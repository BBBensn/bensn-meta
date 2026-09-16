---
date_created: 2026-09-16 23:27:00
type: changelog
tags:
  - project
  - changelog
date_modified: 2026-09-16 23:27:00
---

# v1.0.2 — Erste Inkonsistenzen aus dem Style-Guide aufgeräumt (2026-09-16)
- **Destruktiv-Button-in-Sheet:** tracking.bensn.mes eigenes `.btn-danger` (11px, 11×14px
  Padding) entfernt, ersetzt durch `.btn-pill.red` — dieselbe Rolle wie in health.bensn.me.
  worktrackers zwei eigene, sich unterscheidende Löschen-Inline-Styles (`deleteShift`,
  `deleteBreak`) ebenfalls auf `.btn-pill.red` umgestellt (in den jeweiligen Repos deployed,
  siehe deren Changelogs)
- **Border-Radius, 2-Stufen-Entscheidung für die Container/Tile-Familie:** klein = 12px
  (Tiles, Item-Reihen, Settings-Gruppen), groß = 16px (Cards). `.wt-stat`, `.wt-cig` (beide
  8px) und health.bensn.mes `.stat-card` (10px) waren die Ausreißer und wurden auf 12px
  angeglichen — passt jetzt zu `.item-card`/`.settings-cat`/`.quick-btn`/`.wt-shift-row`.
  `.card`/`.wt-card` waren schon beide 16px. Bewusst nicht angefasst: Radius bei Buttons/
  Inputs/Badges — andere Komponenten-Familie mit eigener, schon stimmiger Logik. Eine
  vollständige Zählung ergab >10 Radius-Werte systemweit, wenn man die mitzählt
- **9px-Labels auf 10px:** `.wt-stat-label`, `.wt-cig-label`, `.wt-table th`, health.bensn.mes
  `.stat-label` und `.pill` liefen auf 9px gegen die sonst übliche 10px — angeglichen.
  Bewusst nicht angefasst: worktrackers komplettes Formular-Label-System (13+ konsistente
  Stellen, eigener interner Standard) sowie einzelne 9px-Labels in feed/location — größerer,
  eigener Schritt
- `design-system.html` entsprechend aktualisiert: gelöste Punkte grün markiert, verbleibende
  amber, mit genauerer Beschreibung des tatsächlichen (größeren) Umfangs
