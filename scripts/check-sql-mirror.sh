#!/usr/bin/env bash
#
# The Flyway migrations are the executable source of truth; database/schema.sql and
# database/seed.sql are the copies the assessment asks to be delivered separately.
# They must stay byte-for-byte identical, so CI runs this on every push.
#
#   ./scripts/check-sql-mirror.sh          # verify
#   ./scripts/check-sql-mirror.sh --fix    # re-copy the migrations over the mirrors
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATIONS="${REPO_ROOT}/backend/src/main/resources/db/migration"
MIRRORS="${REPO_ROOT}/database"

PAIRS=(
    "V1__schema.sql:schema.sql"
    "V2__seed.sql:seed.sql"
)

if [ "${1:-}" = "--fix" ]; then
    for pair in "${PAIRS[@]}"; do
        cp "${MIGRATIONS}/${pair%%:*}" "${MIRRORS}/${pair##*:}"
        echo "updated database/${pair##*:}"
    done
    exit 0
fi

status=0
for pair in "${PAIRS[@]}"; do
    migration="${MIGRATIONS}/${pair%%:*}"
    mirror="${MIRRORS}/${pair##*:}"
    if diff -q "$migration" "$mirror" >/dev/null; then
        echo "ok    database/${pair##*:} matches ${pair%%:*}"
    else
        echo "FAIL  database/${pair##*:} has drifted from ${pair%%:*}" >&2
        diff -u "$migration" "$mirror" || true
        status=1
    fi
done

if [ "$status" -ne 0 ]; then
    echo >&2
    echo "Run ./scripts/check-sql-mirror.sh --fix to re-sync." >&2
fi
exit "$status"
