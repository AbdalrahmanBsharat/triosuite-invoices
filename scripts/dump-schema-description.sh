#!/usr/bin/env bash
#
# Regenerates database/schema_description.md from a real MySQL database.
#
# Applies database/schema.sql and database/seed.sql to a throwaway schema, dumps DESCRIBE and
# SHOW CREATE TABLE for every table, then drops it again — so the output always describes exactly
# what the committed scripts produce, and never whatever state a development database happens to
# be in.
#
# Usage:
#   ./scripts/dump-schema-description.sh > database/schema_description.md
#
# Connection settings come from the environment, with defaults matching the local development
# instance documented in database/README.md:
#   MYSQL_BIN   directory holding the mysql client   (default: on PATH)
#   DB_HOST     default 127.0.0.1
#   DB_PORT     default 3307
#   DB_ADMIN_USER / DB_ADMIN_PASSWORD   an account that may CREATE and DROP a database
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MYSQL_BIN="${MYSQL_BIN:-}"
MYSQL="${MYSQL_BIN:+${MYSQL_BIN%/}/}mysql"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3307}"
DB_ADMIN_USER="${DB_ADMIN_USER:-root}"
DB_ADMIN_PASSWORD="${DB_ADMIN_PASSWORD:-triosuite_root_dev}"
SCRATCH_DB="${SCRATCH_DB:-triosuite_schema_doc}"

mysql_run() {
    "$MYSQL" --default-character-set=utf8mb4 \
        -h "$DB_HOST" -P "$DB_PORT" -u "$DB_ADMIN_USER" "-p${DB_ADMIN_PASSWORD}" "$@" 2>/dev/null
}

cleanup() {
    mysql_run -e "DROP DATABASE IF EXISTS \`${SCRATCH_DB}\`;" || true
}
trap cleanup EXIT

mysql_run -e "DROP DATABASE IF EXISTS \`${SCRATCH_DB}\`;
              CREATE DATABASE \`${SCRATCH_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
mysql_run --database="$SCRATCH_DB" < "${REPO_ROOT}/database/schema.sql"
mysql_run --database="$SCRATCH_DB" < "${REPO_ROOT}/database/seed.sql"

cat <<'HEADER'
# Schema description

`DESCRIBE` and `SHOW CREATE TABLE` for every table, taken from a database built by applying
`database/schema.sql` and `database/seed.sql` to an empty MySQL 8 schema.

Regenerate with:

```bash
./scripts/dump-schema-description.sh > database/schema_description.md
```

Row counts below are what the seed produces, so they double as an inventory of the demo data.
`flyway_schema_history` is not listed: it is Flyway's own bookkeeping table, created by the
migration tool rather than by these scripts.

---

## Summary

HEADER

mysql_run --database="$SCRATCH_DB" --table -e "
SELECT TABLE_NAME AS 'Table', ENGINE AS 'Engine', TABLE_COLLATION AS 'Collation'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = '${SCRATCH_DB}'
ORDER BY TABLE_NAME;" | sed 's/^/    /'

echo
echo "Seeded row counts:"
echo
mysql_run --database="$SCRATCH_DB" --table -e "
SELECT 'users' AS 'Table', COUNT(*) AS 'Rows' FROM users
UNION ALL SELECT 'currencies', COUNT(*) FROM currencies
UNION ALL SELECT 'currency_exchange_rates', COUNT(*) FROM currency_exchange_rates
UNION ALL SELECT 'app_settings', COUNT(*) FROM app_settings
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'items', COUNT(*) FROM items
UNION ALL SELECT 'invoices', COUNT(*) FROM invoices
UNION ALL SELECT 'invoice_lines', COUNT(*) FROM invoice_lines
UNION ALL SELECT 'invoice_sequences', COUNT(*) FROM invoice_sequences
UNION ALL SELECT 'refresh_tokens', COUNT(*) FROM refresh_tokens;" | sed 's/^/    /'

echo
echo "---"
echo

for table in $(mysql_run -N -B --database="$SCRATCH_DB" -e "SHOW TABLES;" | tr -d "\r"); do
    printf '## `%s`\n\n### Columns\n\n' "$table"
    mysql_run --database="$SCRATCH_DB" --table -e "DESCRIBE \`${table}\`;" | sed 's/^/    /'
    printf '\n### `SHOW CREATE TABLE`\n\n```sql\n'
    # --raw stops the batch formatter escaping the newlines inside the DDL.
    mysql_run -N -B --raw --database="$SCRATCH_DB" -e "SHOW CREATE TABLE \`${table}\`;" | cut -f2-
    printf ';\n```\n\n'
done
