# Database

**The SQL scripts the assessment asks for are in this directory:**

| File | What it is |
|---|---|
| [`schema.sql`](schema.sql) | Full DDL — all 10 tables, foreign keys, indexes and CHECK constraints |
| [`seed.sql`](seed.sql) | Demo data — accounts, currencies, rates, customers, the barcoded catalogue and six sample invoices |
| [`schema_description.md`](schema_description.md) | `DESCRIBE` and `SHOW CREATE TABLE` output for every table |
| [`screenshots/`](screenshots) | Screenshots of the tables in MySQL Workbench |

They are **byte-for-byte copies** of the Flyway migrations the application actually runs:

```
backend/src/main/resources/db/migration/V1__schema.sql   ->  database/schema.sql
backend/src/main/resources/db/migration/V2__seed.sql     ->  database/seed.sql
```

The migrations are the executable source of truth — the API applies them itself on start-up — and
these copies exist so the scripts can be read and run on their own. CI fails the build if the two
ever drift apart:

```bash
./scripts/check-sql-mirror.sh          # verify they match
./scripts/check-sql-mirror.sh --fix    # re-copy the migrations over the mirrors
```

---

## Running them

### Option 1 — let the application do it (recommended)

Flyway runs on start-up. Point the API at an empty MySQL 8 schema and it creates and seeds
everything, recording what it applied in `flyway_schema_history` so a second start is a no-op:

```bash
docker compose up --build          # MySQL + API together
# or, against your own MySQL:
cd backend && ./mvnw spring-boot:run
```

### Option 2 — run the scripts by hand

Useful for inspecting the schema, or for taking screenshots against a database the application has
never touched.

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p -e \
  "CREATE DATABASE triosuite CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"

mysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 triosuite < database/schema.sql
mysql -h 127.0.0.1 -P 3306 -u root -p --default-character-set=utf8mb4 triosuite < database/seed.sql
```

`--default-character-set=utf8mb4` matters: the seed contains the ₪, € and £ symbols, and the client
will mangle them under a narrower charset.

Order matters too — `seed.sql` assumes the tables from `schema.sql` exist. Neither script creates
the database itself, so that both can be applied to a schema whose name and collation you choose.

### Verifying it worked

```sql
SELECT COUNT(*) FROM items;                  -- 15
SELECT COUNT(*) FROM invoices;               -- 6
SELECT * FROM invoice_sequences;             -- INV / 2026 / 7

-- every invoice's stored total must equal the sum of its lines
SELECT i.invoice_number,
       i.grand_total,
       SUM(l.gross_amount) AS sum_of_lines
FROM invoices i
JOIN invoice_lines l ON l.invoice_id = i.id
GROUP BY i.id, i.invoice_number, i.grand_total
HAVING i.grand_total <> SUM(l.gross_amount);  -- must return no rows
```

`SeededInvoiceTotalsIT` asserts the same thing on every build, re-deriving all six invoices with the
production `InvoiceCalculator`, so the demo data can never quietly stop adding up.

---

## The local development instance

The development machine for this project could not run Docker — hardware virtualization is disabled
in firmware, so Docker Desktop's WSL2 backend will not start (see
[`docs/PROGRESS.md`](../docs/PROGRESS.md)). A dedicated MySQL 8.4.9 instance was started from the
already-installed server binaries instead, on **port 3307**, with its own data directory, leaving
the machine's existing `MySQL84` service on 3306 untouched.

| | |
|---|---|
| Host / port | `127.0.0.1:3307` |
| Databases | `triosuite` (development), `triosuite_test` (integration tests) |
| Application user | `triosuite` / `triosuite_dev_pw` |
| Data directory | `%LOCALAPPDATA%\triosuite-mysql\data` |
| Config | `%LOCALAPPDATA%\triosuite-mysql\my.ini` |

**Creating it.** `scripts/run-local.ps1` does this the first time it runs, so normally you never do
it by hand: it finds the installed MySQL 8 binaries, initialises a data directory of its own, writes
the `my.ini` above, starts the server, and creates both databases and the application user.

```powershell
.\scripts\run-local.ps1 -DatabaseOnly     # first run creates it; later runs just start it
.\scripts\run-local.ps1 -Reinitialize     # throw it away and build a clean one
```

Nothing about this touches an existing MySQL installation or its data — different port, different
data directory, different `my.ini`.

**Starting it** later is the same command, or directly:

```powershell
& "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysqld.exe" `
    --defaults-file="$env:LOCALAPPDATA\triosuite-mysql\my.ini"
```

It is not registered as a Windows service, so it does not come back by itself after a reboot.

These credentials are development-only defaults baked into the `local` and `test` profiles so the
project runs with no setup. Nothing outside those two profiles has a default: the `prod` profile
refuses to start unless `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` and `JWT_SECRET` are all supplied.

**To connect MySQL Workbench** (which is what the screenshots below were taken with): new
connection, hostname `127.0.0.1`, port `3307`, username `triosuite`, password `triosuite_dev_pw`,
default schema `triosuite`.

---

## Screenshots

The assessment asks for screenshots of the database tables. They are in
[`screenshots/`](screenshots) — one per table, showing its structure in MySQL Workbench's **Table
Inspector → Columns**:

`table_users.png` · `table_refresh_tokens.png` · `table_currencies.png` ·
`table_currency_exchange_rates.png` · `table_customers.png` · `table_items.png` ·
`table_app_settings.png` · `table_invoice_sequences.png` · `table_invoices.png` ·
`table_invoice_lines.png` · `table_flyway_schema_history.png`

All ten application tables, plus the migration history table Flyway creates. Each shot also has the
Navigator expanded on `triosuite → Tables`, so the full schema is visible in every one.

For the same detail as text — every column, type, key and constraint — see
[`schema_description.md`](schema_description.md). [`screenshots/README.md`](screenshots/README.md)
explains how to retake them.

---

## Schema at a glance

Full diagram in [`docs/ERD.md`](../docs/ERD.md); full DDL in [`schema.sql`](schema.sql).

| Table | Purpose |
|---|---|
| `users` | Accounts. BCrypt password hashes, `ADMIN` or `SALES`. No self-registration. |
| `refresh_tokens` | SHA-256 hashes of issued refresh tokens, with expiry and revocation. |
| `currencies` | ISO 4217 codes with their symbol and **minor units**, which drive every rounding decision. |
| `currency_exchange_rates` | The rate suggested for a new invoice. Never read back once an invoice is saved. |
| `customers` | Billing parties. Deactivated, never deleted, because invoices reference them for ever. |
| `items` | The catalogue. `barcode` is unique and is what the scanner looks up. |
| `app_settings` | Exactly one row, pinned by a CHECK on the primary key. Base currency and defaults. |
| `invoice_sequences` | One counter per prefix and year, locked with `SELECT … FOR UPDATE` during numbering. |
| `invoices` | The aggregate root. Snapshots its exchange rate and all four totals; carries the optimistic-lock `version`. |
| `invoice_lines` | Priced lines. Snapshot the item's name, barcode, price and tax rate so an issued invoice never changes. |

Three conventions run through all of it:

- **Money is never a float.** `DECIMAL(19,4)` for amounts, `DECIMAL(19,6)` for exchange rates,
  `DECIMAL(5,4)` for tax rates, `DECIMAL(12,3)` for quantities.
- **Time is always UTC.** `DATETIME(6)` throughout, written with `hibernate.jdbc.time_zone=UTC`,
  serialised as ISO-8601 with a trailing `Z`, and formatted to the device's locale by the app.
- **The database defends itself.** Every foreign key and lookup column is indexed, and CHECK
  constraints enforce the enum values, non-negative amounts and positive quantities — so the data
  stays correct even if a row is ever written by something other than this application.
