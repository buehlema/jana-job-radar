#!/usr/bin/env bash
# Aktualisiert index.html: Tageslauf-Block + Datum (Kopf-/Fußzeile) auf HEUTE.
# Aufruf:  bash update.sh <datei-mit-tageslauf-innentext>
# Der Innentext ist reiner HTML-Satz-Inhalt OHNE <p> und OHNE "Tageslauf DD.:"-Prefix
# (z. B. "Der Cloud-Lauf meldete <b>sechs</b> ungeprüfte Leads …").
set -euo pipefail
cd "$(dirname "$0")"

BODY_FILE="${1:?Innentext-Datei fehlt}"
BODY="$(cat "$BODY_FILE")"

# --- deutsches Datum bestimmen ---
D=$(date +%-d)
M=$(date +%-m)
Y=$(date +%Y)
ABBR=(_ "Jan." "Feb." "März" "Apr." "Mai" "Juni" "Juli" "Aug." "Sept." "Okt." "Nov." "Dez.")
FULL=(_ "Januar" "Februar" "März" "April" "Mai" "Juni" "Juli" "August" "September" "Oktober" "November" "Dezember")
EYE="Stand ${D}. ${ABBR[$M]} ${Y}"          # Kopfzeile (.eyebrow)
FOOT="Stand ${D}. ${FULL[$M]} ${Y}"          # Fußzeile (.disc)
LABEL="Tageslauf ${D}.&nbsp;${ABBR[$M]}:"    # fetter Prefix im Block

# --- Tageslauf-Block zwischen den Markern ersetzen (deterministisch via Python) ---
export BODY LABEL
python3 - "$@" <<'PY'
import os, re, io
html = io.open("index.html", encoding="utf-8").read()
body  = os.environ["BODY"].strip()
label = os.environ["LABEL"]
para = ('<p class="sec-intro" style="margin-top:-8px;font-size:.9rem">'
        f'<b>{label}</b> {body}</p>')
block = f"<!-- TAGESLAUF-START -->\n      {para}\n      <!-- TAGESLAUF-END -->"
html = re.sub(r"<!-- TAGESLAUF-START -->.*?<!-- TAGESLAUF-END -->",
              lambda m: block, html, count=1, flags=re.S)
io.open("index.html", "w", encoding="utf-8").write(html)
PY

# --- Datum in Kopf- und Fußzeile ersetzen (unabhängig vom Vortagesdatum) ---
python3 - <<PY
import io, re
html = io.open("index.html", encoding="utf-8").read()
# Kopfzeile: "Stand 31. Aug. 2026 · Runde"
html = re.sub(r"Stand \d+\. [A-Za-zä.]+ \d{4} · Runde", "${EYE} · Runde", html, count=1)
# Fußzeile: "Stand 31. August 2026, Runde"
html = re.sub(r"Stand \d+\. [A-Za-zä]+ \d{4}, Runde", "${FOOT}, Runde", html, count=1)
io.open("index.html","w",encoding="utf-8").write(html)
PY

echo "index.html aktualisiert auf ${EYE}."
