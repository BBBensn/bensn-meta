# bensn-meta — CLAUDE.md

Projekt-spezifischer Kontext. Ergänzt `~/.claude/CLAUDE.md`.
Ablageort: `~/Documents/Coding/bensn-hub/bensn-meta/CLAUDE.md`

---

## Projekt-Basics

- **Name:** bensn-meta
- **Typ:** Infrastruktur-Meta-Repo (kein Single-App-Projekt)
- **Version:** v1.0.5
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
│       └── nginx-snippet-bensn-auth.conf   (wiederverwendbares auth_request-Snippet)
├── hub-versions/
│   └── v3.0.0/
│       └── api.py            ← bensn Personal OS API (Flask + PostgreSQL, Port 5001)
│                                — verifiziert identisch mit `docker exec bensn-api cat /app/api.py`
├── nginx/                    ← nginx site configs, direkt vom Server gezogen (aktueller Stand)
│   ├── bensn.me
│   ├── auth.bensn.me
│   ├── data.bensn.me
│   ├── feed.bensn.me
│   ├── location.bensn.me
│   ├── pdf.bensn.me
│   ├── tracking.bensn.me
│   └── worktracker.bensn.me
├── shared/                    ← geteilte Design-System-Assets (bensn.css, bensn.js), seit
│                                 2026-09-16 erstmals versioniert — vorher existierte nur eine
│                                 Live-Kopie auf dem Server ohne Git-Historie (siehe unten)
├── schema.sql                ← aktuelles Schema, per `pg_dump --schema-only` gezogen (siehe unten)
├── snapshots/
│   └── bensn-2026-04-27/    ← Vollständiger Server-Snapshot (Archiv-Referenz, NICHT aktueller Stand —
│                               das veraltete schema.sql/nginx darin gehört zum 27.4.-Zeitpunkt)
├── docs/
│   └── changelogs/
└── CLAUDE.md
```

**Hinweis aus dem Repo-Restructure (2026-09):** `nginx/*` und `schema.sql` waren vorher an
mehreren Stellen dupliziert und teils veraltet — z.B. hatte `nginx/feed.bensn.me` noch die
alte Nginx-Basic-Auth-Config, obwohl der Server längst auf das Cookie-System migriert war,
und `auth/bensn-auth-v2/` enthielt eigene, ebenfalls veraltete Kopien von `nginx-feed.bensn.me`
etc. plus alte `feed-index.html`/`tracking-index.html`-Snapshots. Alles wurde gegen den
tatsächlichen Server-Stand verifiziert (`ssh bensn cat /etc/nginx/sites-enabled/...`) und
die Duplikate entfernt — `nginx/` ist jetzt die einzige Quelle für aktuelle Configs.

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
| health-api | 5008 | Docker: `bensn-health-api` Container (siehe `health`-Repo) |
| Grafana | 3000 | Docker (`data.bensn.me`) |
| Stirling-PDF | 8081 | Docker (`pdf.bensn.me`) |

**5004–5007 sind belegt von anderen Projekten auf demselben Server** (u.a. BubenMarket auf
5004) — vor jeder neuen Port-Reservierung `ssh bensn "ss -tlnp"` prüfen, nicht nur die Doku.
Nächster tatsächlich freier Port: **5009**.

---

## Domains

| Domain | Ziel | Auth |
|--------|------|------|
| bensn.me | /var/www/bensn.me (static) | öffentlich |
| auth.bensn.me | Port 5003 | — (ist selbst Auth) |
| worktracker.bensn.me | /var/www/worktracker + Port 5001 | Cookie (bensn-auth) + nginx injiziert X-API-Key |
| feed.bensn.me | /var/www/feed/public + Port 5002 | Cookie (bensn-auth), gezielte öffentliche Ausnahmen |
| health.bensn.me | /var/www/health + Port 5008 | Cookie (bensn-auth) + nginx injiziert X-API-Key |
| location.bensn.me | /var/www/location + Port 5001 | Cookie (bensn-auth) + nginx injiziert X-API-Key |
| tracking.bensn.me | /var/www/tracking + Port 5001 | Cookie (bensn-auth) + nginx injiziert X-API-Key |
| data.bensn.me | Port 3000 (Grafana) | Grafana-eigenes Login |
| pdf.bensn.me | Port 8081 (Stirling-PDF) | Stirling-eigenes Login |

*(Weitere Domains laufen auf demselben Server für unabhängige Nebenprojekte — z.B.
`market.bensn.me`, `stream.bensn.me` (reiner nginx-Proxy zu einem externen Jellyfin, kein
eigener lokaler Code), `crossword.bensn.me`, `games.bensn.at` — die nicht Teil dieses
Repos/Umbaus sind, aber teils dieselbe Postgres-Instanz nutzen, siehe
`library_items`/`wishlist_items` unten.*

**`library.bensn.me` hat sehr wohl einen eigenen lokalen Repo** (`~/Documents/Coding/bensn-hub/library/`,
GitHub `bensn-library-dashboard`) — lag bis 2026-09-17 versteckt unter `stream/Library Dashboard/`
und wurde deshalb bei jeder bisherigen Suche übersehen. Bewusst weiterhin nicht Teil des
Design-Umbaus (eigener Punkt, siehe `design-system.html`), aber strukturell jetzt an der
richtigen Stelle.)*

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

**Feed:** nutzt seit v1.7.x ebenfalls das Cookie-System (`auth_request`), NICHT mehr
Nginx Basic Auth — mit gezielten unauthentifizierten Ausnahmen für `/api/upload`,
`/api/feed/shared`, `/api/feed/combined/shared`, `/api/oembed`, `/api/webhook`,
`/shared`, `/s`, `/uploads/` (siehe `nginx/feed.bensn.me`).

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

# Shared Design-System-Assets (wirkt sich auf ALLE bensn.me-Frontends aus, kein Restart nötig)
scp ~/Documents/Coding/bensn-hub/bensn-meta/shared/bensn.css bensn:/var/www/shared/bensn.css
scp ~/Documents/Coding/bensn-hub/bensn-meta/shared/bensn.js bensn:/var/www/shared/bensn.js
```

---

## Datenbank

- **Engine:** PostgreSQL 16 (Docker Container `bensn-postgres`)
- **DB:** `bensnos`
- **User:** `bensn`
- **Port:** `127.0.0.1:5432` (nur lokal erreichbar)
- **Docker Compose:** `/root/bensn-hub/docker-compose.yml`
- **Schema:** `schema.sql` in diesem Repo (per `pg_dump --schema-only` vom Server gezogen,
  Stand 2026-09-16 — verlässlicher als das ältere `snapshots/.../schema.sql`)

**Aktiv genutzte Tabellen:** `shifts`, `breaks`, `sleep_logs`, `location_logs`, `location_stays`,
`tracking_categories`, `tracking_items`, `tracking_entries`, `shares` (Feed-Sharing-Tokens),
`journal_entries` (alle 9 Journal-Typen, siehe `feed`-Repo — seit 2026-09-16 die einzige
Quelle für den Feed, Obsidian-Vault-Sync komplett abgeschaltet), `health_medications`,
`health_medication_logs`, `health_medication_effect_notes`, `health_meals`, `health_bp_logs`,
`health_weight_logs` (siehe `health`-Repo)

**Legacy, geschrieben aber vom Feed nicht mehr gelesen:** `mood_logs` — ursprünglich für
Mood-Einträge gedacht, per `/api/health/mood` weiterhin beschreibbar, aber der Feed zeigt
Mood-Daten seit v2.1.0 ausschließlich aus `journal_entries`. Kandidat für ein späteres
Aufräumen, falls `/api/health/mood` nicht mehr gebraucht wird.

**Gedroppt (2026-09-16):** `health_logs`, `obsidian_entries`, `feed_items` — alle drei
waren tot/write-only (nie gelesen bzw. nie befüllt), siehe `feed`- und `health`-Repo
Changelogs für Details.

**Gehören NICHT zu diesem Projekt** (dieselbe DB, andere Nebenprojekte): `library_items`,
`wishlist_items`

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
| POST | /api/health/mood | Stimmung eintragen (siehe Hinweis zu `mood_logs` oben) |
| POST | /api/location | Standort (OwnTracks + Shortcut Format) |
| GET | /api/locations | Standortverlauf (limit/offset, `simplify=true` für RDP-Vereinfachung) |
| GET | /api/stays | Geclusterte Aufenthalte |
| PATCH | /api/stay/`<id>` | Aufenthalt umbenennen |
| GET | /api/feed | Kombinierter Feed (shifts, mood, sleep, obsidian) — eigenständig von feed-api's `/api/feed/combined` |
| GET | /api/stats/weekly | Wochenübersicht |
| GET | /api/stats/shift-summary | Zusammenfassung nach Schichttyp |
| GET/POST/PATCH/DELETE | /api/tracking/entries, /entry, /entry/`<id>` | Tracking-Einträge CRUD (PATCH: `amount`, `note`, `timestamp` — bei `timestamp` wird `date` serverseitig aus `Europe/Vienna` neu berechnet) |
| GET | /api/tracking/bestand/`<item_id>` | Aktueller Bestand + Verbrauch seit letztem Eintrag |
| GET | /api/tracking/summary | Tages-Zähler-Zusammenfassung |
| GET/POST/PATCH/DELETE | /api/tracking/categories, /items | Kategorien/Items-Konfiguration |
| POST | /api/tracking/entries/batch | Mehrere verknüpfte Einträge atomar (linked_items) |

---

## Git

- **Repo:** `https://github.com/BBBensn/bensn-meta`
- **Remote:** `git@github.com:BBBensn/bensn-meta.git`

---

## Projekt-spezifische Konventionen

- nginx-Configs lokal in `nginx/` pflegen (einzige Quelle, keine Zweitkopien in `auth/`) →
  per scp deployen → `nginx -t && reload`
- Bei Unsicherheit über den Live-Stand: `ssh bensn "cat /etc/nginx/sites-enabled/<domain>"`
  gegen die lokale Datei diffen, nicht blind vertrauen
- Auth-Service-Code ausschließlich in `auth/bensn-auth-v2/` — `bensn-auth/` ist veraltet
- Neue API-Versionen in `hub-versions/vX.X.X/` archivieren
- Snapshots bei größeren Infra-Änderungen in `snapshots/[name]-[YYYY-MM-DD]/` ablegen
- Soft-Delete: Schichten und Pausen werden mit `deleted = true` markiert, nicht physical gelöscht
- `original_data` JSONB-Feld: speichert Snapshot vor Korrekturen
- **Design-System-Assets (`shared/bensn.css`/`bensn.js`):** einzige Quelle, jede App linkt
  `/shared/bensn.css` statt Styles zu duplizieren. Komponenten, die in ≥2 Apps identisch
  vorkommen, gehören HIER rein, nicht als Kopie in jeder App (siehe `.btn-pill`/`.btn-save`/
  `.btn-cancel`, seit 2026-09-16 zentralisiert — vorher 3x fast-identisch dupliziert).
  Änderungen hier wirken sich auf ALLE bensn.me-Frontends gleichzeitig aus — das ist
  beabsichtigt (Ziel: ein Theme-Wechsel an einer Stelle), aber deshalb vor dem Deploy
  gegen mindestens 2 Apps visuell testen

---

## Roadmap

| Version | Feature | Status |
|---------|---------|--------|
| v1.0.0 | Meta-Repo Setup: Auth v2, API v3.0.0, nginx-Configs, Snapshots | ✅ done |
| — | nginx-Configs + schema.sql gegen Live-Server verifiziert, Duplikate entfernt | ✅ done |
| — | Neuer Service `health-api` (Port 5008 — 5004-5007 waren schon durch andere Projekte belegt) für Medikamente/Blutdruck/Mahlzeiten | ✅ deployed (2026-09-16, Code im `health`-Repo) |
| — | `journal_entries`-Schema + volle Obsidian-Ablösung im Feed (siehe `feed`-Repo v2.1.0–v2.3.0) | ✅ deployed (2026-09-16) |
| — | `health_logs`, `obsidian_entries`, `feed_items` gedroppt, `/api/health/log`-Endpoint entfernt (hing an `health_logs`) | ✅ deployed (2026-09-16) |
| — | `PATCH /api/tracking/entry/<id>` um `timestamp`-Feld erweitert (Zeitpunkt-Korrektur für tracking.bensn.me v2.0.0, `date` wird daraus neu berechnet) | ✅ deployed (2026-09-16) |
| — | Basic Impressum für die bensn.me-Seiten (gesetzlich vorgeschrieben, site-weit statt pro Projekt) | ⬜ offen (später, auf Wunsch des Users) |
| v1.0.1 | `shared/bensn.css`/`bensn.js` erstmals versioniert (`bensn-meta/shared/`, vorher nur Live-Kopie auf dem Server ohne Git-Historie), `.btn-pill`/`.btn-save`/`.btn-cancel` aus health/feed/tracking (und teilweise worktracker-Inline-Styles) hierher zentralisiert statt dupliziert, neue `design-system.html` als lebende Style-Guide-Referenz mit Live-Theme-Editor | ✅ deployed (2026-09-16) |
| v1.0.2 | Erste Inkonsistenzen aus `design-system.html` aufgeräumt: `.btn-danger` (tracking) entfernt zugunsten von `.btn-pill.red`; Border-Radius der "Container/Tile"-Familie (`.wt-stat`, `.wt-cig`, health.bensn.mes `.stat-card`) von 8/10px auf die schon vorherrschenden 12px angeglichen; die dort genannten 9px-Labels (`.wt-stat-label`, `.wt-cig-label`, `.wt-table th`) auf 10px angeglichen. Bewusst NICHT angefasst: Button-/Input-Radius (andere Komponenten-Familie) und die deutlich breitere 9px-Verwendung in worktrackers Formular-Labels/feed/location — siehe `design-system.html` für den vollen Umfang | ✅ deployed (2026-09-16) |
| v1.0.3 | Hub-weites Strukturaufräumen: `stream/Library Dashboard/` (versteckt, nie gefunden) nach `library/` verschoben — ist die echte `bensn-library-dashboard`/library.bensn.me-Codebase; leerer `stream/`-Ordner entfernt; stale `nginx-worktracker.conf` (Pre-Certbot-Entwurf, längst durch `nginx/worktracker.bensn.me` ersetzt) entfernt; worktracker/landing-Icons korrigiert (lokale Repos enthielten andere Dateien als tatsächlich deployed — jetzt live-Stand gezogen); redundanten Top-Level-`Icons/`-Ordner entfernt (alle Inhalte waren längst in die jeweiligen App-Repos migriert) | ✅ deployed (2026-09-17) |
| v1.0.4 | Neuer Endpoint `GET /api/stats/monthly` (Monats-Aggregation für worktracker v2.3.0 Stats-Tab). Zusammen deployed: bereits lokal vorhandene, unabhängige Location-Stays-Erweiterung (`note`-Feld auf `PATCH /api/stay/<id>`, neuer `PATCH /api/places/rename`) — noch ohne Frontend im `location`-Repo | ✅ deployed (2026-09-17) |
| v1.0.5 | `/api/stats/shift-summary` um `avg_spicy` erweitert, neuer Endpoint `GET /api/stats/extremes` (längste Pause, längster/kürzester Dienst), `/api/shifts`-Limit-Obergrenze 100 → 500 (worktracker v2.4.0 Stats-Feedback) | ✅ deployed (2026-09-17) |

---

## Obsidian-Doku

- Projekt-MD: `03_Projects/Coding PC/bensn-meta/bensn-meta.md`
- Changelogs: `03_Projects/Coding PC/bensn-meta/Changelogs/`
- Changelog-All: `03_Projects/Coding PC/bensn-meta/bensn-meta-Changelog-All.md`
