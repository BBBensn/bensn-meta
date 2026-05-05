#!/usr/bin/env python3
"""
weather_location.py — Wetter-Kontext für location_logs
Läuft als Cron, füllt temperature/weather_code/precipitation für Punkte ohne Wetterdaten.
Open-Meteo Historical API, kein API Key, kostenlos.

Cron (alle 15 min, nach geocode.py):
*/15 * * * * DATABASE_URL="postgresql://bensn:PW@localhost:5432/bensnos" /usr/bin/python3 /root/bensn-hub/weather_location.py >> /var/log/weather_location.log 2>&1

Open-Meteo Archive API: https://archive-api.open-meteo.com/v1/archive
Verfügbar: letzte 5 Tage bis aktuelle Stunde (ca. 1h Verzögerung)
"""

import psycopg2
import psycopg2.extras
import urllib.request
import urllib.parse
import json
import time
import os
from datetime import datetime, timezone, timedelta

DB_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://bensn:CHANGE_ME_STRONG_PASSWORD@localhost:5432/bensnos"
)

OPEN_METEO_ARCHIVE = "https://archive-api.open-meteo.com/v1/archive"

# Gleiche Variablen wie collector.py (Subset der wichtigsten)
HOURLY_VARS = ",".join([
    "temperature_2m",
    "apparent_temperature",
    "precipitation",
    "weathercode",
    "cloudcover",
    "windspeed_10m",
    "is_day",
])

# WMO Weather Code → lesbare Beschreibung (Kurzform)
WMO_CODES = {
    0: "Klar", 1: "Meist klar", 2: "Teilweise bewölkt", 3: "Bedeckt",
    45: "Nebel", 48: "Reifnebel",
    51: "Leichter Nieselregen", 53: "Nieselregen", 55: "Starker Nieselregen",
    61: "Leichter Regen", 63: "Regen", 65: "Starker Regen",
    71: "Leichter Schnee", 73: "Schnee", 75: "Starker Schnee",
    80: "Leichte Schauer", 81: "Schauer", 82: "Starke Schauer",
    95: "Gewitter", 96: "Gewitter mit Hagel", 99: "Schweres Gewitter",
}

def get_db():
    return psycopg2.connect(DB_URL, cursor_factory=psycopg2.extras.RealDictCursor)

def fetch_weather_for_point(lat, lon, ts_utc):
    """
    Holt Wetterdaten für einen Punkt via Open-Meteo Archive API.
    ts_utc: datetime in UTC
    Gibt dict zurück oder None bei Fehler.
    """
    # Archive API braucht Datum als YYYY-MM-DD
    # Wir fragen den Tag des Punktes ab (+ Folgetag als Buffer für Mitternacht)
    date_str = ts_utc.strftime("%Y-%m-%d")
    
    # Archive API hat ca. 1h Verzögerung — zu aktuelle Punkte überspringen
    now_utc = datetime.now(timezone.utc)
    if (now_utc - ts_utc) < timedelta(hours=2):
        return None  # zu frisch, später nochmal versuchen

    params = urllib.parse.urlencode({
        "latitude":   lat,
        "longitude":  lon,
        "start_date": date_str,
        "end_date":   date_str,
        "hourly":     HOURLY_VARS,
        "timezone":   "UTC",
    })
    url = f"{OPEN_METEO_ARCHIVE}?{params}"
    req = urllib.request.Request(url, headers={"User-Agent": "bensn-weather-location/1.0"})

    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            data = json.loads(r.read().decode())
    except Exception as e:
        print(f"  Open-Meteo error: {e}")
        return None

    hourly = data.get("hourly", {})
    times  = hourly.get("time", [])
    
    # Stunde des Punktes in UTC finden
    target_hour = ts_utc.strftime("%Y-%m-%dT%H:00")
    
    for i, t in enumerate(times):
        if t == target_hour:
            code = hourly.get("weathercode", [None] * len(times))[i]
            return {
                "temperature":        hourly.get("temperature_2m",       [None]*len(times))[i],
                "apparent_temp":      hourly.get("apparent_temperature",  [None]*len(times))[i],
                "precipitation":      hourly.get("precipitation",         [None]*len(times))[i],
                "weather_code":       int(code) if code is not None else None,
                "weather_desc":       WMO_CODES.get(int(code), "Unbekannt") if code is not None else None,
                "cloudcover":         hourly.get("cloudcover",            [None]*len(times))[i],
                "windspeed":          hourly.get("windspeed_10m",         [None]*len(times))[i],
                "is_day":             hourly.get("is_day",                [None]*len(times))[i],
            }
    
    return None


def ensure_columns(conn):
    """Wetter-Spalten zur location_logs Tabelle hinzufügen falls nicht vorhanden."""
    cur = conn.cursor()
    cur.execute("""
        ALTER TABLE location_logs
          ADD COLUMN IF NOT EXISTS temperature     NUMERIC(5,2),
          ADD COLUMN IF NOT EXISTS apparent_temp   NUMERIC(5,2),
          ADD COLUMN IF NOT EXISTS precipitation   NUMERIC(6,2),
          ADD COLUMN IF NOT EXISTS weather_code    SMALLINT,
          ADD COLUMN IF NOT EXISTS weather_desc    VARCHAR(50),
          ADD COLUMN IF NOT EXISTS cloudcover      SMALLINT,
          ADD COLUMN IF NOT EXISTS windspeed       NUMERIC(5,1),
          ADD COLUMN IF NOT EXISTS is_day          BOOLEAN
    """)
    conn.commit()


def main():
    conn = get_db()
    try:
        ensure_columns(conn)
        cur = conn.cursor()

        # Punkte ohne Wetterdaten, älter als 2h (Archive API Verzögerung)
        cur.execute("""
            SELECT id, latitude, longitude, timestamp
            FROM location_logs
            WHERE temperature IS NULL
              AND timestamp < NOW() - INTERVAL '2 hours'
            ORDER BY timestamp DESC
            LIMIT 30
        """)
        rows = cur.fetchall()

        if not rows:
            print("Keine Punkte zu verarbeiten.")
            return

        print(f"{len(rows)} Punkte brauchen Wetterdaten…")

        # Punkte mit gleicher Stunde + ähnlichen Koordinaten zusammenfassen
        # um API-Calls zu sparen (viele Punkte am gleichen Ort)
        cache = {}  # (lat_round, lon_round, hour) → weather_dict

        for row in rows:
            lat = float(row["latitude"])
            lon = float(row["longitude"])
            ts  = row["timestamp"]
            
            # Zeitzone-aware machen falls nötig
            if ts.tzinfo is None:
                ts = ts.replace(tzinfo=timezone.utc)

            # Cache-Key: 2 Dezimalstellen (~1km) + Stunde
            cache_key = (round(lat, 2), round(lon, 2), ts.strftime("%Y-%m-%dT%H:00"))

            if cache_key in cache:
                weather = cache[cache_key]
                print(f"  Cache-Hit für {cache_key[2]}")
            else:
                weather = fetch_weather_for_point(lat, lon, ts)
                cache[cache_key] = weather
                time.sleep(0.5)  # sanftes Rate Limiting

            if weather is None:
                print(f"  {ts.isoformat()[:16]} → kein Wetter (zu frisch oder Fehler)")
                continue

            cur.execute("""
                UPDATE location_logs SET
                    temperature   = %s,
                    apparent_temp = %s,
                    precipitation = %s,
                    weather_code  = %s,
                    weather_desc  = %s,
                    cloudcover    = %s,
                    windspeed     = %s,
                    is_day        = %s
                WHERE id = %s
            """, (
                weather["temperature"],
                weather["apparent_temp"],
                weather["precipitation"],
                weather["weather_code"],
                weather["weather_desc"],
                weather["cloudcover"],
                weather["windspeed"],
                bool(weather["is_day"]) if weather["is_day"] is not None else None,
                row["id"],
            ))
            conn.commit()

            desc = weather.get("weather_desc", "?")
            temp = weather.get("temperature", "?")
            print(f"  {ts.isoformat()[:16]} → {temp}°C, {desc}")

    finally:
        conn.close()


if __name__ == "__main__":
    main()
