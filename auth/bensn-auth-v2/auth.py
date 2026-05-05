"""
bensn-auth  —  Zentraler Auth-Service für bensn.me
Port 5003 · Cookie-basiert · 90 Tage Laufzeit

Endpoints:
  GET  /auth/verify      → 200 OK (Cookie gültig) | 401 (nicht eingeloggt)
  GET  /auth/login       → Login-HTML-Seite
  POST /auth/login       → Login verarbeiten, Cookie setzen, redirect
  POST /auth/logout      → Cookie löschen, redirect zu /auth/login
"""

from flask import Flask, request, make_response, redirect, url_for
import hashlib, hmac, secrets, time, json, os

app = Flask(__name__)

# ── Config ──────────────────────────────────────────────────────────────
USER     = "bensn"
PW_SALT  = "77cded09d4212e57568cdb7f0f224ed9"
PW_HASH  = "00bce9a17231e2776e4a0683017d8d1245d6ed258e7a0ade333ad629b2e48bc1"

# Secret zum Signieren der Tokens — bleibt konstant (sonst werden alle ausgeloggt nach Neustart)
TOKEN_SECRET = "4e374aba55526ca446d1121064ba4b6ab9a02949739b6a65dd92e1cdb682cbfc"

COOKIE_NAME     = "bensn_auth"
COOKIE_DOMAIN   = ".bensn.me"          # gilt für alle Subdomains
COOKIE_MAX_AGE  = 90 * 24 * 3600       # 90 Tage in Sekunden

# ── Token-Logik ──────────────────────────────────────────────────────────
def make_token(username: str) -> str:
    """Erstellt einen signierten Token: username|issued_at|signature"""
    issued = int(time.time())
    payload = f"{username}|{issued}"
    sig = hmac.new(TOKEN_SECRET.encode(), payload.encode(), hashlib.sha256).hexdigest()
    return f"{payload}|{sig}"

def verify_token(token: str) -> bool:
    """Prüft Token-Signatur und Ablaufzeit (90 Tage)."""
    if not token:
        return False
    try:
        parts = token.split("|")
        if len(parts) != 3:
            return False
        username, issued_str, sig = parts
        payload = f"{username}|{issued_str}"
        expected_sig = hmac.new(TOKEN_SECRET.encode(), payload.encode(), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(sig, expected_sig):
            return False
        issued = int(issued_str)
        if time.time() - issued > COOKIE_MAX_AGE:
            return False
        return True
    except Exception:
        return False

# ── Password-Check ────────────────────────────────────────────────────────
def check_password(username: str, password: str) -> bool:
    if username != USER:
        return False
    hashed = hashlib.pbkdf2_hmac("sha256", password.encode(), PW_SALT.encode(), 100000).hex()
    return hmac.compare_digest(hashed, PW_HASH)

# ── Endpoints ─────────────────────────────────────────────────────────────

@app.route("/auth/verify")
def verify():
    """Nginx auth_request ruft diesen Endpoint auf."""
    token = request.cookies.get(COOKIE_NAME, "")
    if verify_token(token):
        return "", 200
    return "", 401


@app.route("/auth/login", methods=["GET"])
def login_page():
    """Login-Seite — wird von Nginx als redirect Ziel verwendet."""
    next_url = request.args.get("next", "/")
    error    = request.args.get("error", "")
    html = f"""<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>bensn.me · Login</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=DM+Mono:wght@300;400;500&family=Syne:wght@400;500;700;800&display=swap" rel="stylesheet">
<style>
*,*::before,*::after{{box-sizing:border-box;margin:0;padding:0}}
:root{{
  --bg:#0a0a0b;--surface:#111113;--border:rgba(255,255,255,0.07);
  --border-hover:rgba(255,255,255,0.15);--text:#e8e6e0;--muted:#666660;
  --accent-blue:#00A6FB;--accent-red:#FF0051;--green:#4ade80;
}}
html,body{{min-height:100vh;background:var(--bg);color:var(--text);font-family:'Syne',sans-serif;overflow:hidden}}
.grid-bg{{
  position:fixed;inset:0;
  background-image:linear-gradient(rgba(255,255,255,.025) 1px,transparent 1px),
                   linear-gradient(90deg,rgba(255,255,255,.025) 1px,transparent 1px);
  background-size:64px 64px;pointer-events:none;z-index:0;
}}
.blobs{{position:fixed;inset:0;pointer-events:none;z-index:0;overflow:hidden}}
.blob{{position:absolute;border-radius:50%;filter:blur(90px);opacity:.22}}
.center{{
  position:relative;z-index:1;min-height:100vh;
  display:flex;align-items:center;justify-content:center;padding:1.5rem;
}}
.card{{
  background:var(--surface);border:1px solid var(--border);border-radius:20px;
  padding:2.25rem 2rem;width:100%;max-width:360px;
  animation:fadeUp .5s ease forwards;
}}
@keyframes fadeUp{{from{{opacity:0;transform:translateY(14px)}}to{{opacity:1;transform:none}}}}
.logo{{display:flex;align-items:center;gap:.75rem;margin-bottom:2rem}}
.logo-mark{{
  width:34px;height:34px;border:1px solid var(--border-hover);border-radius:8px;
  display:flex;align-items:center;justify-content:center;flex-shrink:0;
}}
.logo-text{{font-family:'DM Mono',monospace;font-size:14px;color:var(--muted)}}
.logo-text span{{color:var(--text)}}
h1{{font-size:1.4rem;font-weight:800;letter-spacing:-.02em;margin-bottom:.3rem}}
.sub{{font-family:'DM Mono',monospace;font-size:11px;color:var(--muted);margin-bottom:1.75rem}}
.field{{margin-bottom:.9rem}}
.field label{{
  display:block;font-family:'DM Mono',monospace;font-size:9px;
  letter-spacing:.1em;text-transform:uppercase;color:var(--muted);margin-bottom:5px;
}}
.field input{{
  width:100%;background:rgba(255,255,255,.04);border:1px solid var(--border);
  border-radius:10px;padding:10px 14px;color:var(--text);
  font-family:'DM Mono',monospace;font-size:13px;outline:none;
  transition:border-color .15s;
}}
.field input:focus{{border-color:var(--border-hover)}}
.error{{
  font-family:'DM Mono',monospace;font-size:11px;color:var(--accent-red);
  min-height:1.2em;margin-bottom:.7rem;
}}
.btn{{
  width:100%;background:var(--text);color:var(--bg);border:none;border-radius:10px;
  padding:11px;font-family:'Syne',sans-serif;font-size:.95rem;font-weight:700;
  cursor:pointer;transition:opacity .15s;
}}
.btn:hover{{opacity:.88}}
</style>
</head>
<body>
<div class="grid-bg"></div>
<div class="blobs">
  <div class="blob" style="width:480px;height:420px;background:#00A6FB;left:60%;top:5%"></div>
  <div class="blob" style="width:420px;height:360px;background:#FF0051;left:5%;top:55%"></div>
</div>
<div class="center">
  <div class="card">
    <div class="logo">
      <div class="logo-mark">
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none">
          <rect x="2" y="2" width="6" height="6" rx="1.5" fill="rgba(255,255,255,0.5)"/>
          <rect x="10" y="2" width="6" height="6" rx="1.5" fill="rgba(255,255,255,0.25)"/>
          <rect x="2" y="10" width="6" height="6" rx="1.5" fill="rgba(255,255,255,0.25)"/>
          <rect x="10" y="10" width="6" height="6" rx="1.5" fill="rgba(255,255,255,0.1)"/>
        </svg>
      </div>
      <span class="logo-text"><span>bensn</span>.me</span>
    </div>
    <h1>Willkommen zurück.</h1>
    <div class="sub">Persönliche Infrastruktur — nur für dich.</div>
    <form method="POST" action="/auth/login">
      <input type="hidden" name="next" value="{next_url}">
      <div class="field">
        <label>Benutzername</label>
        <input type="text" name="username" value="bensn" autocomplete="username" required>
      </div>
      <div class="field">
        <label>Passwort</label>
        <input type="password" name="password" autocomplete="current-password" required autofocus>
      </div>
      <div class="error">{'Falsches Passwort.' if error else ''}</div>
      <button class="btn" type="submit">Einloggen</button>
    </form>
  </div>
</div>
</body>
</html>"""
    return html, 200


@app.route("/auth/login", methods=["POST"])
def do_login():
    username = request.form.get("username", "").strip()
    password = request.form.get("password", "")
    next_url = request.form.get("next", "/")

    # next_url nur relative Pfade erlauben (keine open redirects)
    if not next_url.startswith("/"):
        next_url = "/"

    if not check_password(username, password):
        return redirect(f"/auth/login?next={next_url}&error=1")

    token = make_token(username)
    resp  = make_response(redirect(next_url))
    resp.set_cookie(
        COOKIE_NAME,
        token,
        max_age   = COOKIE_MAX_AGE,
        domain    = COOKIE_DOMAIN,
        path      = "/",
        secure    = True,
        httponly  = True,
        samesite  = "Lax",       # Lax statt Strict damit Redirects von extern funktionieren
    )
    return resp


@app.route("/auth/logout", methods=["POST", "GET"])
def logout():
    resp = make_response(redirect("/auth/login"))
    resp.set_cookie(
        COOKIE_NAME, "",
        max_age  = 0,
        domain   = COOKIE_DOMAIN,
        path     = "/",
        secure   = True,
        httponly = True,
        samesite = "Lax",
    )
    return resp


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5003, debug=False)
