---
date_created: 2026-09-17 03:41:00
type: changelog
tags:
  - project
  - changelog
date_modified: 2026-09-17 03:41:00
---

# v1.0.5 — Stats-Feedback für worktracker v2.4.0 (2026-09-17)
- `/api/stats/shift-summary` um `avg_spicy` (Spicy-Zigaretten-Ø separat vom Gesamt-Ø) erweitert
- Neuer Endpoint `GET /api/stats/extremes`: längste Pause, längster/kürzester Dienst (netto) mit
  Datum/Station — hilft, fehlerhafte Einträge zu erkennen
- `/api/shifts`-Limit-Obergrenze von 100 auf 500 angehoben — bei 100 blieben ältere Monate in
  worktrackers Schichten-Tab komplett unsichtbar, sobald >100 Schichten existierten
