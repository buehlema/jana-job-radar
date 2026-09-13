#!/usr/bin/env bash
# Aktualisiert index.html aus /tmp/radar.json (oder $1):
#   - pflegt leads.json (merkt pro Stelle das DATUM DES ERSTEN AUFTAUCHENS)
#   - rendert die dated Leads-Liste zwischen <!-- LEADS-START/END -->
#   - setzt die Zusammenfassungszeile zwischen <!-- TAGESLAUF-START/END -->
#   - setzt das "Stand"-Datum in Kopf-/Fußzeile auf HEUTE
#
# radar.json-Format:
# { "caveat": "kurzer ehrlicher Hinweis (HTML inline erlaubt: <b> <i> &amp; &nbsp;)",
#   "leads": [ {"org":"...","role":"...","url":"https://...","ort":"...","status":"ungeprüft"}, ... ] }
#
# Aufruf:  bash update.sh [radar.json]   (Default: /tmp/radar.json)
set -euo pipefail
cd "$(dirname "$0")"
RADAR="${1:-/tmp/radar.json}"
[ -f "$RADAR" ] || { echo "FEHLER: $RADAR nicht gefunden — index.html unverändert."; exit 1; }
[ -f leads.json ] || echo '{}' > leads.json

RADAR_FILE="$RADAR" python3 - <<'PY'
import os, re, io, json, datetime

radar_path = os.environ["RADAR_FILE"]
try:
    radar = json.load(io.open(radar_path, encoding="utf-8"))
except Exception as e:
    raise SystemExit(f"FEHLER: {radar_path} ist kein gültiges JSON ({e}) — Abbruch, index.html unverändert.")

leads_in = radar.get("leads") or []
caveat   = (radar.get("caveat") or "").strip()
if not isinstance(leads_in, list):
    raise SystemExit("FEHLER: 'leads' ist keine Liste — Abbruch.")

today = datetime.date.today()
ISO = today.isoformat()
ABBR = ["", "Jan.","Feb.","März","Apr.","Mai","Juni","Juli","Aug.","Sept.","Okt.","Nov.","Dez."]
FULL = ["", "Januar","Februar","März","April","Mai","Juni","Juli","August","September","Oktober","November","Dezember"]
d, m, y = today.day, today.month, today.year
EYE  = f"Stand {d}. {ABBR[m]} {y}"      # Kopfzeile
FOOT = f"Stand {d}. {FULL[m]} {y}"      # Fußzeile

def key_of(l):
    u = (l.get("url") or "").strip()
    if u.startswith("http"):
        return u
    return f"{(l.get('org') or '').strip()}|{(l.get('role') or '').strip()}"

def de_date(iso):
    dt = datetime.date.fromisoformat(iso)
    return f"{dt.day:02d}.{dt.month:02d}.{dt.year}"

# --- State laden & mergen (first_seen bleibt erhalten) ---
state = json.load(io.open("leads.json", encoding="utf-8"))
current = []
for l in leads_in:
    k = key_of(l)
    if not k or k == "|":
        continue
    rec = state.get(k, {})
    first_seen = rec.get("first_seen", ISO)   # bereits bekannt? Datum behalten, sonst heute
    state[k] = {
        "first_seen": first_seen,
        "last_seen": ISO,
        "org": (l.get("org") or rec.get("org") or "").strip(),
        "role": (l.get("role") or rec.get("role") or "").strip(),
        "url": (l.get("url") or rec.get("url") or "").strip(),
        "ort": (l.get("ort") or rec.get("ort") or "").strip(),
        "status": (l.get("status") or "ungeprüft").strip(),
    }
    current.append((k, state[k]))

json.dump(state, io.open("leads.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)

# --- Leads-Liste rendern ---
def esc(s):
    return (s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

items = []
for k, r in current:
    fs = de_date(r["first_seen"])
    name = esc(r["org"])
    if r["role"]:
        name += " — " + esc(r["role"])
    meta = " · ".join([x for x in [esc(r.get("ort","")), r.get("status","ungeprüft")] if x])
    badge = f'<span class="jl-badge" title="erstmals im Portal gesehen">seit&nbsp;{fs}</span>'
    inner = f'<span><span class="jl-name">{name}</span><br><span class="jl-desc">{meta}</span></span>'
    url = r.get("url","")
    if url.startswith("http"):
        items.append(f'<a class="joblink" href="{esc(url)}" target="_blank" rel="noopener">{badge}{inner}<span class="jl-arrow">↗</span></a>')
    else:
        items.append(f'<div class="joblink">{badge}{inner}</div>')

if items:
    leads_html = (f'<p class="jl-h" style="margin-top:6px">Aktuelle Leads · '
                  f'Datum = erstmals im Portal gesehen · alle ungeprüft, vor Bewerbung Originalseite öffnen</p>\n      '
                  + "\n      ".join(items))
else:
    leads_html = ('<p class="sec-intro" style="font-size:.9rem">Heute kein Lead im Portal gefunden.</p>')

# --- Zusammenfassungszeile (Tageslauf-Block) ---
n = len(current)
summary = (f'<p class="sec-intro" style="margin-top:-8px;font-size:.9rem">'
           f'<b>Stand {d}.&nbsp;{ABBR[m]}:</b> {n} ungeprüfte Lead(s) im Portal, '
           f'jeweils mit Datum des ersten Auftauchens (siehe Liste unten).'
           + ((" " + caveat) if caveat else "")
           + '</p>')

html = io.open("index.html", encoding="utf-8").read()
html = re.sub(r"<!-- TAGESLAUF-START -->.*?<!-- TAGESLAUF-END -->",
              lambda mo: f"<!-- TAGESLAUF-START -->\n      {summary}\n      <!-- TAGESLAUF-END -->",
              html, count=1, flags=re.S)
html = re.sub(r"<!-- LEADS-START -->.*?<!-- LEADS-END -->",
              lambda mo: f"<!-- LEADS-START -->\n      {leads_html}\n      <!-- LEADS-END -->",
              html, count=1, flags=re.S)
html = re.sub(r"Stand \d+\. [A-Za-zä.]+ \d{4} · Runde", EYE + " · Runde", html, count=1)
html = re.sub(r"Stand \d+\. [A-Za-zä]+ \d{4}, Runde", FOOT + ", Runde", html, count=1)
io.open("index.html", "w", encoding="utf-8").write(html)
print(f"OK: {n} Leads gerendert, {EYE}.")
PY
