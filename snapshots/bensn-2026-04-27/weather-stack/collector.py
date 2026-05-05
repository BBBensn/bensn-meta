#!/usr/bin/env python3
import os
import time
import requests
from datetime import datetime, timezone, timedelta
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS

INFLUX_URL    = os.environ["INFLUX_URL"]
INFLUX_TOKEN  = os.environ["INFLUX_TOKEN"]
INFLUX_ORG    = os.environ["INFLUX_ORG"]
INFLUX_BUCKET = os.environ["INFLUX_BUCKET"]

LOCATIONS = {
    "wien":        {"latitude": 48.1925, "longitude": 16.3897},
    "schwarzenau": {"latitude": 48.5333, "longitude": 15.2167},
}

HOURLY_VARS = ",".join([
    "temperature_2m", "apparent_temperature", "relative_humidity_2m",
    "dew_point_2m", "precipitation", "rain", "snowfall", "snow_depth",
    "weathercode", "pressure_msl", "surface_pressure", "cloudcover",
    "visibility", "windspeed_10m", "windgusts_10m", "winddirection_10m",
    "uv_index", "is_day",
])

def get_vienna_hour():
    # Wien = UTC+1 im Winter, UTC+2 im Sommer – einfach +1 nehmen und Open-Meteo macht den Rest
    vienna_offset = timedelta(hours=2)  # CEST (Sommerzeit)
    vienna_now = datetime.now(timezone.utc) + vienna_offset
    return vienna_now.strftime("%Y-%m-%dT%H:00")

def fetch_weather(name, lat, lon):
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": lat, "longitude": lon,
        "hourly": HOURLY_VARS,
        "current_weather": True,
        "timezone": "Europe/Vienna",
        "forecast_days": 1,
    }
    for attempt in range(3):
        try:
            resp = requests.get(url, params=params, timeout=30)
            resp.raise_for_status()
            break
        except Exception as e:
            print(f"  Versuch {attempt+1} fehlgeschlagen: {e}", flush=True)
            if attempt == 2:
                raise
            time.sleep(10)

    data   = resp.json()
    hourly = data["hourly"]
    times  = hourly["time"]
    now_hour = get_vienna_hour()
    print(f"  Suche nach Stunde: {now_hour}", flush=True)
    points = []

    for i, t in enumerate(times):
        if not t.startswith(now_hour):
            continue
        p = Point("weather") \
            .tag("location", name) \
            .tag("source", "open-meteo") \
            .time(datetime.now(timezone.utc).replace(second=0, microsecond=0), WritePrecision.S)
        for var in HOURLY_VARS.split(","):
            value = hourly.get(var, [None] * len(times))[i]
            if value is not None:
                p = p.field(var, float(value))
        points.append(p)
        break
    return points

def collect():
    client    = InfluxDBClient(url=INFLUX_URL, token=INFLUX_TOKEN, org=INFLUX_ORG)
    write_api = client.write_api(write_options=SYNCHRONOUS)
    all_points = []
    for name, coords in LOCATIONS.items():
        print(f"[{datetime.now().isoformat()}] Fetching {name}...", flush=True)
        try:
            pts = fetch_weather(name, coords["latitude"], coords["longitude"])
            all_points.extend(pts)
            print(f"  → {len(pts)} point(s) collected", flush=True)
        except Exception as e:
            print(f"  ✗ Fehler bei {name}: {e}", flush=True)
    if all_points:
        write_api.write(bucket=INFLUX_BUCKET, org=INFLUX_ORG, record=all_points)
        print(f"[{datetime.now().isoformat()}] ✓ {len(all_points)} Punkte gespeichert.", flush=True)
    client.close()

def seconds_until_next_hour():
    now = datetime.now()
    seconds = (60 - now.minute) * 60 - now.second
    return seconds

if __name__ == "__main__":
    print(f"[{datetime.now().isoformat()}] Collector gestartet.", flush=True)
    collect()  # sofort einmal sammeln beim Start
    while True:
        wait = seconds_until_next_hour()
        print(f"[{datetime.now().isoformat()}] Warte {wait}s bis zur nächsten vollen Stunde...", flush=True)
        time.sleep(wait)
        collect()
