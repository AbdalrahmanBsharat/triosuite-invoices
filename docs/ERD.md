# Entity relationship diagram

Ten tables. The full DDL is in [`database/schema.sql`](../database/schema.sql); column-by-column
output from the live database is in
[`database/schema_description.md`](../database/schema_description.md).

```mermaid
erDiagram
    users ||--o{ refresh_tokens : "issues"
    users ||--o{ invoices : "created_by"
    users ||--o{ invoices : "approved_by"
    users ||--o{ invoices : "cancelled_by"

    currencies ||--o| currency_exchange_rates : "quoted at"
    currencies ||--o{ items : "priced in"
    currencies ||--o{ invoices : "issued in"
    currencies ||--o{ app_settings : "base and default"

    customers ||--o{ invoices : "billed to"

    invoices ||--o{ invoice_lines : "contains"
    items ||--o{ invoice_lines : "snapshotted onto"

    users {
        bigint id PK
        varchar_50 username UK
        varchar_255 email UK
        char_60 password_hash "BCrypt, strength 12"
        varchar_150 full_name
        varchar_10 role "ADMIN | SALES"
        tinyint_1 is_active
        datetime_6 created_at
        datetime_6 updated_at
    }

    refresh_tokens {
        bigint id PK
        bigint user_id FK
        char_64 token_hash UK "SHA-256, hex"
        datetime_6 expires_at
        datetime_6 revoked_at "null until used or revoked"
        datetime_6 created_at
    }

    currencies {
        char_3 code PK "ISO 4217"
        varchar_60 name
        varchar_8 symbol
        int minor_units "2 or 3 - drives all rounding"
        tinyint_1 is_active
    }

    currency_exchange_rates {
        char_3 currency_code PK_FK
        decimal_19_6 rate_to_base "base units per 1 unit"
        datetime_6 updated_at
    }

    customers {
        bigint id PK
        varchar_200 name
        varchar_255 email
        varchar_40 phone
        varchar_500 address
        tinyint_1 is_active
        datetime_6 created_at
        datetime_6 updated_at
    }

    items {
        bigint id PK
        varchar_50 sku UK
        varchar_64 barcode UK "EAN-13, nullable"
        varchar_200 name
        decimal_19_4 unit_price
        char_3 currency_code FK
        decimal_5_4 tax_rate "0.1600 = 16%"
        tinyint_1 is_active
        datetime_6 created_at
        datetime_6 updated_at
    }

    app_settings {
        tinyint id PK "CHECK id = 1"
        char_3 base_currency_code FK "reporting currency"
        char_3 default_currency_code FK
        varchar_10 default_tax_mode "EXCLUSIVE | INCLUSIVE"
        decimal_5_4 default_tax_rate
        varchar_10 invoice_number_prefix "INV"
        datetime_6 updated_at
    }

    invoice_sequences {
        varchar_10 prefix PK
        int year PK "counter resets per year"
        bigint next_value "locked FOR UPDATE"
    }

    invoices {
        bigint id PK
        varchar_20 invoice_number UK "INV-YYYY-000001"
        bigint customer_id FK
        char_3 currency_code FK
        decimal_19_6 exchange_rate "snapshot"
        varchar_10 tax_mode "EXCLUSIVE | INCLUSIVE"
        varchar_10 status "DRAFT | APPROVED | CANCELLED"
        date issue_date "its year selects the sequence"
        varchar_1000 notes
        decimal_19_4 subtotal "sum of rounded line nets"
        decimal_19_4 tax_total "sum of rounded line taxes"
        decimal_19_4 grand_total "sum of rounded line grosses"
        decimal_19_4 grand_total_base "grand_total x exchange_rate"
        bigint created_by FK
        bigint approved_by FK
        datetime_6 approved_at
        bigint cancelled_by FK
        datetime_6 cancelled_at
        varchar_500 cancellation_reason
        bigint version "optimistic lock"
        datetime_6 created_at
        datetime_6 updated_at
    }

    invoice_lines {
        bigint id PK
        bigint invoice_id FK "ON DELETE CASCADE"
        int line_no "unique within the invoice"
        bigint item_id FK
        varchar_200 item_name_snapshot
        varchar_64 barcode_snapshot
        decimal_12_3 quantity
        decimal_19_4 unit_price "snapshot"
        decimal_5_4 tax_rate "snapshot"
        decimal_19_4 net_amount
        decimal_19_4 tax_amount
        decimal_19_4 gross_amount
    }
```

---

## Why the model looks like this

**`invoice_lines` is deliberately denormalized.** It stores `item_name_snapshot`,
`barcode_snapshot`, `unit_price` and `tax_rate` copied from the catalogue at write time, alongside
the `item_id` foreign key. An approved invoice is a financial record: if it rendered live joins to
`items`, re-pricing or renaming a product would silently rewrite documents that were issued years
ago. The foreign key is kept for traceability, and items are deactivated rather than deleted so it
can never dangle. ([ADR-0004](DECISIONS.md#adr-0004--snapshot-columns-on-invoice-lines))

**`invoices.exchange_rate` is a snapshot too**, for the same reason. `currency_exchange_rates` only
ever supplies the value the Create screen pre-fills; the user may override it per invoice, and once
saved it is never read back from that table.
([ADR-0003](DECISIONS.md#adr-0003--money-rounding-and-the-units-of-the-exchange-rate))

**`invoice_sequences` exists instead of an `AUTO_INCREMENT`.** Numbers must be formatted
`INV-YYYY-000001` and restart every year, which no auto-increment column can do. Allocation locks
the matching row with `SELECT … FOR UPDATE` inside the same transaction that inserts the invoice, so
concurrent creates serialise on one short row lock and cannot be handed the same number. The unique
index on `invoices.invoice_number` is the last line of defence.
([ADR-0005](DECISIONS.md#adr-0005--invoice-numbering-uses-a-locked-sequence-row-not-auto_increment))

**`app_settings` is a table with exactly one row**, pinned by `CHECK (id = 1)`. A settings row is
relational data like anything else — it is referenced by two foreign keys into `currencies` — and
making the singleton a database constraint means no code path can create a second.

**`users` is referenced three times from `invoices`** — `created_by`, `approved_by`, `cancelled_by`
— because the audit trail is part of the domain, not incidental bookkeeping. Each is written in the
same transaction as the state change it describes, and
`CHECK (status <> 'CANCELLED' OR cancelled_by IS NOT NULL)` stops a cancellation ever being recorded
without an author.

**Nothing is ever deleted.** There is no DELETE endpoint for invoices; withdrawal is the
`CANCELLED` status, and cancelled invoices stay visible in the list under their status filter. The
only `ON DELETE CASCADE` in the schema is from `invoice_lines` to `invoices`, and it exists for
referential tidiness rather than because anything deletes invoices — plus `refresh_tokens` to
`users`, so removing an account cannot leave a usable session behind.
