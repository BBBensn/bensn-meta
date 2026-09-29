---
date_created: 2026-09-29 19:33:24
type: changelog
tags:
  - project
  - changelog
date_modified: 2026-09-29 19:33:24
---

# v1.0.10 — Mobile Stabilität in shared/ (2026-09-29)
- `bensn.js`: Blob-Animation pausiert bei fokussiertem Eingabefeld, versteckter Seite und `prefers-reduced-motion`; Resize klemmt die Positionen
- `bensn.js`: setzt `--vv-height`/`--vv-top` aus `visualViewport` (sichtbare Fläche über der iOS-Tastatur) für Bottom-Sheets
- `bensn.css`: Blob-Blur auf Touch-Geräten 90 → 50px
- `bensn.css`: Eingabefelder auf Touch-Geräten mind. 16px (verhindert iOS-Auto-Zoom, der zu seitlichem Scrollen führt)
- `bensn.css`: `overflow-x: clip` auch auf `html`, `overflow-wrap: break-word` auf `body`, `max-width: 100%` für Medien/`pre`
