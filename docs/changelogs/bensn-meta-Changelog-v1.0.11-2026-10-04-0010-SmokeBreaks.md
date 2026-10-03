---
date_created: 2026-10-04 00:10:00
type: changelog
tags:
  - project
  - changelog
date_modified: 2026-10-04 00:10:00
---

# v1.0.11 — /api/smoke-breaks (2026-10-04)
- Neuer Endpoint `GET /api/smoke-breaks?days=120` (max. 730): alle Pausen mit Zigaretten
  (`zig_spicy`/`zig_blend` > 0) mit `break_start`/`break_end`, Dauer, Typ und Station. Gleiche
  Löschregeln wie `/api/shifts` und `/api/shift/<id>` (Schicht und Pause nicht gelöscht)
- Anlass: Habits (Gesamt-App) lud bisher `/api/shifts?limit=100` und dann für JEDE Schicht
  `/api/shift/<id>` — 101 Requests, jeweils mit Auth-Prüfung, das war die auffällig lange Ladezeit.
  Jetzt 3 Requests insgesamt, Laden in ~0,3 s
- Dazu kann Habits die Arbeits-Zigaretten endlich chronologisch im Verlauf zeigen (bisher nur als
  Tagessumme am Ende des Tages, weil der Zeitstempel je Pause verloren ging)
- Verifiziert: Summen über alle Daten identisch zur alten Methode (754 Spicy / 120 Zigaretten).
  Abweichend ist nur die Tageszuordnung bei 38 Tagen: Pausen nach Mitternacht in Nachtdiensten
  zählen jetzt zum Kalendertag der Pause statt zum Beginn der Schicht
- Deploy: `api.py` wird read-only in den Container gemountet, Neustart mit `docker restart
  bensn-api` reicht (Sicherung `api.py.bak-<zeit>` neben der Datei)
