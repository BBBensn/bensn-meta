#!/bin/bash
# bensn-auth Deploy Script
# Führe jeden Block einzeln aus und prüfe danach ob alles läuft.
# Server: root@178.104.133.228

SERVER="root@178.104.133.228"

echo "=== SCHRITT 1: Auth-Service deployen ==="
ssh $SERVER "mkdir -p /var/www/bensn-auth"
scp auth.py                  $SERVER:/var/www/bensn-auth/auth.py
scp bensn-auth.service       $SERVER:/etc/systemd/system/bensn-auth.service

echo "=== SCHRITT 2: Auth-Service starten ==="
ssh $SERVER "
  pip3 install flask gunicorn --break-system-packages 2>/dev/null
  systemctl daemon-reload
  systemctl enable bensn-auth
  systemctl restart bensn-auth
  sleep 2
  systemctl status bensn-auth --no-pager
"

echo "=== SCHRITT 3: Auth-Service lokal testen (vor SSL) ==="
ssh $SERVER "curl -s http://127.0.0.1:5003/auth/verify && echo 'OK' || echo 'FEHLER'"
# Erwartet: leere Antwort mit HTTP 401 (kein Cookie)

echo "=== SCHRITT 4: SSL-Zertifikat für auth.bensn.me holen ==="
echo ">>> Erst DNS setzen: auth.bensn.me → 178.104.133.228 bei World4You"
echo ">>> Dann ausführen:"
echo "ssh $SERVER 'certbot certonly --nginx -d auth.bensn.me'"

echo "=== SCHRITT 5: Nginx-Configs deployen ==="
scp nginx-auth.bensn.me      $SERVER:/etc/nginx/sites-enabled/auth.bensn.me
scp nginx-feed.bensn.me      $SERVER:/etc/nginx/sites-enabled/feed.bensn.me
scp nginx-worktracker.bensn.me $SERVER:/etc/nginx/sites-enabled/worktracker.bensn.me
scp nginx-location.bensn.me  $SERVER:/etc/nginx/sites-enabled/location.bensn.me
scp nginx-tracking.bensn.me  $SERVER:/etc/nginx/sites-enabled/tracking.bensn.me

echo "=== SCHRITT 6: Nginx testen und neu laden ==="
ssh $SERVER "nginx -t && systemctl reload nginx"

echo "=== SCHRITT 7: Frontends deployen ==="
scp feed-index.html          $SERVER:/var/www/feed/public/index.html
scp tracking-index.html      $SERVER:/var/www/tracking/index.html

echo "=== FERTIG ==="
echo "Teste: https://auth.bensn.me/auth/login"
echo "Teste: https://worktracker.bensn.me  (sollte zu Login redirecten)"
