#!/usr/bin/env bash
# Teste supabase/functions/lire-photo dans Deno, contre un faux Supabase et une fausse API Anthropic.
# Lancer depuis la racine du dépôt : bash tests/fonction.test.sh   (Deno est téléchargé via npm au besoin)
set -euo pipefail
ICI=$(cd "$(dirname "$0")" && pwd); F="$ICI/../supabase/functions/lire-photo/index.ts"
CACHE=${TMPDIR:-/tmp}/odm-deno; mkdir -p "$CACHE"; export DENO_DIR="$CACHE/cache"
[ -x "$CACHE/node_modules/.bin/deno" ] || (cd "$CACHE" && npm init -y >/dev/null && npm i -s deno@2.5.6 >/dev/null)
DENO="$CACHE/node_modules/.bin/deno"; RUN="${TMPDIR:-/tmp}/odm-deno-run"; mkdir -p "$RUN"   # hors de $CACHE : Deno ne doit trouver aucun package.json au-dessus
(cd "$RUN" && "$DENO" check "$F" >/dev/null 2>&1) && echo "✓ types vérifiés (deno check)" || { echo "✗ deno check"; exit 1; }
pkill -f "odm-deno.*deno run" 2>/dev/null || true; pkill -f fonction-mock.js 2>/dev/null || true   # restes d'un essai précédent
node "$ICI/fonction-mock.js" & M=$!
(cd "$RUN" && exec env SUPABASE_URL=http://localhost:8790 SUPABASE_ANON_KEY=x ANTHROPIC_API_KEY=k ANTHROPIC_BASE_URL=http://localhost:8790 \
  "$DENO" run --allow-net --allow-env "$F" >/dev/null 2>&1) & D=$!
trap 'kill $M $D 2>/dev/null; pkill -f "odm-deno.*deno run" 2>/dev/null; rm -f "$ICI/.derniere-requete.json"' EXIT
for i in $(seq 30); do curl -s -o /dev/null localhost:8000 && break; sleep 0.5; done
IMG=$(head -c 3000 /dev/urandom | base64 -w0); ko=0
verif() { if eval "$2"; then echo "✓ $1"; else echo "✗ $1 — réponse : ${R:0:200}"; ko=1; fi; }
R=$(curl -s -X POST localhost:8000 -H "Authorization: Bearer mauvais" -d "{\"image\":\"$IMG\"}")
verif "refuse sans connexion" '[[ $R == *"connexion requise"* ]]'
R=$(curl -s -X POST localhost:8000 -H "Authorization: Bearer bon" -d '{}')
verif "refuse sans image" '[[ $R == *"image manquante"* ]]'
R=$(curl -s -X POST localhost:8000 -H "Authorization: Bearer bon" -d "{\"image\":\"data:image/jpeg;base64,$IMG\",\"contexte\":\"Dernier index électrique connu : 467.33 kWh.\"}")
verif "renvoie la lecture" '[[ $R == *"\"index_kwh\":469.46"* ]]'
Q="$ICI/.derniere-requete.json"
verif "contexte transmis à Claude" 'grep -q "Relevés précédents : Dernier index électrique connu : 467.33" "$Q"'
verif "image envoyée en JPEG base64 sans préfixe" 'python3 -c "import json,sys;b=json.load(open(sys.argv[1]))[\"body\"];s=b[\"messages\"][0][\"content\"][0][\"source\"];sys.exit(0 if s[\"media_type\"]==\"image/jpeg\" and not s[\"data\"].startswith(\"data:\") else 1)" "$Q"'
verif "sortie JSON structurée et repli activés" 'python3 -c "import json,sys;d=json.load(open(sys.argv[1]));b=d[\"body\"];sys.exit(0 if b[\"output_config\"][\"format\"][\"type\"]==\"json_schema\" and b.get(\"fallbacks\")==\"default\" else 1)" "$Q"'
R=$(curl -s -i -X OPTIONS localhost:8000)
verif "autorise les appels du site (CORS)" '[[ $R == *"access-control-allow-origin: *"* ]]'
[ $ko = 0 ] && echo "Tous les tests de la fonction passent" || { echo "Des tests de la fonction échouent"; exit 1; }
