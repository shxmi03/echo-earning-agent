#!/usr/bin/env bash
# Applies every migration to a throwaway Postgres and runs the access-rule checks.
# Usage: DATABASE_URL=postgres://... supabase/tests/run.sh   (the database must be empty)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
psql=(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q)
"${psql[@]}" -f "$here/auth_stub.sql"
for f in "$here"/../migrations/*.sql; do
  echo "migration $(basename "$f")"
  "${psql[@]}" -f "$f"
done
"${psql[@]}" -f "$here/rls_test.sql"
