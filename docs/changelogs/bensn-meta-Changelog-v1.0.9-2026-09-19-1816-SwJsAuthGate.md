---
date_created: 2026-09-19 18:16:00
type: changelog
tags:
  - project
  - changelog
date_modified: 2026-09-19 18:16:00
---

# v1.0.9 — sw.js/manifest.json nicht mehr hinterm Auth-Gate (2026-09-19)
- Kontext: `feed`/`health`/`tracking` bekamen gerade einen Bugfix für einen kaputten
  Service Worker (siehe deren Changelogs v2.7.3/v1.6.3/v1.6.3) — nach dem Deploy
  funktionierte alles am MacBook, aber ein iPhone blieb weiterhin komplett hängen
- Ursache gefunden: `/sw.js` lag in allen drei Nginx-Configs unter der allgemeinen
  `location /`, die per `auth_request` einen gültigen Login-Cookie verlangt. Der Browser
  prüft im Hintergrund periodisch auf ein neues `sw.js`, **ohne dass dabei zwingend eine
  aktive Nutzer-Session vorliegt**. War das Cookie in genau diesem Moment abgelaufen oder
  fehlerhaft, bekam der Update-Check eine HTML-Login-Seite statt Javascript zurück — das
  Service-Worker-Update schlägt dabei still fehl (kein sichtbarer Fehler), und der Browser
  bleibt dauerhaft auf der alten, im Zweifel kaputten Service-Worker-Version hängen
- Fix: neue `location = /sw.js`/`location = /manifest.json` Blöcke in allen drei Configs,
  explizit VOR der allgemeinen `location /`, ohne `auth_request` — diese beiden Dateien
  enthalten keine privaten Daten und müssen für den Update-Mechanismus jederzeit ohne
  Session erreichbar sein (gleiches Prinzip wie die bereits bestehende `/shared/`-Ausnahme)
- `/sw.js` bekommt zusätzlich `Cache-Control: no-cache`, damit Browser bei jeder Prüfung
  wirklich den aktuellen Stand sehen und nicht durch eine zwischengespeicherte Antwort
  erneut hängen bleiben
- Lokale Config-Spiegel unter `nginx/feed.bensn.me`/`nginx/tracking.bensn.me` synchronisiert
  (`nginx/health.bensn.me` existierte hier nie als Datei — vorbestehende Lücke, nicht Teil
  dieses Fixes)
