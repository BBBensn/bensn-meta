---
date_created: 2026-10-04 00:52:00
type: changelog
tags:
  - project
  - changelog
date_modified: 2026-10-04 00:52:00
---

# v1.0.12 — Nginx-Spiegel für den Cutover der Gesamt-App (2026-10-04)
- `nginx/tracking.bensn.me`: Gesamt-App im Root, `/js/` und `/css/` mit Cookie-Auth + `no-cache`,
  `/` mit `no-cache`, `/next/` leitet auf `/` um (Vorschau-Pfad entfällt).
- `nginx/worktracker.bensn.me`: `location /` leitet auf `https://tracking.bensn.me/#/work` um;
  `/api/` (iOS-Kurzbefehle, OwnTracks, ohne Cookie) unverändert.
- Gegenstück für `health.bensn.me` liegt im `health`-Repo (`nginx.conf`).
- Auf dem Server liegen die vorherigen Configs unter `/root/nginx-backup-20261004/`.
