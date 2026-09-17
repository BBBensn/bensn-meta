---
date_created: 2026-09-17 03:56:00
type: changelog
tags:
  - project
  - changelog
date_modified: 2026-09-17 03:56:00
---

# v1.0.6 — Fix: gelöschte Pausen verfälschten Stats-Berechnungen (2026-09-17)
- Bug gefunden über worktracker-Feedback: die Schicht vom 14.04. hatte zwei doppelte, aber bereits
  soft-gelöschte Pausen-Einträge (Reste einer Korrektur-Historie). `/api/stats/extremes`,
  `/api/stats/shift-summary` und `/api/stats/monthly` summierten Pausen ohne `deleted`-Filter,
  wodurch diese gelöschten Duplikate mitgezählt wurden — die Netto-Dienstzeit dieser Schicht wurde
  dadurch um ca. 1h zu kurz berechnet (416min echt vs. 360min berechnet) und sie erschien fälschlich
  als "kürzester Dienst"
- Fix: alle drei Endpoints filtern jetzt konsequent `deleted IS NULL OR deleted = false` auf
  `breaks` (und zusätzlich auf `shifts` in `shift-summary`/`monthly`, wo das vorher ebenfalls fehlte)
- Bekannt, aber bewusst nicht angefasst: `current_shift`- und `daily_summary`-Views in `schema.sql`
  haben denselben strukturellen Fehler (keine `deleted`-Filterung auf `breaks`) — betrifft die
  "Gesamtpause"-Anzeige im Aktiv-Tab, falls eine laufende Schicht eine ähnliche
  Korrektur-Historie bekommt. Eigener Punkt für später, da das eine View-Migration braucht
