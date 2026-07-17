# bensn-meta — CLAUDE.md

Projekt-spezifischer Kontext. Ergänzt `~/.claude/CLAUDE.md`.
Ablageort: `~/Documents/Coding/bensn-hub/bensn-meta/CLAUDE.md`

---

## Projekt-Basics

- **Name:** bensn-meta
- **Typ:** Infrastruktur-Meta-Repo (kein Single-App-Projekt)
- **Version:** v1.0.0
- **Status:** active
- **Stack:** Flask + gunicorn + PostgreSQL 16 (Docker) + nginx + systemd

Dieses Repo enthält: Auth-Service-Code, API-Versionen, nginx-Configs und Server-Snapshots für die gesamte bensn.me Infrastruktur.

---

## Lokale Struktur

```
~/Documents/Coding/bensn-hub/bensn-meta/
├── auth/
│   ├── bensn-auth/          ← v1 (veraltet)
│   └── bensn-auth-v2/       ← aktueller Auth-Service
│       ├── auth.py           (Flask, Port 5003, gunicorn)
│       ├── bensn-auth.service
│       ├── DEPLOY.sh
│       └── nginx-*.conf      (Configs für alle Domains)
├── hub-versions/
│   └── v3.0.0/
│       └── api.py            ← bensn Personal OS API (Flask + PostgreSQL, Port 5001)
├── nginx/                    ← nginx site configs (aktueller Stand)
│   ├── bensn.me
│   ├── data.bensn.me
│   ├── feed.bensn.me
│   ├── location.bensn.me
│   ├── pdf.bensn.me
│   ├── tracking.bensn.me
│   └── worktracker.bensn.me
├── snapshots/
│   └── bensn-2026-04-27/    ← Vollständiger Server-Snapshot
│       ├── bensn-hub/        (API + docker-compose.yml + schema.sql)
│       ├── feed/, landing/, location/, worktracker/
│       ├── nginx/, systemd/, shared/
│       └── weather-stack/, stirling-pdf/
├── docs/
│   └── changelogs/
└── CLAUDE.md
```

---

## Remote-Struktur

```
/var/www/
├── bensn.me/                ← Landing Page (static)
├── bensn-auth/              ← Auth Service
│   └── auth.py
├── feed/
│   ├── public/              ← Feed Frontend
│   └── api/                 ← Feed API (app.py)
├── worktracker/             ← Worktracker Frontend
├── location/                ← Location Frontend
├── tracking/                ← Tracking Frontend
└── shared/                  ← Geteilte Assets (CSS, JS)

/root/bensn-hub/             ← Haupt-API (Docker Compose, NICHT unter /var/www/)
├── api.py
├── docker-compose.yml
├── schema.sql
└── requirements.txt
```

---

## Services & Ports

| Dienst | Port | Deployment |
|--------|------|------------|
| bensn-auth | 5003 | systemd: `bensn-auth.service` (gunicorn) |
| bensn-api | 5001 | Docker: `bensn-api` Container |
| bensn-postgres | 5432 | Docker: `bensn-postgres` Container (localhost only) |
| feed-api | 5002 | systemd: `feed-api.service` |
| Grafana | 3000 | Docker (`data.bensn.me`) |
| Stirling-PDF | 8081 | Docker (`pdf.bensn.me`) |

---

## Domains

| Domain | Ziel | Auth |
|--------|------|------|
| bensn.me | /var/www/bensn.me (static) | öffentlich |
| auth.bensn.me | Port 5003 | — (ist selbst Auth) |
| worktracker.bensn.me | /var/www/worktracker + Port 5001 | nginx injiziert X-API-Key |
| feed.bensn.me | /var/www/feed/public + Port 5002 | nginx Basic Auth für /api/ |
| location.bensn.me | /var/www/location + Port 5001 | nginx injiziert X-API-Key |
| tracking.bensn.me | /var/www/tracking + Port 5001 | nginx injiziert X-API-Key |
| data.bensn.me | Port 3000 (Grafana) | [placeholder] |
| pdf.bensn.me | Port 8081 (Stirling-PDF) | [placeholder] |

---

## Auth-System

**bensn-auth (Cookie-basiert):**
- Cookie: `bensn_auth`, Domain `.bensn.me`, HMAC-SHA256 signiert, 90 Tage
- Verify: `GET http://127.0.0.1:5003/auth/verify` → 200 OK | 401
- Login: `GET/POST https://auth.bensn.me/auth/login`
- nginx nutzt `auth_request` Direktive um Subdomains zu schützen

**API-Key (X-API-Key):**
- nginx injiziert den Key automatisch für worktracker, location, tracking
- API prüft per `require_api_key` Decorator (Header oder Query-Param)

**Feed Basic Auth:**
- feed.bensn.me nutzt nginx `auth_basic` mit `/etc/nginx/.htpasswd` für `/api/`

---

## Deploy

```bash
# Auth-Service
scp ~/Documents/Coding/bensn-hub/bensn-meta/auth/bensn-auth-v2/auth.py \
  bensn:/var/www/bensn-auth/auth.py
ssh bensn systemctl restart bensn-auth

# Haupt-API (Docker)
scp ~/Documents/Coding/bensn-hub/bensn-meta/hub-versions/v3.0.0/api.py \
  bensn:/root/bensn-hub/api.py
ssh bensn "cd /root/bensn-hub && docker compose up -d --build"

# nginx-Config deployen
scp ~/Documents/Coding/bensn-hub/bensn-meta/nginx/worktracker.bensn.me \
  bensn:/etc/nginx/sites-enabled/worktracker.bensn.me
ssh bensn "nginx -t && systemctl reload nginx"

# systemd-Service nach .service Änderung
scp auth/bensn-auth-v2/bensn-auth.service bensn:/etc/systemd/system/bensn-auth.service
ssh bensn "systemctl daemon-reload && systemctl restart bensn-auth"
```

---

## Datenbank

- **Engine:** PostgreSQL 16 (Docker Container `bensn-postgres`)
- **DB:** `bensnos`
- **User:** `bensn`
- **Port:** `127.0.0.1:5432` (nur lokal erreichbar)
- **Docker Compose:** `/root/bensn-hub/docker-compose.yml`
- **Schema:** `/root/bensn-hub/schema.sql`

Tabellen: `shifts`, `breaks`, `sleep_logs`, `mood_logs`, `health_logs`, `location_logs`, `obsidian_entries`
Views: `current_shift`, `daily_summary`

---

## API-Endpoints (hub-versions/v3.0.0/api.py, Port 5001)

| Methode | Endpoint | Beschreibung |
|---------|----------|-------------|
| GET | /health | Health Check |
| POST | /api/shift/start | Schicht beginnen |
| POST | /api/shift/end | Schicht beenden |
| GET | /api/shift/current | Aktuelle Schicht + Pausen (für Widget) |
| GET | /api/shift/`<id>` | Einzelne Schicht mit Pausen |
| GET | /api/shifts | Schichtliste (limit/offset/date) |
| PATCH | /api/shift/`<id>`/correct | Schicht korrigieren (speichert Snapshot) |
| DELETE | /api/shift/`<id>` | Schicht soft-löschen |
| POST | /api/break/start | Pause beginnen |
| POST | /api/break/end | Pause beenden (zig_spicy/zig_blend) |
| POST | /api/break/add | Pause nachträglich hinzufügen |
| PATCH | /api/break/`<id>`/correct | Pause korrigieren |
| DELETE | /api/break/`<id>` | Pause soft-löschen |
| POST | /api/health/sleep | Schlaf eintragen (upsert by date) |
| POST | /api/health/mood | Stimmung eintragen |
| POST | /api/health/log | Gesundheitsdaten (Schritte, Gewicht, Medikamente) |
| POST | /api/location | Standort (OwnTracks + Shortcut Format) |
| GET | /api/locations | Standortverlauf (limit/offset) |
| GET | /api/feed | Kombinierter Feed (shifts, mood, sleep, obsidian) |
| GET | /api/stats/weekly | Wochenübersicht |
| GET | /api/stats/shift-summary | Zusammenfassung nach Schichttyp |

---

## Git

- **Repo:** `https://github.com/BBBensn/bensn-meta`
- **Remote:** `git@github.com:BBBensn/bensn-meta.git`

---

## Projekt-spezifische Konventionen

- nginx-Configs lokal in `nginx/` pflegen → per scp deployen → `nginx -t && reload`
- Auth-Service-Code ausschließlich in `auth/bensn-auth-v2/` — `bensn-auth/` ist veraltet
- Neue API-Versionen in `hub-versions/vX.X.X/` archivieren
- Snapshots bei größeren Infra-Änderungen in `snapshots/[name]-[YYYY-MM-DD]/` ablegen
- Soft-Delete: Schichten und Pausen werden mit `deleted = true` markiert, nicht physical gelöscht
- `original_data` JSONB-Feld: speichert Snapshot vor Korrekturen

---

## Roadmap

| Version | Feature | Status |
|---------|---------|--------|
| v1.0.0 | Meta-Repo Setup: Auth v2, API v3.0.0, nginx-Configs, Snapshots | aktiv |
| v1.1.0 | [placeholder] | geplant |

---

## Obsidian-Doku

- Projekt-MD: `03_Projects/Coding PC/bensn-meta/bensn-meta.md`
- Changelogs: `03_Projects/Coding PC/bensn-meta/Changelogs/`
- Changelog-All: `03_Projects/Coding PC/bensn-meta/bensn-meta-Changelog-All.md`
