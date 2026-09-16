---
date_created: 2026-09-16 22:44:00
type: changelog
tags:
  - project
  - changelog
date_modified: 2026-09-16 22:44:00
---

# v1.0.1 — Shared Design System versioniert + Style-Guide-Seite (2026-09-16)
- `shared/bensn.css`/`bensn.js` erstmals nach `bensn-meta/shared/` gezogen und versioniert —
  vorher existierte nur eine Live-Kopie auf dem Server ohne Git-Historie (die referenzierte
  `snapshots/bensn-2026-04-27/shared/`-Kopie war 5 Monate veraltet)
- `.btn-pill`, `.btn-save`, `.btn-cancel` aus health/feed/tracking (fast-identisch dupliziert,
  ein Padding-Wert wich in tracking leicht ab) zentral in `shared/bensn.css` zusammengeführt;
  worktrackers ursprüngliche Inline-Styles ("Bearbeiten"/"+ Pause") auf dieselbe Klasse
  umgestellt — vorher gab es die Klasse dort gar nicht, nur wiederholten Inline-Style
- Neue Seite `design-system.html`: lebende Referenz aller Farben/Typografie/Komponenten über
  alle Frontends hinweg, inkl. Live-Theme-Editor (Farben live ändern, als CSS exportieren) und
  einem Abschnitt "Bekannte Inkonsistenzen" (u.a. `.btn-danger` vs. `.btn-pill.red`, zwei
  unvereinheitlichte Löschen-Buttons in worktracker, library.bensn.mes eigenständiges
  Formular-/Button-/Badge-System, uneinheitliche Border-Radius- und Label-Font-Size-Werte)
- Landing-Page um die fehlenden Karten `tracking.bensn.me`, `library.bensn.me`,
  `stream.bensn.me` ergänzt — waren trotz aktivem Betrieb nie auf der Übersicht
