#!/usr/bin/env python3
"""Relève les jauges Claude (session 5 h et semaine) et les ajoute à data/claude.csv.

Utilise l'endpoint non documenté https://api.anthropic.com/api/oauth/usage,
le même que lisent les barres d'état communautaires de Claude Code.
Aucun appel au modèle : ça ne consomme pas de crédit.

Usage :
    python3 collecteur/claude_usage.py          # relève + commit + push
    python3 collecteur/claude_usage.py --no-git # relève seulement
"""
import csv
import json
import os
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CSV_PATH = REPO / "data" / "claude.csv"
URL = "https://api.anthropic.com/api/oauth/usage"


def lire_jeton():
    # Linux / Windows (WSL) : fichier de Claude Code
    fichier = Path.home() / ".claude" / ".credentials.json"
    brut = None
    if fichier.exists():
        brut = fichier.read_text()
    elif sys.platform == "darwin":
        # macOS : Trousseau
        brut = subprocess.run(
            ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
            capture_output=True, text=True, check=True,
        ).stdout
    if not brut:
        sys.exit("Identifiants Claude Code introuvables : connecte-toi d'abord dans Claude Code.")
    return json.loads(brut)["claudeAiOauth"]["accessToken"]


def relever():
    req = urllib.request.Request(URL, headers={
        "Authorization": f"Bearer {lire_jeton()}",
        "anthropic-beta": "oauth-2025-04-20",
        "Content-Type": "application/json",
    })
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


def main():
    d = relever()
    h5 = d.get("five_hour") or {}
    s7 = d.get("seven_day") or {}
    ligne = [
        datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        h5.get("utilization", ""), h5.get("resets_at") or "",
        s7.get("utilization", ""), s7.get("resets_at") or "",
    ]
    with CSV_PATH.open("a", newline="") as f:
        csv.writer(f).writerow(ligne)
    print("Relevé :", ligne)

    if "--no-git" in sys.argv:
        return
    git = lambda *a: subprocess.run(["git", "-C", str(REPO), *a], check=True)
    git("pull", "--rebase", "--autostash", "-q")
    git("add", str(CSV_PATH))
    git("commit", "-q", "-m", "Relevé Claude")
    git("push", "-q")


if __name__ == "__main__":
    main()
