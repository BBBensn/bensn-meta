---
date_created: 2026-09-17 04:11:00
type: changelog
tags:
  - project
  - changelog
date_modified: 2026-09-17 04:11:00
---

# v1.0.7 — Fix: Ø-Werte pro Schichttyp mittelten über einzelne Pausen (2026-09-17)
- Bei der Suche nach dem v1.0.6-Bug (14.04.-Schicht) aufgefallen: `/api/stats/shift-summary`
  berechnete `avg_break_minutes`/`avg_cigarettes`/`avg_spicy` als Durchschnitt über einzelne
  Pausen (`AVG(AVG(...))`) statt als Durchschnitt der Pro-Schicht-Summe. Ergebnis war z.B.
  "Ø 14min Pause" für "früh", obwohl die tatsächliche Ø-Gesamtpause pro Schicht bei 52-76min lag
  (abhängig davon, ob der v1.0.6-Fix schon aktiv war) — Zigaretten-Ø war ebenso ~5x zu niedrig
- Fix: Query summiert jetzt zuerst pro Schicht (`SUM` statt `AVG` in der Subquery), erst danach
  wird über die Schichten gemittelt — Ergebnis jetzt konsistent mit der bereits korrekten
  "Ø Netto/Pause pro Schicht"-Berechnung in der "Gesamt"-Card
- Nebenbei verifiziert: keine aktiven (nicht-gelöschten) Duplikat-Pausen mehr in der DB —
  die 3 historischen Duplikat-Fälle (14.04., 13.07., 08.06.) waren bereits händisch per
  Soft-Delete bereinigt, bevor dieser Fix kam
