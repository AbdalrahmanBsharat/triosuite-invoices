# Database screenshots

The assessment asks for screenshots of the database tables. Here they are — the structure of every
table in the schema, captured in MySQL Workbench's **Table Inspector → Columns**.

| File | Table |
|---|---|
| [`table_users.png`](table_users.png) | `users` |
| [`table_refresh_tokens.png`](table_refresh_tokens.png) | `refresh_tokens` |
| [`table_currencies.png`](table_currencies.png) | `currencies` |
| [`table_currency_exchange_rates.png`](table_currency_exchange_rates.png) | `currency_exchange_rates` |
| [`table_customers.png`](table_customers.png) | `customers` |
| [`table_items.png`](table_items.png) | `items` |
| [`table_app_settings.png`](table_app_settings.png) | `app_settings` |
| [`table_invoice_sequences.png`](table_invoice_sequences.png) | `invoice_sequences` |
| [`table_invoices.png`](table_invoices.png) | `invoices` |
| [`table_invoice_lines.png`](table_invoice_lines.png) | `invoice_lines` |
| [`table_flyway_schema_history.png`](table_flyway_schema_history.png) | `flyway_schema_history` — Flyway's own bookkeeping, showing both migrations applied |

That is all ten application tables, plus the migration history table Flyway creates.

Every shot also has the Navigator open on the left with `triosuite → Tables` expanded, so the whole
schema is visible in each one — which is why there is no separate overview image.

The same information in text form, and easier to search, is in
[`../schema_description.md`](../schema_description.md): `DESCRIBE` and `SHOW CREATE TABLE` output
for every table, regenerated from the committed scripts by
[`../../scripts/dump-schema-description.sh`](../../scripts/dump-schema-description.sh).

## Retaking them

Connect MySQL Workbench to the development instance — hostname `127.0.0.1`, port `3307`, username
`triosuite`, password `triosuite_dev_pw`, default schema `triosuite` (see
[`../README.md`](../README.md)). Then right-click a table → **Table Inspector** → the **Columns**
tab.

If the database is empty, start the backend once and Flyway creates and seeds it, or apply the
scripts by hand:

```bash
mysql -h 127.0.0.1 -P 3307 -u triosuite -p --default-character-set=utf8mb4 triosuite < database/schema.sql
mysql -h 127.0.0.1 -P 3307 -u triosuite -p --default-character-set=utf8mb4 triosuite < database/seed.sql
```
