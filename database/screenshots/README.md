# Database screenshots

The assessment asks for screenshots of the database tables. They belong in this directory, under
these exact filenames — the root `README.md` already lists them.

| File | What to capture |
|---|---|
| `01_schema_overview.png` | The schema tree expanded, showing all 10 tables |
| `table_users.png` | Structure of `users` |
| `table_refresh_tokens.png` | Structure of `refresh_tokens` |
| `table_currencies.png` | Structure of `currencies` |
| `table_currency_exchange_rates.png` | Structure of `currency_exchange_rates` |
| `table_customers.png` | Structure of `customers` |
| `table_items.png` | Structure of `items` |
| `table_app_settings.png` | Structure of `app_settings` |
| `table_invoice_sequences.png` | Structure of `invoice_sequences` |
| `table_invoices.png` | Structure of `invoices` |
| `table_invoice_lines.png` | Structure of `invoice_lines` |
| `data_invoices.png` | Rows of `invoices` — all three statuses visible |
| `data_invoice_lines.png` | Rows of `invoice_lines` |

## Taking them

**Connect MySQL Workbench** to the database. For the local development instance documented in
[`../README.md`](../README.md): hostname `127.0.0.1`, port `3307`, username `triosuite`, password
`triosuite_dev_pw`, default schema `triosuite`.

Then, in the Navigator:

- **`01_schema_overview.png`** — expand `triosuite → Tables` so all ten are listed, and capture the
  panel.
- **`table_<name>.png`** — right-click the table → **Table Inspector** → the **Columns** tab.
- **`data_invoices.png` / `data_invoice_lines.png`** — right-click the table → **Select Rows**.

For the two data shots, widen the result grid enough that the interesting columns are legible:
`invoice_number`, `currency_code`, `tax_mode`, `status` and the four totals for `invoices`;
`item_name_snapshot`, `quantity`, `unit_price`, `tax_rate` and the three amounts for
`invoice_lines`.

## If the database is empty

The screenshots should show the seeded demo data — six invoices across all three statuses, fifteen
items, five currencies. Either start the backend once (Flyway seeds it automatically) or apply the
scripts by hand:

```bash
mysql -h 127.0.0.1 -P 3307 -u triosuite -p --default-character-set=utf8mb4 triosuite < database/schema.sql
mysql -h 127.0.0.1 -P 3307 -u triosuite -p --default-character-set=utf8mb4 triosuite < database/seed.sql
```
