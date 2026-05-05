#!/usr/bin/env python3
"""
Weather API – empfängt GPS-Koordinaten vom iPhone (via Shortcut),
fragt Open-Meteo ab und speichert das Ergebnis in InfluxDB.

Erwarteter POST-Body (JSON):
{
  "latitude": 48.123,
  "longitude": 16.456,
  "api_key": "mein-iphone-api-key"
}
"""

import os
import requests
from datetime import datetime, timezone
from flask import Flask, request, jsonify
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS

app = Flask(__name__)

INFLUX_URL    = os.environ["INFLUX_URL"]
INFLUX_TOKEN  = os.environ["INFLUX_TOKEN"]
INFLUX_ORG    = os.environ["INFLUX_ORG"]
INFLUX_BUCKET = os.environ["INFLUX_BUCKET"]
API_KEY       = os.environ["API_KEY"]

HOURLY_VARS = ",".join([
    "temperature_2m", "apparent_temperature", "relative_humidity_2m",
    "dew_point_2m", "precipitation", "rain", "snowfall", "snow_depth",
    "weathercode", "pressure_msl", "surface_pressure", "cloudcover",
    "visibility", "windspeed_10m", "windgusts_10m", "winddirection_10m",
    "uv_index", "is_day",
])


def fetch_and_store(lat: float, lon: float):
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude":        lat,
        "longitude":       lon,
        "hourly":          HOURLY_VARS,
        "current_weather": True,
        "timezone":        "Europe/Vienna",
        "forecast_days":   1,
    }

    resp = requests.get(url, params=params, timeout=10)
    resp.raise_for_status()
    data = resp.json()

    hourly    = data["hourly"]
    times     = hourly["time"]
    now_hour  = datetime.now().strftime("%Y-%m-%dT%H:00")

    for i, t in enumerate(times):
        if not t.startswith(now_hour):
            continue

        p = Point("weather") \
            .tag("location", "current_location") \
            .tag("source", "iphone") \
            .field("gps_lat", lat) \
            .field("gps_lon", lon) \
            .time(datetime.now(timezone.utc), WritePrecision.S)

        for var in HOURLY_VARS.split(","):
            value = hourly.get(var, [None] * len(times))[i]
            if value is not None:
                p = p.field(var, float(value))

        client    = InfluxDBClient(url=INFLUX_URL, token=INFLUX_TOKEN, org=INFLUX_ORG)
        write_api = client.write_api(write_options=SYNCHRONOUS)
        write_api.write(bucket=INFLUX_BUCKET, org=INFLUX_ORG, record=[p])
        client.close()
        return True

    return False


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200


@app.route("/api/location", methods=["POST"])
def receive_location():
    body = request.get_json(silent=True)

    if not body:
        return jsonify({"error": "Kein JSON-Body"}), 400

    if body.get("api_key") != API_KEY:
        return jsonify({"error": "Ungültiger API-Key"}), 401

    lat = body.get("latitude")
    lon = body.get("longitude")

    if lat is None or lon is None:
        return jsonify({"error": "latitude und longitude erforderlich"}), 400

    try:
        ok = fetch_and_store(float(lat), float(lon))
        if ok:
            return jsonify({"status": "gespeichert"}), 200
        else:
            return jsonify({"status": "keine Daten für aktuelle Stunde"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
