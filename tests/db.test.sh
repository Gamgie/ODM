#!/usr/bin/env bash
# Tests du schéma Supabase sur un Postgres local (imitation minimale de auth/storage/rôles).
# Lancer en root depuis la racine du dépôt : bash tests/db.test.sh
set -euo pipefail
ICI=$(cd "$(dirname "$0")" && pwd); D=/tmp/odm-pgtest; B=$(ls -d /usr/lib/postgresql/*/bin | tail -1)
rm -rf $D; mkdir -p $D; cp "$ICI/../supabase/schema.sql" "$ICI/db-mock.sql" "$ICI/db-assertions.sql" $D/; chown -R postgres $D
P="psql -h $D -p 5499 -U postgres -q -v ON_ERROR_STOP=1"
su postgres -c "$B/initdb -D $D/d -A trust >/dev/null && $B/pg_ctl -D $D/d -o '-k $D -p 5499 -c listen_addresses=' -l $D/log start >/dev/null"
trap 'su postgres -c "$B/pg_ctl -D $D/d stop -m fast >/dev/null"; rm -rf $D' EXIT
sleep 1
su postgres -c "$P -f $D/db-mock.sql && $P -f $D/schema.sql && $P -f $D/schema.sql && $P -f $D/db-assertions.sql" 2>&1 | { grep -v NOTICE || true; }
echo "Tous les tests de la base passent (schéma appliqué deux fois)"
