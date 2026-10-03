---
date_created: 2026-10-04 01:30:00
type: changelog
tags:
  - project
  - changelog
date_modified: 2026-10-04 01:30:00
---

# v1.0.13 — Tracking-Eintrag mit nachträglichem Zeitpunkt (2026-10-04)
- `POST /api/tracking/entry`: optionales `timestamp` (ISO 8601). Gesetzt → Eintrag wird mit diesem Zeitpunkt
  angelegt und `date` aus dem Wiener Kalendertag berechnet (wie schon bei `PATCH`). Ohne `timestamp` unverändert.
- Gebraucht vom Habits-Modul (Gedrückthalten eines Buttons → Eintrag mit Uhrzeit). Deploy: `api.py` + `docker restart bensn-api`.
