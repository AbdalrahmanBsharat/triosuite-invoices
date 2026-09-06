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

    +-------------------------+--------+--------------------+
    | Table                   | Engine | Collation          |
    +-------------------------+--------+--------------------+
    | app_settings            | InnoDB | utf8mb4_0900_ai_ci |
    | currencies              | InnoDB | utf8mb4_0900_ai_ci |
    | currency_exchange_rates | InnoDB | utf8mb4_0900_ai_ci |
    | customers               | InnoDB | utf8mb4_0900_ai_ci |
    | invoice_lines           | InnoDB | utf8mb4_0900_ai_ci |
    | invoice_sequences       | InnoDB | utf8mb4_0900_ai_ci |
    | invoices                | InnoDB | utf8mb4_0900_ai_ci |
    | items                   | InnoDB | utf8mb4_0900_ai_ci |
    | refresh_tokens          | InnoDB | utf8mb4_0900_ai_ci |
    | users                   | InnoDB | utf8mb4_0900_ai_ci |
    +-------------------------+--------+--------------------+

Seeded row counts:

    +-------------------------+------+
    | Table                   | Rows |
    +-------------------------+------+
    | users                   |    2 |
    | currencies              |    5 |
    | currency_exchange_rates |    5 |
    | app_settings            |    1 |
    | customers               |    6 |
    | items                   |   15 |
    | invoices                |    6 |
    | invoice_lines           |   14 |
    | invoice_sequences       |    1 |
    | refresh_tokens          |    0 |
    +-------------------------+------+

---

## `app_settings`

### Columns

    +-----------------------+--------------+------+-----+---------+-------+
    | Field                 | Type         | Null | Key | Default | Extra |
    +-----------------------+--------------+------+-----+---------+-------+
    | id                    | tinyint      | NO   | PRI | NULL    |       |
    | base_currency_code    | char(3)      | NO   | MUL | NULL    |       |
    | default_currency_code | char(3)      | NO   | MUL | NULL    |       |
    | default_tax_mode      | varchar(10)  | NO   |     | NULL    |       |
    | default_tax_rate      | decimal(5,4) | NO   |     | NULL    |       |
    | invoice_number_prefix | varchar(10)  | NO   |     | NULL    |       |
    | updated_at            | datetime(6)  | NO   |     | NULL    |       |
    +-----------------------+--------------+------+-----+---------+-------+

### `SHOW CREATE TABLE`

```sql
CREATE TABLE `app_settings` (
  `id` tinyint NOT NULL,
  `base_currency_code` char(3) NOT NULL COMMENT 'reporting currency',
  `default_currency_code` char(3) NOT NULL,
  `default_tax_mode` varchar(10) NOT NULL,
  `default_tax_rate` decimal(5,4) NOT NULL,
  `invoice_number_prefix` varchar(10) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_app_settings_base_currency_code` (`base_currency_code`),
  KEY `ix_app_settings_default_currency_code` (`default_currency_code`),
  CONSTRAINT `fk_app_settings_base_currency` FOREIGN KEY (`base_currency_code`) REFERENCES `currencies` (`code`),
  CONSTRAINT `fk_app_settings_default_currency` FOREIGN KEY (`default_currency_code`) REFERENCES `currencies` (`code`),
  CONSTRAINT `ck_app_settings_prefix` CHECK ((char_length(`invoice_number_prefix`) >= 1)),
  CONSTRAINT `ck_app_settings_singleton` CHECK ((`id` = 1)),
  CONSTRAINT `ck_app_settings_tax_mode` CHECK ((`default_tax_mode` in (_utf8mb4'EXCLUSIVE',_utf8mb4'INCLUSIVE'))),
  CONSTRAINT `ck_app_settings_tax_rate` CHECK (((`default_tax_rate` >= 0) and (`default_tax_rate` <= 1)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
;
```

## `currencies`

### Columns

    +-------------+-------------+------+-----+---------+-------+
    | Field       | Type        | Null | Key | Default | Extra |
    +-------------+-------------+------+-----+---------+-------+
    | code        | char(3)     | NO   | PRI | NULL    |       |
    | name        | varchar(60) | NO   |     | NULL    |       |
    | symbol      | varchar(8)  | NO   |     | NULL    |       |
    | minor_units | int         | NO   |     | NULL    |       |
    | is_active   | tinyint(1)  | NO   | MUL | 1       |       |
    +-------------+-------------+------+-----+---------+-------+

### `SHOW CREATE TABLE`

```sql
CREATE TABLE `currencies` (
  `code` char(3) NOT NULL,
  `name` varchar(60) NOT NULL,
  `symbol` varchar(8) NOT NULL,
  `minor_units` int NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`code`),
  KEY `ix_currencies_is_active` (`is_active`),
  CONSTRAINT `ck_currencies_minor_units` CHECK ((`minor_units` in (2,3)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
;
```

## `currency_exchange_rates`

### Columns

    +---------------+---------------+------+-----+---------+-------+
    | Field         | Type          | Null | Key | Default | Extra |
    +---------------+---------------+------+-----+---------+-------+
    | currency_code | char(3)       | NO   | PRI | NULL    |       |
    | rate_to_base  | decimal(19,6) | NO   |     | NULL    |       |
    | updated_at    | datetime(6)   | NO   |     | NULL    |       |
    +---------------+---------------+------+-----+---------+-------+

### `SHOW CREATE TABLE`

```sql
CREATE TABLE `currency_exchange_rates` (
  `currency_code` char(3) NOT NULL,
  `rate_to_base` decimal(19,6) NOT NULL COMMENT 'base-currency units per 1 unit of currency_code',
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`currency_code`),
  CONSTRAINT `fk_currency_exchange_rates_currency` FOREIGN KEY (`currency_code`) REFERENCES `currencies` (`code`),
  CONSTRAINT `ck_currency_exchange_rates_rate` CHECK ((`rate_to_base` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
;
```

## `customers`

### Columns

    +------------+--------------+------+-----+---------+----------------+
    | Field      | Type         | Null | Key | Default | Extra          |
    +------------+--------------+------+-----+---------+----------------+
    | id         | bigint       | NO   | PRI | NULL    | auto_increment |
    | name       | varchar(200) | NO   | MUL | NULL    |                |
    | email      | varchar(255) | YES  |     | NULL    |                |
    | phone      | varchar(40)  | YES  |     | NULL    |                |
    | address    | varchar(500) | YES  |     | NULL    |                |
    | is_active  | tinyint(1)   | NO   | MUL | 1       |                |
    | created_at | datetime(6)  | NO   |     | NULL    |                |
    | updated_at | datetime(6)  | NO   |     | NULL    |                |
    +------------+--------------+------+-----+---------+----------------+

### `SHOW CREATE TABLE`

```sql
CREATE TABLE `customers` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(200) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `phone` varchar(40) DEFAULT NULL,
  `address` varchar(500) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_customers_name` (`name`),
  KEY `ix_customers_is_active` (`is_active`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
;
```

## `invoice_lines`

### Columns

    +--------------------+---------------+------+-----+---------+----------------+
    | Field              | Type          | Null | Key | Default | Extra          |
    +--------------------+---------------+------+-----+---------+----------------+
    | id                 | bigint        | NO   | PRI | NULL    | auto_increment |
    | invoice_id         | bigint        | NO   | MUL | NULL    |                |
    | line_no            | int           | NO   |     | NULL    |                |
    | item_id            | bigint        | NO   | MUL | NULL    |                |
    | item_name_snapshot | varchar(200)  | NO   |     | NULL    |                |
    | barcode_snapshot   | varchar(64)   | YES  | MUL | NULL    |                |
    | quantity           | decimal(12,3) | NO   |     | NULL    |                |
    | unit_price         | decimal(19,4) | NO   |     | NULL    |                |
    | tax_rate           | decimal(5,4)  | NO   |     | NULL    |                |
    | net_amount         | decimal(19,4) | NO   |     | NULL    |                |
    | tax_amount         | decimal(19,4) | NO   |     | NULL    |                |
    | gross_amount       | decimal(19,4) | NO   |     | NULL    |                |
    +--------------------+---------------+------+-----+---------+----------------+

### `SHOW CREATE TABLE`

```sql
CREATE TABLE `invoice_lines` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `invoice_id` bigint NOT NULL,
  `line_no` int NOT NULL,
  `item_id` bigint NOT NULL,
  `item_name_snapshot` varchar(200) NOT NULL,
  `barcode_snapshot` varchar(64) DEFAULT NULL,
  `quantity` decimal(12,3) NOT NULL,
  `unit_price` decimal(19,4) NOT NULL,
  `tax_rate` decimal(5,4) NOT NULL,
  `net_amount` decimal(19,4) NOT NULL,
  `tax_amount` decimal(19,4) NOT NULL,
  `gross_amount` decimal(19,4) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_invoice_lines_invoice_line_no` (`invoice_id`,`line_no`),
  KEY `ix_invoice_lines_invoice_id` (`invoice_id`),
  KEY `ix_invoice_lines_item_id` (`item_id`),
  KEY `ix_invoice_lines_barcode_snapshot` (`barcode_snapshot`),
  CONSTRAINT `fk_invoice_lines_invoice` FOREIGN KEY (`invoice_id`) REFERENCES `invoices` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_invoice_lines_item` FOREIGN KEY (`item_id`) REFERENCES `items` (`id`),
  CONSTRAINT `ck_invoice_lines_amounts` CHECK (((`net_amount` >= 0) and (`tax_amount` >= 0) and (`gross_amount` >= 0))),
  CONSTRAINT `ck_invoice_lines_line_no` CHECK ((`line_no` >= 1)),
  CONSTRAINT `ck_invoice_lines_quantity` CHECK ((`quantity` > 0)),
  CONSTRAINT `ck_invoice_lines_tax_rate` CHECK (((`tax_rate` >= 0) and (`tax_rate` <= 1))),
  CONSTRAINT `ck_invoice_lines_unit_price` CHECK ((`unit_price` >= 0))
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
;
```

## `invoice_sequences`

### Columns

    +------------+-------------+------+-----+---------+-------+
    | Field      | Type        | Null | Key | Default | Extra |
    +------------+-------------+------+-----+---------+-------+
    | prefix     | varchar(10) | NO   | PRI | NULL    |       |
    | year       | int         | NO   | PRI | NULL    |       |
    | next_value | bigint      | NO   |     | 1       |       |
    +------------+-------------+------+-----+---------+-------+

### `SHOW CREATE TABLE`

```sql
CREATE TABLE `invoice_sequences` (
  `prefix` varchar(10) NOT NULL,
  `year` int NOT NULL,
  `next_value` bigint NOT NULL DEFAULT '1',
  PRIMARY KEY (`prefix`,`year`),
  CONSTRAINT `ck_invoice_sequences_next_value` CHECK ((`next_value` >= 1)),
  CONSTRAINT `ck_invoice_sequences_year` CHECK ((`year` between 2000 and 9999))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
;
```

## `invoices`

### Columns

    +---------------------+---------------+------+-----+---------+----------------+
    | Field               | Type          | Null | Key | Default | Extra          |
    +---------------------+---------------+------+-----+---------+----------------+
    | id                  | bigint        | NO   | PRI | NULL    | auto_increment |
    | invoice_number      | varchar(20)   | NO   | UNI | NULL    |                |
    | customer_id         | bigint        | NO   | MUL | NULL    |                |
    | currency_code       | char(3)       | NO   | MUL | NULL    |                |
    | exchange_rate       | decimal(19,6) | NO   |     | NULL    |                |
    | tax_mode            | varchar(10)   | NO   |     | NULL    |                |
    | status              | varchar(10)   | NO   | MUL | NULL    |                |
    | issue_date          | date          | NO   | MUL | NULL    |                |
    | notes               | varchar(1000) | YES  |     | NULL    |                |
    | subtotal            | decimal(19,4) | NO   |     | NULL    |                |
    | tax_total           | decimal(19,4) | NO   |     | NULL    |                |
    | grand_total         | decimal(19,4) | NO   |     | NULL    |                |
    | grand_total_base    | decimal(19,4) | NO   |     | NULL    |                |
    | created_by          | bigint        | NO   | MUL | NULL    |                |
    | approved_by         | bigint        | YES  | MUL | NULL    |                |
    | approved_at         | datetime(6)   | YES  |     | NULL    |                |
    | cancelled_by        | bigint        | YES  | MUL | NULL    |                |
    | cancelled_at        | datetime(6)   | YES  |     | NULL    |                |
    | cancellation_reason | varchar(500)  | YES  |     | NULL    |                |
    | version             | bigint        | NO   |     | 0       |                |
    | created_at          | datetime(6)   | NO   |     | NULL    |                |
    | updated_at          | datetime(6)   | NO   |     | NULL    |                |
    +---------------------+---------------+------+-----+---------+----------------+

### `SHOW CREATE TABLE`

```sql
CREATE TABLE `invoices` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `invoice_number` varchar(20) NOT NULL COMMENT 'INV-YYYY-000001',
  `customer_id` bigint NOT NULL,
  `currency_code` char(3) NOT NULL,
  `exchange_rate` decimal(19,6) NOT NULL COMMENT 'snapshot; base-currency units per 1 invoice-currency unit',
  `tax_mode` varchar(10) NOT NULL,
  `status` varchar(10) NOT NULL,
  `issue_date` date NOT NULL,
  `notes` varchar(1000) DEFAULT NULL,
  `subtotal` decimal(19,4) NOT NULL COMMENT 'sum of rounded line net amounts',
  `tax_total` decimal(19,4) NOT NULL COMMENT 'sum of rounded line tax amounts',
  `grand_total` decimal(19,4) NOT NULL COMMENT 'sum of rounded line gross amounts',
  `grand_total_base` decimal(19,4) NOT NULL COMMENT 'grand_total x exchange_rate, rounded to base currency',
  `created_by` bigint NOT NULL,
  `approved_by` bigint DEFAULT NULL,
  `approved_at` datetime(6) DEFAULT NULL,
  `cancelled_by` bigint DEFAULT NULL,
  `cancelled_at` datetime(6) DEFAULT NULL,
  `cancellation_reason` varchar(500) DEFAULT NULL,
  `version` bigint NOT NULL DEFAULT '0' COMMENT 'optimistic lock',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_invoices_invoice_number` (`invoice_number`),
  KEY `ix_invoices_customer_id` (`customer_id`),
  KEY `ix_invoices_currency_code` (`currency_code`),
  KEY `ix_invoices_status` (`status`),
  KEY `ix_invoices_issue_date` (`issue_date`),
  KEY `ix_invoices_created_by` (`created_by`),
  KEY `ix_invoices_approved_by` (`approved_by`),
  KEY `ix_invoices_cancelled_by` (`cancelled_by`),
  KEY `ix_invoices_status_issue_date` (`status`,`issue_date`),
  CONSTRAINT `fk_invoices_approved_by` FOREIGN KEY (`approved_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_invoices_cancelled_by` FOREIGN KEY (`cancelled_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_invoices_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_invoices_currency` FOREIGN KEY (`currency_code`) REFERENCES `currencies` (`code`),
  CONSTRAINT `fk_invoices_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`),
  CONSTRAINT `ck_invoices_amounts` CHECK (((`subtotal` >= 0) and (`tax_total` >= 0) and (`grand_total` >= 0) and (`grand_total_base` >= 0))),
  CONSTRAINT `ck_invoices_approval_audit` CHECK (((`approved_at` is null) or (`approved_by` is not null))),
  CONSTRAINT `ck_invoices_cancellation_audit` CHECK (((`status` <> _utf8mb4'CANCELLED') or ((`cancelled_by` is not null) and (`cancelled_at` is not null)))),
  CONSTRAINT `ck_invoices_exchange_rate` CHECK ((`exchange_rate` > 0)),
  CONSTRAINT `ck_invoices_status` CHECK ((`status` in (_utf8mb4'DRAFT',_utf8mb4'APPROVED',_utf8mb4'CANCELLED'))),
  CONSTRAINT `ck_invoices_tax_mode` CHECK ((`tax_mode` in (_utf8mb4'EXCLUSIVE',_utf8mb4'INCLUSIVE'))),
  CONSTRAINT `ck_invoices_version` CHECK ((`version` >= 0))
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
;
```

## `items`

### Columns

    +---------------+---------------+------+-----+---------+----------------+
    | Field         | Type          | Null | Key | Default | Extra          |
    +---------------+---------------+------+-----+---------+----------------+
    | id            | bigint        | NO   | PRI | NULL    | auto_increment |
    | sku           | varchar(50)   | NO   | UNI | NULL    |                |
    | barcode       | varchar(64)   | YES  | UNI | NULL    |                |
    | name          | varchar(200)  | NO   | MUL | NULL    |                |
    | unit_price    | decimal(19,4) | NO   |     | NULL    |                |
    | currency_code | char(3)       | NO   | MUL | NULL    |                |
    | tax_rate      | decimal(5,4)  | NO   |     | NULL    |                |
    | is_active     | tinyint(1)    | NO   | MUL | 1       |                |
    | created_at    | datetime(6)   | NO   |     | NULL    |                |
    | updated_at    | datetime(6)   | NO   |     | NULL    |                |
    +---------------+---------------+------+-----+---------+----------------+

### `SHOW CREATE TABLE`

```sql
CREATE TABLE `items` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `sku` varchar(50) NOT NULL,
  `barcode` varchar(64) DEFAULT NULL COMMENT 'EAN-13 for the seeded catalogue',
  `name` varchar(200) NOT NULL,
  `unit_price` decimal(19,4) NOT NULL,
  `currency_code` char(3) NOT NULL,
  `tax_rate` decimal(5,4) NOT NULL COMMENT 'item default, snapshotted onto the invoice line',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_items_sku` (`sku`),
  UNIQUE KEY `uk_items_barcode` (`barcode`),
  KEY `ix_items_name` (`name`),
  KEY `ix_items_currency_code` (`currency_code`),
  KEY `ix_items_is_active` (`is_active`),
  CONSTRAINT `fk_items_currency` FOREIGN KEY (`currency_code`) REFERENCES `currencies` (`code`),
  CONSTRAINT `ck_items_tax_rate` CHECK (((`tax_rate` >= 0) and (`tax_rate` <= 1))),
  CONSTRAINT `ck_items_unit_price` CHECK ((`unit_price` >= 0))
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
;
```

## `refresh_tokens`

### Columns

    +------------+-------------+------+-----+---------+----------------+
    | Field      | Type        | Null | Key | Default | Extra          |
    +------------+-------------+------+-----+---------+----------------+
    | id         | bigint      | NO   | PRI | NULL    | auto_increment |
    | user_id    | bigint      | NO   | MUL | NULL    |                |
    | token_hash | char(64)    | NO   | UNI | NULL    |                |
    | expires_at | datetime(6) | NO   | MUL | NULL    |                |
    | revoked_at | datetime(6) | YES  |     | NULL    |                |
    | created_at | datetime(6) | NO   |     | NULL    |                |
    +------------+-------------+------+-----+---------+----------------+

### `SHOW CREATE TABLE`

```sql
CREATE TABLE `refresh_tokens` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `token_hash` char(64) NOT NULL COMMENT 'SHA-256 of the token, lowercase hex',
  `expires_at` datetime(6) NOT NULL,
  `revoked_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_refresh_tokens_token_hash` (`token_hash`),
  KEY `ix_refresh_tokens_user_id` (`user_id`),
  KEY `ix_refresh_tokens_expires_at` (`expires_at`),
  CONSTRAINT `fk_refresh_tokens_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
;
```

## `users`

### Columns

    +---------------+--------------+------+-----+---------+----------------+
    | Field         | Type         | Null | Key | Default | Extra          |
    +---------------+--------------+------+-----+---------+----------------+
    | id            | bigint       | NO   | PRI | NULL    | auto_increment |
    | username      | varchar(50)  | NO   | UNI | NULL    |                |
    | email         | varchar(255) | NO   | UNI | NULL    |                |
    | password_hash | char(60)     | NO   |     | NULL    |                |
    | full_name     | varchar(150) | NO   |     | NULL    |                |
    | role          | varchar(10)  | NO   | MUL | NULL    |                |
    | is_active     | tinyint(1)   | NO   | MUL | 1       |                |
    | created_at    | datetime(6)  | NO   |     | NULL    |                |
    | updated_at    | datetime(6)  | NO   |     | NULL    |                |
    +---------------+--------------+------+-----+---------+----------------+

### `SHOW CREATE TABLE`

```sql
CREATE TABLE `users` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password_hash` char(60) NOT NULL COMMENT 'BCrypt, strength 12',
  `full_name` varchar(150) NOT NULL,
  `role` varchar(10) NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_users_username` (`username`),
  UNIQUE KEY `uk_users_email` (`email`),
  KEY `ix_users_role` (`role`),
  KEY `ix_users_is_active` (`is_active`),
  CONSTRAINT `ck_users_role` CHECK ((`role` in (_utf8mb4'ADMIN',_utf8mb4'SALES')))
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
;
```

