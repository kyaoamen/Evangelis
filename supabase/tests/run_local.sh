#!/usr/bin/env bash
# Runs all migrations + seed + behaviour tests on a throwaway local Postgres.
# Needs PostgreSQL 15+ server binaries (initdb, pg_ctl). Usage: supabase/tests/run_local.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"
bin="${PG_BIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
tmp="$(mktemp -d)"
port="${PG_PORT:-54329}"
run_pg() { if [ "$(id -u)" = 0 ]; then su postgres -s /bin/bash -c "$*"; else bash -c "$*"; fi; }
cleanup() { run_pg "'$bin/pg_ctl' -D '$tmp/data' -m immediate stop" >/dev/null 2>&1 || true; rm -rf "$tmp"; }
trap cleanup EXIT
[ "$(id -u)" = 0 ] && chown postgres "$tmp"
run_pg "'$bin/initdb' -D '$tmp/data' -U postgres -A trust >/dev/null"
run_pg "'$bin/pg_ctl' -D '$tmp/data' -o '-p $port -k $tmp' -l '$tmp/log' -w start >/dev/null"

psql_() { psql -h "$tmp" -p "$port" -U postgres -d postgres -v ON_ERROR_STOP=1 -q "$@"; }
psql_ -f "$here/supabase_stub.sql"
for f in "$root"/migrations/*.sql; do echo "migrate: $(basename "$f")"; psql_ -f "$f"; done
psql_ -f "$root/seed.sql"
echo "seed: ok"
psql_ -o /dev/null -f "$here/rls_test.sql" 2>&1 | sed 's/^psql:[^ ]* NOTICE:  /  /'
