---
date_created: 2026-09-17 00:14:00
type: changelog
tags:
  - project
  - changelog
date_modified: 2026-09-17 00:14:00
---

# v1.0.3 — Hub-weites Strukturaufräumen (2026-09-17)
- **Größter Fund:** `stream/Library Dashboard/` war die tatsächliche, aktive Codebase von
  library.bensn.me (Repo `bensn-library-dashboard`, Backend/Frontend passen exakt zum live
  laufenden Service) — lag aber unter einem komplett irreführenden Pfad (Ordnername einer
  anderen Domain, Leerzeichen im Namen), weshalb sie bei jeder bisherigen Suche in diesem
  Repo übersehen wurde. Nach `library/` verschoben (Top-Level, wie alle anderen Apps),
  Git-Historie/Remote unverändert. Der jetzt leere `stream/`-Ordner wurde entfernt
  (stream.bensn.me ist ein reiner nginx-Proxy zu externem Jellyfin, braucht keinen lokalen Code)
- Stale `nginx-worktracker.conf` im Hub-Root entfernt — ein Pre-Certbot-Entwurf mit
  Platzhalter-SSL-Kommentaren, längst durch `nginx/worktracker.bensn.me` ersetzt
- **Icons korrigiert, nicht nur aufgeräumt:** worktracker und landing hatten lokal andere
  Icon-Dateien als tatsächlich live deployed (worktracker: komplett andere Icons unter einem
  falschen Ordnernamen `icon/` statt `icons/`, im HTML nirgends referenziert; landing: nie
  versionierte `/icons/`, nur ältere, andere Exports unter `logo/`). Beide Repos ziehen jetzt
  die echten, live laufenden Icons
- Top-Level `Icons/`-Ordner (Quelle für Feed/Tracking/Location/Worktracker/Bensn-Hub-Icons)
  entfernt — Inhalte waren längst in die jeweiligen App-Repos migriert, nur worktracker hinkte
  hinterher (siehe oben, jetzt behoben)
- Lose `.DS_Store`-Dateien im Hub-Root und den o.g. Ordnern entfernt (waren nirgends getrackt,
  reine lokale Artefakte)
- **Offen, nicht selbstständig entschieden:** `logo_project.af` existiert doppelt im Hub-Root
  UND in `landing/logo/` — unterschiedliche Dateien (unterschiedliche Größe, ~2 Wochen
  Zeitunterschied). Welche die aktuelle ist, kann nur der User beurteilen
