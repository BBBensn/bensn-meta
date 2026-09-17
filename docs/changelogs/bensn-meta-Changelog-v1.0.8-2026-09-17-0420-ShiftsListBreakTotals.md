---
date_created: 2026-09-17 04:20:00
type: changelog
tags:
  - project
  - changelog
date_modified: 2026-09-17 04:20:00
---

# v1.0.8 — `/api/shifts` liefert jetzt echte Pausen-/Zigaretten-Summen (2026-09-17)
- Gefunden über worktracker-Feedback (12.09.-Schicht: "Netto" in der Liste zeigte 8h, obwohl
  Stats richtigerweise 6h07m Netto auswies): `/api/shifts` gab `total_break_minutes`/`zig_total`
  nie zurück (reines `SELECT * FROM shifts`). Das Frontend rechnete `netto = brutto - (total_break_minutes||0)`,
  also faktisch immer `netto = brutto` — die Schichten-Liste zeigte seit jeher Brutto, obwohl
  "Netto" draufstand
- Fix: `/api/shifts` joint jetzt dieselbe Pausen-Aggregation (mit `deleted`-Filter) wie die
  Stats-Endpoints und liefert `total_break_minutes`/`zig_total` pro Schicht mit
- Betrifft nur `worktracker` (einziger Konsument, der diese Felder nutzt) — `tracking`/`feed`
  ignorieren die neuen Felder einfach, keine Breaking Changes
