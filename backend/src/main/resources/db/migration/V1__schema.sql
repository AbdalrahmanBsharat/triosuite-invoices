-- =====================================================================================
-- Triosuite Invoices — schema (Flyway V1)
--
-- MySQL 8, InnoDB, utf8mb4 throughout. Every foreign key and every column used for
-- lookup or filtering carries an index. Enum-like columns, non-negative amounts and
-- positive quantities are enforced by CHECK constraints so the database stays correct
-- even if a row is ever written by something other than this application.
--
-- Money and time conventions (see docs/DECISIONS.md, ADR-0003):
--   amounts        DECIMAL(19,4)
--   exchange rates DECIMAL(19,6)   -- base-currency units per 1 invoice-currency unit
--   tax rates      DECIMAL(5,4)    -- 0.1600 = 16%
--   quantities     DECIMAL(12,3)
--   timestamps     DATETIME(6), always UTC
--
-- This file is mirrored byte-for-byte to database/schema.sql.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- users — application accounts. There is no self-registration; accounts are seeded.
-- -------------------------------------------------------------------------------------
CREATE TABLE users (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    username      VARCHAR(50)  NOT NULL,
    email         VARCHAR(255) NOT NULL,
    password_hash CHAR(60)     NOT NULL COMMENT 'BCrypt, strength 12',
    full_name     VARCHAR(150) NOT NULL,
    role          VARCHAR(10)  NOT NULL,
    is_active     TINYINT(1)   NOT NULL DEFAULT 1,
    created_at    DATETIME(6)  NOT NULL,
    updated_at    DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_username (username),
    UNIQUE KEY uk_users_email (email),
    KEY ix_users_role (role),
    KEY ix_users_is_active (is_active),
    CONSTRAINT ck_users_role CHECK (role IN ('ADMIN', 'SALES'))
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

-- -------------------------------------------------------------------------------------
-- refresh_tokens — opaque, single-use, rotated. Only the SHA-256 hash is ever stored.
-- -------------------------------------------------------------------------------------
CREATE TABLE refresh_tokens (
    id         BIGINT      NOT NULL AUTO_INCREMENT,
    user_id    BIGINT      NOT NULL,
    token_hash CHAR(64)    NOT NULL COMMENT 'SHA-256 of the token, lowercase hex',
    expires_at DATETIME(6) NOT NULL,
    revoked_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_refresh_tokens_token_hash (token_hash),
    KEY ix_refresh_tokens_user_id (user_id),
    KEY ix_refresh_tokens_expires_at (expires_at),
    CONSTRAINT fk_refresh_tokens_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

-- -------------------------------------------------------------------------------------
-- currencies — ISO 4217. minor_units drives every rounding decision.
-- -------------------------------------------------------------------------------------
CREATE TABLE currencies (
    code        CHAR(3)     NOT NULL,
    name        VARCHAR(60) NOT NULL,
    symbol      VARCHAR(8)  NOT NULL,
    minor_units INT         NOT NULL,
    is_active   TINYINT(1)  NOT NULL DEFAULT 1,
    PRIMARY KEY (code),
    KEY ix_currencies_is_active (is_active),
    CONSTRAINT ck_currencies_minor_units CHECK (minor_units IN (2, 3))
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

-- -------------------------------------------------------------------------------------
-- currency_exchange_rates — the rate suggested on the Create Invoice screen.
-- The rate actually used is snapshotted onto the invoice and never read back from here.
-- -------------------------------------------------------------------------------------
CREATE TABLE currency_exchange_rates (
    currency_code CHAR(3)        NOT NULL,
    rate_to_base  DECIMAL(19, 6) NOT NULL COMMENT 'base-currency units per 1 unit of currency_code',
    updated_at    DATETIME(6)    NOT NULL,
    PRIMARY KEY (currency_code),
    CONSTRAINT fk_currency_exchange_rates_currency FOREIGN KEY (currency_code) REFERENCES currencies (code),
    CONSTRAINT ck_currency_exchange_rates_rate CHECK (rate_to_base > 0)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

-- -------------------------------------------------------------------------------------
-- customers
-- -------------------------------------------------------------------------------------
CREATE TABLE customers (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    name       VARCHAR(200) NOT NULL,
    email      VARCHAR(255) NULL,
    phone      VARCHAR(40)  NULL,
    address    VARCHAR(500) NULL,
    is_active  TINYINT(1)   NOT NULL DEFAULT 1,
    created_at DATETIME(6)  NOT NULL,
    updated_at DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    KEY ix_customers_name (name),
    KEY ix_customers_is_active (is_active)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

-- -------------------------------------------------------------------------------------
-- items — barcode is unique and nullable; it is what the scanner looks up.
-- -------------------------------------------------------------------------------------
CREATE TABLE items (
    id            BIGINT         NOT NULL AUTO_INCREMENT,
    sku           VARCHAR(50)    NOT NULL,
    barcode       VARCHAR(64)    NULL COMMENT 'EAN-13 for the seeded catalogue',
    name          VARCHAR(200)   NOT NULL,
    unit_price    DECIMAL(19, 4) NOT NULL,
    currency_code CHAR(3)        NOT NULL,
    tax_rate      DECIMAL(5, 4)  NOT NULL COMMENT 'item default, snapshotted onto the invoice line',
    is_active     TINYINT(1)     NOT NULL DEFAULT 1,
    created_at    DATETIME(6)    NOT NULL,
    updated_at    DATETIME(6)    NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_items_sku (sku),
    UNIQUE KEY uk_items_barcode (barcode),
    KEY ix_items_name (name),
    KEY ix_items_currency_code (currency_code),
    KEY ix_items_is_active (is_active),
    CONSTRAINT fk_items_currency FOREIGN KEY (currency_code) REFERENCES currencies (code),
    CONSTRAINT ck_items_unit_price CHECK (unit_price >= 0),
    CONSTRAINT ck_items_tax_rate CHECK (tax_rate >= 0 AND tax_rate <= 1)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

-- -------------------------------------------------------------------------------------
-- app_settings — exactly one row, pinned by the CHECK on the primary key.
-- -------------------------------------------------------------------------------------
CREATE TABLE app_settings (
    id                    TINYINT       NOT NULL,
    base_currency_code    CHAR(3)       NOT NULL COMMENT 'reporting currency',
    default_currency_code CHAR(3)       NOT NULL,
    default_tax_mode      VARCHAR(10)   NOT NULL,
    default_tax_rate      DECIMAL(5, 4) NOT NULL,
    invoice_number_prefix VARCHAR(10)   NOT NULL,
    updated_at            DATETIME(6)   NOT NULL,
    PRIMARY KEY (id),
    KEY ix_app_settings_base_currency_code (base_currency_code),
    KEY ix_app_settings_default_currency_code (default_currency_code),
    CONSTRAINT fk_app_settings_base_currency FOREIGN KEY (base_currency_code) REFERENCES currencies (code),
    CONSTRAINT fk_app_settings_default_currency FOREIGN KEY (default_currency_code) REFERENCES currencies (code),
    CONSTRAINT ck_app_settings_singleton CHECK (id = 1),
    CONSTRAINT ck_app_settings_tax_mode CHECK (default_tax_mode IN ('EXCLUSIVE', 'INCLUSIVE')),
    CONSTRAINT ck_app_settings_tax_rate CHECK (default_tax_rate >= 0 AND default_tax_rate <= 1),
    CONSTRAINT ck_app_settings_prefix CHECK (CHAR_LENGTH(invoice_number_prefix) >= 1)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

-- -------------------------------------------------------------------------------------
-- invoice_sequences — one row per (prefix, year). Locked with SELECT ... FOR UPDATE
-- during invoice creation so concurrent requests cannot allocate the same number.
-- -------------------------------------------------------------------------------------
CREATE TABLE invoice_sequences (
    prefix     VARCHAR(10) NOT NULL,
    year       INT         NOT NULL,
    next_value BIGINT      NOT NULL DEFAULT 1,
    PRIMARY KEY (prefix, year),
    CONSTRAINT ck_invoice_sequences_next_value CHECK (next_value >= 1),
    CONSTRAINT ck_invoice_sequences_year CHECK (year BETWEEN 2000 AND 9999)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

-- -------------------------------------------------------------------------------------
-- invoices — the aggregate root. Records are never deleted; cancellation is a status.
-- exchange_rate and every total are snapshots computed by the server.
-- -------------------------------------------------------------------------------------
CREATE TABLE invoices (
    id                  BIGINT         NOT NULL AUTO_INCREMENT,
    invoice_number      VARCHAR(20)    NOT NULL COMMENT 'INV-YYYY-000001',
    customer_id         BIGINT         NOT NULL,
    currency_code       CHAR(3)        NOT NULL,
    exchange_rate       DECIMAL(19, 6) NOT NULL COMMENT 'snapshot; base-currency units per 1 invoice-currency unit',
    tax_mode            VARCHAR(10)    NOT NULL,
    status              VARCHAR(10)    NOT NULL,
    issue_date          DATE           NOT NULL,
    notes               VARCHAR(1000)  NULL,
    subtotal            DECIMAL(19, 4) NOT NULL COMMENT 'sum of rounded line net amounts',
    tax_total           DECIMAL(19, 4) NOT NULL COMMENT 'sum of rounded line tax amounts',
    grand_total         DECIMAL(19, 4) NOT NULL COMMENT 'sum of rounded line gross amounts',
    grand_total_base    DECIMAL(19, 4) NOT NULL COMMENT 'grand_total x exchange_rate, rounded to base currency',
    created_by          BIGINT         NOT NULL,
    approved_by         BIGINT         NULL,
    approved_at         DATETIME(6)    NULL,
    cancelled_by        BIGINT         NULL,
    cancelled_at        DATETIME(6)    NULL,
    cancellation_reason VARCHAR(500)   NULL,
    version             BIGINT         NOT NULL DEFAULT 0 COMMENT 'optimistic lock',
    created_at          DATETIME(6)    NOT NULL,
    updated_at          DATETIME(6)    NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_invoices_invoice_number (invoice_number),
    KEY ix_invoices_customer_id (customer_id),
    KEY ix_invoices_currency_code (currency_code),
    KEY ix_invoices_status (status),
    KEY ix_invoices_issue_date (issue_date),
    KEY ix_invoices_created_by (created_by),
    KEY ix_invoices_approved_by (approved_by),
    KEY ix_invoices_cancelled_by (cancelled_by),
    KEY ix_invoices_status_issue_date (status, issue_date),
    CONSTRAINT fk_invoices_customer FOREIGN KEY (customer_id) REFERENCES customers (id),
    CONSTRAINT fk_invoices_currency FOREIGN KEY (currency_code) REFERENCES currencies (code),
    CONSTRAINT fk_invoices_created_by FOREIGN KEY (created_by) REFERENCES users (id),
    CONSTRAINT fk_invoices_approved_by FOREIGN KEY (approved_by) REFERENCES users (id),
    CONSTRAINT fk_invoices_cancelled_by FOREIGN KEY (cancelled_by) REFERENCES users (id),
    CONSTRAINT ck_invoices_status CHECK (status IN ('DRAFT', 'APPROVED', 'CANCELLED')),
    CONSTRAINT ck_invoices_tax_mode CHECK (tax_mode IN ('EXCLUSIVE', 'INCLUSIVE')),
    CONSTRAINT ck_invoices_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_invoices_amounts CHECK (subtotal >= 0 AND tax_total >= 0 AND grand_total >= 0 AND grand_total_base >= 0),
    CONSTRAINT ck_invoices_version CHECK (version >= 0),
    CONSTRAINT ck_invoices_approval_audit CHECK (approved_at IS NULL OR approved_by IS NOT NULL),
    CONSTRAINT ck_invoices_cancellation_audit CHECK (status <> 'CANCELLED' OR (cancelled_by IS NOT NULL AND cancelled_at IS NOT NULL))
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

-- -------------------------------------------------------------------------------------
-- invoice_lines — immutable children, replaced wholesale when a DRAFT is updated.
-- item_name_snapshot / barcode_snapshot / unit_price / tax_rate are deliberate copies so
-- an approved invoice cannot change when the catalogue does (ADR-0004).
-- -------------------------------------------------------------------------------------
CREATE TABLE invoice_lines (
    id                 BIGINT         NOT NULL AUTO_INCREMENT,
    invoice_id         BIGINT         NOT NULL,
    line_no            INT            NOT NULL,
    item_id            BIGINT         NOT NULL,
    item_name_snapshot VARCHAR(200)   NOT NULL,
    barcode_snapshot   VARCHAR(64)    NULL,
    quantity           DECIMAL(12, 3) NOT NULL,
    unit_price         DECIMAL(19, 4) NOT NULL,
    tax_rate           DECIMAL(5, 4)  NOT NULL,
    net_amount         DECIMAL(19, 4) NOT NULL,
    tax_amount         DECIMAL(19, 4) NOT NULL,
    gross_amount       DECIMAL(19, 4) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_invoice_lines_invoice_line_no (invoice_id, line_no),
    KEY ix_invoice_lines_invoice_id (invoice_id),
    KEY ix_invoice_lines_item_id (item_id),
    KEY ix_invoice_lines_barcode_snapshot (barcode_snapshot),
    CONSTRAINT fk_invoice_lines_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE,
    CONSTRAINT fk_invoice_lines_item FOREIGN KEY (item_id) REFERENCES items (id),
    CONSTRAINT ck_invoice_lines_line_no CHECK (line_no >= 1),
    CONSTRAINT ck_invoice_lines_quantity CHECK (quantity > 0),
    CONSTRAINT ck_invoice_lines_unit_price CHECK (unit_price >= 0),
    CONSTRAINT ck_invoice_lines_tax_rate CHECK (tax_rate >= 0 AND tax_rate <= 1),
    CONSTRAINT ck_invoice_lines_amounts CHECK (net_amount >= 0 AND tax_amount >= 0 AND gross_amount >= 0)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;
