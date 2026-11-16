#!/usr/bin/env python3
"""Relève les jauges Claude (session 5 h et semaine) et les envoie dans Supabase.

Lit https://api.anthropic.com/api/oauth/usage, endpoint NON documenté utilisé par
les barres d'état communautaires de Claude Code (il peut changer sans prévenir).
Aucun appel au modèle : ça ne consomme pas de crédit.

Configuration : collecteur/config.json (voir config.exemple.json), jamais commité.
Usage : python claude_usage.py          (relève et envoie)
        python claude_usage.py --test   (relève et affiche, sans envoyer)
"""
import json
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path

ICI = Path(__file__).resolve().parent
JOURNAL = ICI / "log.txt"


def log(msg):
    ligne = f"{datetime.now():%Y-%m-%d %H:%M} {msg}"
    print(ligne)
    with JOURNAL.open("a", encoding="utf-8") as f:
        f.write(ligne + "\n")


def lire_jeton():
    # Windows et Linux : fichier de Claude Code ; macOS : Trousseau
    fichier = Path.home() / ".claude" / ".credentials.json"
    if fichier.exists():
        brut = fichier.read_text(encoding="utf-8")
    elif sys.platform == "darwin":
        brut = subprocess.run(
            ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
            capture_output=True, text=True, check=True).stdout
    else:
        sys.exit(f"Identifiants Claude Code introuvables ({fichier}). Connecte-toi d'abord dans Claude Code.")
    return json.loads(brut)["claudeAiOauth"]["accessToken"]


def requete(url, headers, corps=None):
    data = json.dumps(corps).encode() if corps is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method="POST" if data else "GET")
    with urllib.request.urlopen(req, timeout=20) as r:
        txt = r.read().decode()
        return json.loads(txt) if txt else None


def main():
    usage = requete("https://api.anthropic.com/api/oauth/usage", {
        "Authorization": f"Bearer {lire_jeton()}",
        "anthropic-beta": "oauth-2025-04-20",
    })
    h5 = usage.get("five_hour") or {}
    s7 = usage.get("seven_day") or {}
    releve = {
        "p_session_5h": h5.get("utilization"), "p_session_5h_reset": h5.get("resets_at"),
        "p_semaine": s7.get("utilization"), "p_semaine_reset": s7.get("resets_at"),
    }
    if "--test" in sys.argv:
        print("Relevé (non envoyé) :", releve)
        return

    cfg = json.loads((ICI / "config.json").read_text(encoding="utf-8"))
    url = cfg["supabase_url"].rstrip("/") + "/rest/v1/rpc/ajouter_releve_claude"
    try:
        requete(url, {"apikey": cfg["supabase_key"], "Content-Type": "application/json"},
                {"p_cle": cfg["cle_collecteur"], **releve})
    except urllib.error.HTTPError as e:
        log(f"ERREUR Supabase {e.code} : {e.read().decode()[:300]}")
        sys.exit(1)
    log(f"OK 5h={releve['p_session_5h']} % semaine={releve['p_semaine']} %")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # journalise tout pour le lancement planifié sans fenêtre
        log(f"ERREUR {type(e).__name__} : {e}")
        raise
