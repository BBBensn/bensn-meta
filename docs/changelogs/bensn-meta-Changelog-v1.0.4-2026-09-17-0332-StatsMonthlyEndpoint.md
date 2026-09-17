---
date_created: 2026-09-17 03:32:00
type: changelog
tags:
  - project
  - changelog
date_modified: 2026-09-17 03:32:00
---

# v1.0.4 — Neuer Stats-Endpoint für worktracker (2026-09-17)
- Neuer Endpoint `GET /api/stats/monthly`: aggregiert alle abgeschlossenen Schichten nach Monat
  (Anzahl, Brutto-Arbeitsminuten, Pausenminuten, Zigaretten Spicy/Blend) — Grundlage für den neuen
  Stats-Tab in `worktracker` v2.3.0. Bestehender `/api/stats/shift-summary` unverändert wiederverwendet.
- Mit diesem Deploy zusammen ausgeliefert (bereits lokal vorhanden, unabhängig von dieser Änderung):
  `PATCH /api/stay/<id>` um optionales `note`-Feld erweitert, neuer Endpoint `PATCH /api/places/rename`
  zum Umbenennen/Zusammenführen von Location-Stay-Namen — dieser Teil ist noch ohne zugehöriges
  Frontend/Changelog im `location`-Repo, wurde hier nur mit deployed, weil er bereits unversioniert
  im Arbeitsverzeichnis lag
