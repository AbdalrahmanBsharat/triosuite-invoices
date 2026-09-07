-- =====================================================================================
-- Triosuite Invoices — demo data (Flyway V2)
--
-- Everything a reviewer needs to exercise the app without creating anything first:
-- two accounts, five currencies with rates, six customers, a fifteen-item catalogue with
-- valid EAN-13 barcodes, and six invoices covering all three statuses, five currencies
-- and both tax modes.
--
-- Every stored total in this file was produced by the production InvoiceCalculator, and
-- SeededInvoiceTotalsIT re-derives all of them on each build, so the seed can never
-- drift from the engine.
--
-- This file is mirrored byte-for-byte to database/seed.sql.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- Accounts. Passwords are BCrypt, strength 12:
--   admin / Admin#2026   (ADMIN)
--   sales / Sales#2026   (SALES)
-- Change both before exposing this deployment to anyone (see docs/DEPLOYMENT.md).
-- -------------------------------------------------------------------------------------
INSERT INTO users (id, username, email, password_hash, full_name, role, is_active, created_at, updated_at)
VALUES
    (1, 'admin', 'admin@triosuite.local',
     '$2a$12$N2KroBw/mv.sTG/4BQd7fua7ZeBypfDnxaisOIpwFVulKk33O0PgK',
     'System Administrator', 'ADMIN', 1, '2026-01-05 07:30:00.000000', '2026-01-05 07:30:00.000000'),
    (2, 'sales', 'sales@triosuite.local',
     '$2a$12$GqHsGxruMIzgzk9ZKIy4lu64I6eQTNwGml4JfxieEJPviwEnHQUwC',
     'Sales Representative', 'SALES', 1, '2026-01-05 07:31:00.000000', '2026-01-05 07:31:00.000000');

-- -------------------------------------------------------------------------------------
-- Currencies. JOD is the base (reporting) currency, and it carries three minor units — so the
-- three-decimal rounding path is the default one rather than an edge case only one invoice hits.
-- -------------------------------------------------------------------------------------
INSERT INTO currencies (code, name, symbol, minor_units, is_active)
VALUES
    ('ILS', 'Israeli New Shekel', '₪',  2, 1),
    ('USD', 'US Dollar',          '$',  2, 1),
    ('EUR', 'Euro',               '€',  2, 1),
    ('JOD', 'Jordanian Dinar',    'JD', 3, 1),
    ('GBP', 'Pound Sterling',     '£',  2, 1);

-- Rates are "base-currency units per one unit of this currency", so JOD is exactly 1.
INSERT INTO currency_exchange_rates (currency_code, rate_to_base, updated_at)
VALUES
    ('ILS', 0.194175, '2026-01-05 08:00:00.000000'),
    ('USD', 0.708738, '2026-01-05 08:00:00.000000'),
    ('EUR', 0.765049, '2026-01-05 08:00:00.000000'),
    ('JOD', 1.000000, '2026-01-05 08:00:00.000000'),
    ('GBP', 0.897087, '2026-01-05 08:00:00.000000');

-- -------------------------------------------------------------------------------------
-- Settings. Exactly one row, pinned by ck_app_settings_singleton.
-- -------------------------------------------------------------------------------------
INSERT INTO app_settings (id, base_currency_code, default_currency_code, default_tax_mode,
                          default_tax_rate, invoice_number_prefix, updated_at)
VALUES
    (1, 'JOD', 'JOD', 'EXCLUSIVE', 0.1600, 'INV', '2026-01-05 08:00:00.000000');

-- -------------------------------------------------------------------------------------
-- Customers. Sahara Logistics is inactive, which exercises the "customer must be active"
-- validation on invoice creation.
-- -------------------------------------------------------------------------------------
INSERT INTO customers (id, name, email, phone, address, is_active, created_at, updated_at)
VALUES
    (1, 'Al-Quds Trading Co.', 'billing@alquds-trading.example', '+970 2 295 1100',
     'Al-Irsal Street 14, Ramallah', 1, '2026-01-06 09:00:00.000000', '2026-01-06 09:00:00.000000'),
    (2, 'Bethlehem Electronics', 'accounts@bethlehem-electronics.example', '+970 2 274 3320',
     'Manger Street 88, Bethlehem', 1, '2026-01-06 09:05:00.000000', '2026-01-06 09:05:00.000000'),
    (3, 'Levant Office Supplies', 'finance@levant-office.example', '+962 6 553 8890',
     'Mecca Street 210, Amman', 1, '2026-01-06 09:10:00.000000', '2026-01-06 09:10:00.000000'),
    (4, 'Mediterranean Retail Group', 'ap@medretail.example', '+357 22 456 700',
     'Makarios Avenue 31, Nicosia', 1, '2026-01-06 09:15:00.000000', '2026-01-06 09:15:00.000000'),
    (5, 'Northgate Systems Ltd', 'purchasing@northgate-systems.example', '+44 161 496 0111',
     'Deansgate 402, Manchester', 1, '2026-01-06 09:20:00.000000', '2026-01-06 09:20:00.000000'),
    (6, 'Sahara Logistics', 'hello@sahara-logistics.example', '+1 415 555 0142',
     'Market Street 900, San Francisco', 0, '2026-01-06 09:25:00.000000', '2026-01-06 09:25:00.000000');

-- -------------------------------------------------------------------------------------
-- Catalogue. Every barcode is a valid EAN-13 (prefix 729, correct modulo-10 check digit);
-- printable PNGs of all fifteen are in docs/barcodes/. Items 13-15 are zero-rated.
-- -------------------------------------------------------------------------------------
INSERT INTO items (id, sku, barcode, name, unit_price, currency_code, tax_rate, is_active, created_at, updated_at)
VALUES
    (1,  'LAP-1401', '7290001000014', 'Business Laptop 14"',         834.7570, 'JOD', 0.1600, 1, '2026-01-07 10:00:00.000000', '2026-01-07 10:00:00.000000'),
    (2,  'MSE-2201', '7290001000021', 'Wireless Mouse',               17.4560, 'JOD', 0.1600, 1, '2026-01-07 10:01:00.000000', '2026-01-07 10:01:00.000000'),
    (3,  'KBD-3310', '7290001000038', 'Mechanical Keyboard',          67.7670, 'JOD', 0.1600, 1, '2026-01-07 10:02:00.000000', '2026-01-07 10:02:00.000000'),
    (4,  'MON-2704', '7290001000045', '27" 4K Monitor',              368.7380, 'JOD', 0.1600, 1, '2026-01-07 10:03:00.000000', '2026-01-07 10:03:00.000000'),
    (5,  'DCK-1102', '7290001000052', 'USB-C Docking Station',       145.5340, 'JOD', 0.1600, 1, '2026-01-07 10:04:00.000000', '2026-01-07 10:04:00.000000'),
    (6,  'PRN-4400', '7290001000069', 'Laser Printer A4',            242.5240, 'JOD', 0.1600, 1, '2026-01-07 10:05:00.000000', '2026-01-07 10:05:00.000000'),
    (7,  'TNR-4401', '7290001000076', 'Toner Cartridge Black',        56.1170, 'JOD', 0.1600, 1, '2026-01-07 10:06:00.000000', '2026-01-07 10:06:00.000000'),
    (8,  'PPR-0500', '7290001000083', 'A4 Copy Paper (500 sheets)',    4.3690, 'JOD', 0.1600, 1, '2026-01-07 10:07:00.000000', '2026-01-07 10:07:00.000000'),
    (9,  'CHR-7700', '7290001000090', 'Ergonomic Office Chair',      223.3010, 'JOD', 0.1600, 1, '2026-01-07 10:08:00.000000', '2026-01-07 10:08:00.000000'),
    (10, 'DSK-1400', '7290001000106', 'Standing Desk 140 cm',        475.7280, 'JOD', 0.1600, 1, '2026-01-07 10:09:00.000000', '2026-01-07 10:09:00.000000'),
    (11, 'NET-2400', '7290001000113', 'Network Switch 24-Port',      326.2140, 'JOD', 0.1600, 1, '2026-01-07 10:10:00.000000', '2026-01-07 10:10:00.000000'),
    (12, 'CBL-0603', '7290001000120', 'Cat6 Patch Cable 3 m',          3.4950, 'JOD', 0.1600, 1, '2026-01-07 10:11:00.000000', '2026-01-07 10:11:00.000000'),
    (13, 'LIC-0001', '7290001000137', 'Annual Software Licence',     349.5150, 'JOD', 0.0000, 1, '2026-01-07 10:12:00.000000', '2026-01-07 10:12:00.000000'),
    (14, 'SVC-0010', '7290001000144', 'On-site Support Hour',         42.7180, 'JOD', 0.0000, 1, '2026-01-07 10:13:00.000000', '2026-01-07 10:13:00.000000'),
    (15, 'WRT-0024', '7290001000151', 'Extended Warranty 24 m',      124.2720, 'JOD', 0.0000, 1, '2026-01-07 10:14:00.000000', '2026-01-07 10:14:00.000000');

-- -------------------------------------------------------------------------------------
-- Sample invoices.
--
--   1  ILS  EXCLUSIVE  APPROVED    foreign currency, tax added on top
--   2  USD  INCLUSIVE  APPROVED    foreign currency, tax extracted from the price
--   3  JOD  EXCLUSIVE  DRAFT       the base currency, rate locked at 1
--   4  EUR  INCLUSIVE  CANCELLED   cancelled after approval, with a reason
--   5  GBP  EXCLUSIVE  DRAFT       zero-rated lines only
--   6  ILS  INCLUSIVE  CANCELLED   cancelled while still a draft
--
-- Unit prices on foreign-currency invoices are the JOD catalogue price converted at the
-- invoice's own exchange rate and rounded to that currency's minor units, which is what
-- the mobile app does when an item is added (ADR-0011).
-- -------------------------------------------------------------------------------------
INSERT INTO invoices (id, invoice_number, customer_id, currency_code, exchange_rate, tax_mode, status,
                      issue_date, notes, subtotal, tax_total, grand_total, grand_total_base,
                      created_by, approved_by, approved_at, cancelled_by, cancelled_at,
                      cancellation_reason, version, created_at, updated_at)
VALUES
    (1, 'INV-2026-000001', 1, 'ILS', 0.194175, 'EXCLUSIVE', 'APPROVED', '2026-02-11', 'Q1 office refresh, delivered to the Ramallah branch.',
     9002.8000, 1440.4500, 10443.2500, 2027.8180,
     1, 1, '2026-02-12 09:14:22.000000', NULL, NULL, NULL, 0, '2026-02-11 08:00:00.000000', '2026-02-12 09:14:22.000000'),
    (2, 'INV-2026-000002', 2, 'USD', 0.708738, 'INCLUSIVE', 'APPROVED', '2026-03-19', 'Prices quoted tax inclusive at the customer''s request.',
     1876.5800, 300.2500, 2176.8300, 1542.8020,
     2, 1, '2026-03-20 11:02:47.000000', NULL, NULL, NULL, 0, '2026-03-19 08:00:00.000000', '2026-03-20 11:02:47.000000'),
    (3, 'INV-2026-000003', 3, 'JOD', 1.000000, 'EXCLUSIVE', 'DRAFT', '2026-05-04', 'Awaiting confirmation of the delivery window.',
     2291.2620, 366.6020, 2657.8640, 2657.8640,
     2, NULL, NULL, NULL, NULL, NULL, 0, '2026-05-04 08:00:00.000000', '2026-05-04 08:00:00.000000'),
    (4, 'INV-2026-000004', 4, 'EUR', 0.765049, 'INCLUSIVE', 'CANCELLED', '2026-06-22', 'Network refresh for the Nicosia distribution centre.',
     833.6600, 133.3900, 967.0500, 739.8410,
     1, 1, '2026-06-23 08:40:10.000000', 1, '2026-07-01 14:26:55.000000', 'Customer postponed the rollout to the next financial year.', 0, '2026-06-22 08:00:00.000000', '2026-07-01 14:26:55.000000'),
    (5, 'INV-2026-000005', 5, 'GBP', 0.897087, 'EXCLUSIVE', 'DRAFT', '2026-08-01', 'Zero-rated services only.',
     2519.4900, 0.0000, 2519.4900, 2260.2020,
     2, NULL, NULL, NULL, NULL, NULL, 0, '2026-08-01 08:00:00.000000', '2026-08-01 08:00:00.000000'),
    (6, 'INV-2026-000006', 1, 'ILS', 0.194175, 'INCLUSIVE', 'CANCELLED', '2026-08-28', 'Replaced by a revised quotation.',
     2713.2700, 331.7300, 3045.0000, 591.2630,
     2, NULL, NULL, 1, '2026-08-29 10:05:31.000000', 'Superseded before approval; a corrected invoice will be issued.', 0, '2026-08-28 08:00:00.000000', '2026-08-29 10:05:31.000000');

INSERT INTO invoice_lines (invoice_id, line_no, item_id, item_name_snapshot, barcode_snapshot,
                           quantity, unit_price, tax_rate, net_amount, tax_amount, gross_amount)
VALUES
    (1, 1, 1,  'Business Laptop 14"',        '7290001000014',  2.000, 4299.0000, 0.1600, 8598.0000, 1375.6800, 9973.6800),
    (1, 2, 2,  'Wireless Mouse',             '7290001000021',  2.000,   89.9000, 0.1600,  179.8000,   28.7700,  208.5700),
    (1, 3, 8,  'A4 Copy Paper (500 sheets)', '7290001000083', 10.000,   22.5000, 0.1600,  225.0000,   36.0000,  261.0000),
    (2, 1, 4,  '27" 4K Monitor',             '7290001000045',  3.000,  520.2700, 0.1600, 1345.5300,  215.2800, 1560.8100),
    (2, 2, 5,  'USB-C Docking Station',      '7290001000052',  3.000,  205.3400, 0.1600,  531.0500,   84.9700,  616.0200),
    (3, 1, 9,  'Ergonomic Office Chair',     '7290001000090',  6.000,  223.3010, 0.1600, 1339.8060,  214.3690, 1554.1750),
    (3, 2, 10, 'Standing Desk 140 cm',       '7290001000106',  2.000,  475.7280, 0.1600,  951.4560,  152.2330, 1103.6890),
    (4, 1, 11, 'Network Switch 24-Port',     '7290001000113',  2.000,  426.4000, 0.1600,  735.1700,  117.6300,  852.8000),
    (4, 2, 12, 'Cat6 Patch Cable 3 m',       '7290001000120', 25.000,    4.5700, 0.1600,   98.4900,   15.7600,  114.2500),
    (5, 1, 13, 'Annual Software Licence',    '7290001000137',  5.000,  389.6100, 0.0000, 1948.0500,    0.0000, 1948.0500),
    (5, 2, 14, 'On-site Support Hour',       '7290001000144', 12.000,   47.6200, 0.0000,  571.4400,    0.0000,  571.4400),
    (6, 1, 6,  'Laser Printer A4',           '7290001000069',  1.000, 1249.0000, 0.1600, 1076.7200,  172.2800, 1249.0000),
    (6, 2, 7,  'Toner Cartridge Black',      '7290001000076',  4.000,  289.0000, 0.1600,  996.5500,  159.4500, 1156.0000),
    (6, 3, 15, 'Extended Warranty 24 m',     '7290001000151',  1.000,  640.0000, 0.0000,  640.0000,    0.0000,  640.0000);

-- -------------------------------------------------------------------------------------
-- Numbering. Six invoices have been issued for 2026, so the next one is INV-2026-000007.
-- -------------------------------------------------------------------------------------
INSERT INTO invoice_sequences (prefix, year, next_value)
VALUES ('INV', 2026, 7);
