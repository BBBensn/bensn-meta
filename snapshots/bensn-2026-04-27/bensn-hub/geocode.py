#!/usr/bin/env python3
"""
geocode.py — Reverse Geocoding für location_logs
Läuft als Cron, füllt city/district/country für Punkte ohne Ortsname.
Nominatim (OSM), kein API Key, Rate Limit 1 req/s.

Cron (alle 5 min):
*/5 * * * * /usr/bin/python3 /root/geocode.py >> /var/log/geocode.log 2>&1
"""

import psycopg2
import psycopg2.extras
import urllib.request
import urllib.parse
import json
import time
import os

DB_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://bensn:CHANGE_ME_STRONG_PASSWORD@localhost:5432/bensnos"
)

NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"
USER_AGENT    = "bensn-location-geocoder/1.0 (bensn.me)"

def get_db():
    return psycopg2.connect(DB_URL, cursor_factory=psycopg2.extras.RealDictCursor)

def reverse_geocode(lat, lon):
    """Nominatim reverse geocoding → (city, district, country)"""
    params = urllib.parse.urlencode({
        "lat": lat,
        "lon": lon,
        "format": "jsonv2",
        "zoom": 14,           # Stadtteil-Ebene
        "addressdetails": 1,
    })
    url = f"{NOMINATIM_URL}?{params}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            data = json.loads(r.read().decode())
    except Exception as e:
        print(f"  Nominatim error: {e}")
        return None, None, None

    addr = data.get("address", {})

    # City: city > town > village > municipality
    city = (
        addr.get("city") or
        addr.get("town") or
        addr.get("village") or
        addr.get("municipality") or
        addr.get("county")
    )

    # District: city_district > suburb > neighbourhood > quarter
    district = (
        addr.get("city_district") or
        addr.get("suburb") or
        addr.get("neighbourhood") or
        addr.get("quarter")
    )

    country = addr.get("country_code", "").upper() or addr.get("country")

    return city, district, country


def main():
    conn = get_db()
    try:
        cur = conn.cursor()

        # Alle Punkte ohne city, max 50 pro Lauf (Rate Limit)
        cur.execute("""
            SELECT id, latitude, longitude
            FROM location_logs
            WHERE city IS NULL
            ORDER BY timestamp DESC
            LIMIT 50
        """)
        rows = cur.fetchall()

        if not rows:
            print("Keine Punkte zu geocodieren.")
            return

        print(f"{len(rows)} Punkte zu geocodieren…")

        for row in rows:
            lat = float(row["latitude"])
            lon = float(row["longitude"])
            city, district, country = reverse_geocode(lat, lon)

            # Auch wenn city None → als geocodiert markieren (leerer String)
            # damit wir nicht immer wieder denselben Punkt anfragen
            cur.execute("""
                UPDATE location_logs
                SET city     = %s,
                    district = %s,
                    country  = %s
                WHERE id = %s
            """, (city or "", district or "", country or "", row["id"]))
            conn.commit()

            result = f"{district}, {city}" if district else city or "unbekannt"
            print(f"  {lat:.5f},{lon:.5f} → {result}")

            # Nominatim Rate Limit: max 1 req/s
            time.sleep(1.1)

    finally:
        conn.close()


if __name__ == "__main__":
    main()
