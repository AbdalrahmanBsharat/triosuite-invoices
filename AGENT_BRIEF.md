# AGENT BRIEF — Triosuite Technical Assessment

**ERP Sales Invoices: Flutter app + Spring Boot REST API + MySQL**

You are acting as a senior full-stack engineer (backend lead) delivering a hiring assessment that will
be reviewed by senior engineers. Build the entire solution described below, end to end, in this
repository. Treat it as production-grade code that happens to be small.

---

## How you must work (read this first)

1. **Autonomy.** Do not ask questions. Make sensible senior-level decisions, record each non-obvious
   one in `docs/DECISIONS.md` (one short ADR-style entry each), and keep going. The only reason to
   stop is a hard blocker that cannot be resolved unaided (e.g. a tool that needs credentials or a
   manual install). If that happens, say exactly what is needed, in one message, and continue with
   everything that is not blocked.
2. **Setup first, then implementation.** Follow the phases in section 8 in order. Each phase has exit
   criteria; do not move on until they pass.
3. **Verify, do not assume.** Run the real commands (`./mvnw verify`, `flutter analyze`, `flutter test`,
   `flutter build apk`, `curl` against the running API). Never report something as working unless it
   was actually run.
4. **Resumability.** Save this brief as `AGENT_BRIEF.md` in the repo root. Keep `docs/PROGRESS.md` as a
   checkbox list of every task in this brief and update it as work completes. If context resets or a
   session ends, re-read `AGENT_BRIEF.md` and `docs/PROGRESS.md` and continue from where you left off.
5. **Quality bar.** No TODOs, no placeholders, no commented-out code, no "for simplicity" shortcuts that
   would be insecure or incorrect, no dead code. Small, focused commits with conventional commit
   messages (`feat:`, `fix:`, `docs:`, `test:`, `chore:`).
6. **Language.** English for all code, comments, docs and commit messages.
7. **Scope discipline.** Implement everything required here, and nothing that is not listed (no
   discounts, no PDF export, no multi-tenancy, no push notifications). Depth and correctness over
   breadth.

---

## 1. The assessment (verbatim from Triosuite)

> **ERP Mobile Application Assessment**
>
> Develop a small, ERP-oriented mobile application using Flutter. The app should not exceed five
> screens and must cover creating and managing sales invoices end to end.
>
> **1. Required Screens:** Login · Invoice List · Create Sales Invoice · Invoice Details · Settings
>
> **2. System Capabilities**
> - **Multi-Currency** — support multiple currencies with user-supplied exchange rates.
> - **Tax Modes** — support Tax Inclusive and Tax Exclusive calculations.
> - **Automatic Numbering** — invoice numbers generated automatically.
> - **Approval** — approved invoices become non-editable.
> - **Cancellation** — cancel an invoice without deleting the record.
> - **Barcode Scanning** — scan a barcode to auto-add the item using a Flutter package.
>
> **3. Deliverables (GitHub repository including):** repository link · README explaining how to run the
> project · SQL scripts used to create the database · screenshots of the database tables · source code
> for the REST APIs · APK file of the application · clear location of the SQL scripts within the
> project.

---

## 2. Repository layout (fixed)

```
/
├── README.md                  # overview, reviewer quick start, links to everything
├── AGENT_BRIEF.md             # this file
├── backend/                   # Spring Boot REST API (Maven wrapper, Dockerfile)
├── mobile/                    # Flutter app
├── database/
│   ├── README.md              # what each script is and how to run it
│   ├── schema.sql             # full DDL — identical to Flyway V1
│   ├── seed.sql               # demo data — identical to Flyway V2
│   ├── schema_description.md  # SHOW CREATE TABLE / DESCRIBE output for every table
│   └── screenshots/           # DB table screenshots (see Phase 6)
├── docs/
│   ├── DECISIONS.md           # ADR-style decisions
│   ├── PROGRESS.md            # checklist, updated continuously
│   ├── ERD.md                 # Mermaid ER diagram
│   ├── API.md                 # endpoint summary + link to Swagger UI
│   ├── SMOKE_TEST.md          # recorded end-to-end run (Phase 5)
│   ├── DEPLOYMENT.md          # free hosting guide (section 9)
│   ├── openapi.json           # exported OpenAPI spec
│   └── barcodes/              # printable PNG barcodes for the seeded items
├── release/
│   └── app-release.apk
├── docker-compose.yml         # local MySQL 8 + backend
└── .github/workflows/ci.yml
```

---

## 3. Tech stack (fixed — do not substitute)

### Backend
- Java 21 (LTS). Latest stable GA Spring Boot (verify what is current; do not use
  milestones/snapshots). Maven wrapper (`./mvnw`).
- Starters: `web`, `data-jpa`, `security`, `validation`, `actuator`.
- Flyway (with the MySQL module). `mysql-connector-j`. `springdoc-openapi` (Swagger UI).
- JWT via `jjwt` (or Nimbus through `spring-security-oauth2-jose`). Lombok allowed; MapStruct optional.
- Tests: JUnit 5, AssertJ, Spring Boot Test + MockMvc. Integration tests run against MySQL 8 via
  Testcontainers. **If Docker is not available on this machine, point a test profile at the local MySQL
  instead — never fall back to H2, the DDL is MySQL-specific.** The calculation engine tests must be
  pure unit tests with no Spring context.
- Multi-stage Dockerfile (`eclipse-temurin:21-jre` base, non-root user).

### Mobile
- Flutter stable (latest), Dart 3.
- Packages: `get` (GetX state), `dio` (HTTP + interceptors), `flutter_secure_storage` (tokens),
  `mobile_scanner` (barcode), `intl` (formatting), `freezed` + `json_serializable` (models), `decimal`
  (client-side money math), `package_info_plus` (version), `pretty_dio_logger`. Nothing else unless
  strictly needed; justify additions in `DECISIONS.md`.
- Feature-first structure: `lib/core/` (network, auth, storage, theme, errors, routing) and
  `lib/features/<auth|invoices|settings>/{data,domain,presentation}/`.

### Money and time (apply everywhere)
- Backend: `BigDecimal` for every amount, rate and quantity.
- DB: `DECIMAL(19,4)` for amounts, `DECIMAL(19,6)` for exchange rates, `DECIMAL(5,4)` for tax rates
  (`0.1600` = 16%), `DECIMAL(12,3)` for quantities. Never `double`/`float` for money, on either side.
- Rounding: per line, `HALF_UP`, to the invoice currency's minor units (2 for ILS/USD/EUR/GBP, 3 for
  JOD). Invoice totals are the sum of the already-rounded lines. Document this in `docs/DECISIONS.md`.
- All timestamps stored and transmitted in UTC (`DATETIME(6)`, ISO-8601 with `Z` in JSON). The app
  formats to the device locale/time zone.

---

## 4. Domain model

### Tables
MySQL 8, InnoDB, utf8mb4; FK + index on every foreign key and every lookup column;
`created_at`/`updated_at` on mutable tables.

| Table | Columns (essentials) |
|---|---|
| `users` | id, username (unique), email (unique), password_hash (BCrypt), full_name, role (ADMIN \| SALES), is_active, timestamps |
| `refresh_tokens` | id, user_id (FK), token_hash (SHA-256, unique), expires_at, revoked_at, created_at |
| `currencies` | code (PK, ISO 4217), name, symbol, minor_units (2 or 3), is_active |
| `currency_exchange_rates` | currency_code (PK/FK), rate_to_base DECIMAL(19,6), updated_at — default rate suggested on the Create screen |
| `customers` | id, name, email, phone, address, is_active, timestamps |
| `items` | id, sku (unique), barcode (unique, nullable), name, unit_price, currency_code (FK), tax_rate (item default), is_active, timestamps |
| `app_settings` | single row: base_currency_code (FK), default_currency_code (FK), default_tax_mode (EXCLUSIVE \| INCLUSIVE), default_tax_rate, invoice_number_prefix (INV), updated_at |
| `invoice_sequences` | prefix, year, next_value — composite PK (prefix, year) — locked row for number allocation |
| `invoices` | id, invoice_number (unique), customer_id (FK), currency_code (FK), exchange_rate (user-supplied snapshot), tax_mode, status (DRAFT \| APPROVED \| CANCELLED), issue_date, notes, subtotal, tax_total, grand_total, grand_total_base, created_by (FK users), approved_by, approved_at, cancelled_by, cancelled_at, cancellation_reason, version (optimistic lock), timestamps |
| `invoice_lines` | id, invoice_id (FK, ON DELETE CASCADE), line_no, item_id (FK), item_name_snapshot, barcode_snapshot, quantity, unit_price, tax_rate (snapshot), net_amount, tax_amount, gross_amount |

Snapshots are deliberate: an approved invoice must not change if an item's price or name changes later.
Use CHECK constraints for enums, non-negative amounts and positive quantities.

### Invoice state machine (enforced server-side; the single source of truth)

```
DRAFT ──approve──▶ APPROVED ──cancel──▶ CANCELLED
  │                                         ▲
  └──────────────────cancel──────────────────┘
```

- Header/lines editable in `DRAFT` only. Any write to an `APPROVED` or `CANCELLED` invoice →
  `409 Conflict`, code `INVOICE_NOT_EDITABLE`.
- Approve: `DRAFT → APPROVED`; requires at least one line; sets `approved_by`/`approved_at`. Approving
  anything not in `DRAFT` → `409`, code `INVALID_TRANSITION`.
- Cancel: `DRAFT | APPROVED → CANCELLED`; optional reason; sets `cancelled_by`/`cancelled_at`.
  Cancelling a cancelled invoice → `409`, code `INVALID_TRANSITION`.
- There is no DELETE endpoint for invoices. Records are never deleted; cancelled invoices stay visible
  in the list under a status filter.
- Optimistic locking: `invoices.version` is returned in every response and must be sent back on
  update/approve/cancel; a mismatch → `409`, code `STALE_VERSION`.

### Automatic numbering
Format `INV-YYYY-000001`: prefix from settings, year of the issue date, 6-digit zero-padded counter that
resets per year. Allocated server-side, on creation, inside the same transaction as the insert, by
locking the matching `invoice_sequences` row (`SELECT … FOR UPDATE` / JPA `PESSIMISTIC_WRITE`), creating
the row if the year is new. Unique index on `invoice_number` is the last line of defence. The client
never sends an invoice number.

### Multi-currency
`app_settings.base_currency_code` is the reporting currency (seed: `ILS`). Every invoice stores
`currency_code` and `exchange_rate` = how many base-currency units one invoice-currency unit is worth
(invoice in USD, base ILS, rate `3.650000`). For invoices in the base currency the rate is `1` and
locked. The Create screen pre-fills the rate from `currency_exchange_rates`; the user may override it
per invoice (this is the "user-supplied exchange rate" requirement). Rates can also be maintained in
Settings. Once saved on an invoice, the rate is a snapshot and never changes. Every invoice response
returns totals in the invoice currency plus `grandTotalBase` in the base currency.

### Tax modes (per invoice; both supported)
Let `q` = quantity, `p` = unit price, `r` = tax rate as a decimal; `round()` = HALF_UP to the currency's
minor units, applied **per line**:

- **EXCLUSIVE** (unit price is net): `net = round(q·p)`, `tax = round(net·r)`, `gross = net + tax`
- **INCLUSIVE** (unit price is gross): `gross = round(q·p)`, `net = round(gross / (1 + r))`,
  `tax = gross − net`

Invoice: `subtotal = Σ net`, `tax_total = Σ tax`, `grand_total = Σ gross`,
`grand_total_base = round(grand_total · exchange_rate)`.

Put this in one pure, stateless `InvoiceCalculator` class with exhaustive unit tests (both modes, 2- and
3-decimal currencies, rounding edge cases such as `x.xx5`, zero tax, fractional quantities, many lines
so rounding drift is visible). The server always recomputes totals; it never trusts totals sent by the
client. The mobile app uses the identical formulas only for live preview.

### Barcode
`items.barcode` is unique. `GET /api/items/by-barcode/{barcode}` → item or `404`. Seed items with valid
EAN-13 barcodes (correct check digits). Generate PNG barcodes for all seeded items into `docs/barcodes/`
and embed them in the README so a reviewer can scan them off a second screen.

---

## 5. REST API contract

Base path `/api`. JSON only. Everything requires `Authorization: Bearer <accessToken>` except
`POST /api/auth/login`, `POST /api/auth/refresh`, `GET /actuator/health`, and the Swagger UI/OpenAPI
endpoints.

### Auth
- `POST /api/auth/login` `{username, password}` → `{accessToken, refreshToken, expiresInSeconds, user{id, username, fullName, role}}`
- `POST /api/auth/refresh` `{refreshToken}` → new token pair; the used refresh token is revoked (rotation)
- `POST /api/auth/logout` `{refreshToken}` → revokes it
- `GET /api/auth/me`

### Reference data
- `GET /api/currencies`
- `GET /api/exchange-rates` · `PUT /api/exchange-rates/{currencyCode}` `{rateToBase}` (ADMIN)
- `GET /api/customers?search=&page=&size=`
- `GET /api/items?search=&page=&size=` · `GET /api/items/by-barcode/{barcode}`
- `GET /api/settings` · `PUT /api/settings` (ADMIN)

### Invoices
- `GET /api/invoices?status=&search=&page=&size=&sort=` → paginated summaries (id, number, customer name, issue date, currency, grand total, status)
- `POST /api/invoices` → creates a DRAFT with lines; allocates the number; returns the full invoice with server-computed totals (`201` + `Location`)
- `GET /api/invoices/{id}` → full detail with lines and audit fields
- `PUT /api/invoices/{id}` → replaces header + lines (DRAFT only; body carries `version`)
- `POST /api/invoices/{id}/approve` `{version}` (ADMIN, SALES)
- `POST /api/invoices/{id}/cancel` `{version, reason?}` (ADMIN)

**RBAC:** SALES can read everything, create/edit drafts and approve. ADMIN can do everything, plus
cancel, settings and exchange rates.

### Conventions
- **Errors:** RFC 9457 `application/problem+json` via Spring `ProblemDetail`, with a stable `code`
  property (`VALIDATION_ERROR`, `NOT_FOUND`, `UNAUTHORIZED`, `FORBIDDEN`, `INVOICE_NOT_EDITABLE`,
  `INVALID_TRANSITION`, `STALE_VERSION`, `RATE_LIMITED`, `INTERNAL_ERROR`) and, for validation, a list
  of `{field, message}`. Never leak stack traces, SQL or internal class names.
- **Validation:** Jakarta Bean Validation on every request DTO (quantity > 0, unit price ≥ 0, exchange
  rate > 0, tax rate in [0,1], currency active, customer active, max 200 lines, notes ≤ 1000 chars…).
  Business rules (state machine, ≥1 line to approve) enforced in the service layer.
- **Pagination response:** `{content, page, size, totalElements, totalPages}`. Default `size=20`, max 100.
- **DTOs only at the API boundary** — JPA entities are never serialized.
- **OpenAPI:** annotated controllers and DTOs, Swagger UI at `/swagger-ui.html`, spec exported to
  `docs/openapi.json`.

---

## 6. Security requirements (non-negotiable)

- Passwords hashed with BCrypt (strength ≥ 10); never logged, never returned.
- Access tokens: JWT, HS256 with a ≥ 256-bit secret from env `JWT_SECRET`, 30-minute expiry,
  `iss`/`sub`/`iat`/`exp` + `role` claim.
- Refresh tokens: opaque 256-bit random, stored hashed (SHA-256), 30-day expiry, rotated on use,
  revocable, one-time use.
- Stateless sessions; CSRF disabled (bearer auth only); CORS restricted to origins from env
  `CORS_ALLOWED_ORIGINS`; default-deny on all routes; method-level `@PreAuthorize` for roles.
- Brute-force protection on `/api/auth/login`: per-username and per-IP limiter, 5 attempts per minute →
  `429` with `Retry-After`.
- All configuration via environment variables with a committed `.env.example`. No secrets in the repo:
  no real `.env`, no keystore, no passwords in `application.yml`. The `prod` profile fails fast if
  `JWT_SECRET` or DB credentials are missing.
- Actuator exposes only `health` and `info`; health details hidden from unauthenticated callers.
- Keep Spring Security's default security headers; `server.forward-headers-strategy=framework` (HTTPS is
  terminated by the hosting platform).
- Every state change is authorized and validated on the server; UI restrictions in the app are
  convenience only.
- Data access through JPA / parameterized queries only; no string-concatenated SQL.
- Structured logs with a request ID (MDC) on every line; no tokens, passwords or PII in logs.
- Dependency hygiene: current stable versions only, no unused starters, `./mvnw dependency:tree`
  reviewed.

---

## 7. Flutter app spec — exactly five screens

**Constraint:** exactly five routed screens: `/login`, `/invoices`, `/invoices/new` (reused for
`/invoices/:id/edit`), `/invoices/:id`, `/settings`. Everything else — barcode scanner, item picker,
customer picker, confirmations, cancel-reason input — is a modal bottom sheet or dialog inside those
screens. The startup check below is a redirect/overlay, not a sixth route.

Material 3, one consistent theme (light + dark), no placeholder text anywhere. Every list has
loading / empty / error states with retry. Every API error maps problem+json → a clear human message.

**Startup:** check `GET /actuator/health` with a generous timeout (free hosting may need ~60 s to wake
up): show "Connecting to server…" with a retry button rather than failing instantly. Then:
valid/refreshable token → Invoice List; otherwise → Login.

1. **Login** — username + password (show/hide), inline validation, loading state, server error text,
   tokens persisted in secure storage. No self-registration.
2. **Invoice List** — infinite-scroll pagination, pull-to-refresh, status filter chips
   (All / Draft / Approved / Cancelled), search by number or customer, rows showing
   number · customer · date · grand total with currency symbol · status badge. FAB → Create.
   Tap → Details. App-bar action → Settings.
3. **Create / Edit Sales Invoice** — customer (searchable sheet), issue date, currency dropdown,
   exchange rate (pre-filled from server rates, editable, locked at 1 for the base currency), tax mode
   segmented control (Exclusive / Inclusive), notes. Lines: "Add item" (searchable sheet) and
   "Scan barcode" (bottom sheet using `mobile_scanner`, camera permission handling, torch toggle; on
   detection → lookup by barcode → add a line, or increment quantity if the item is already on the
   invoice → haptic + snackbar; 404 → "Item not found", keep scanning). Each line: name, quantity
   field, editable unit price, tax rate (read-only from item), line total; swipe to remove. Live totals
   footer computed on-device with the same formulas via `decimal`, labelled "preview"; after saving,
   show the server's totals. Save → creates/updates the DRAFT → navigates to Details. Edit mode is
   reachable only from a DRAFT, prefills everything and sends `version`.
4. **Invoice Details** — header (number, status badge, customer, date, currency + rate, tax mode),
   lines, totals (subtotal, tax, grand total, grand total in base currency), audit (created / approved /
   cancelled by whom and when, cancellation reason). Actions by status: DRAFT → Edit / Approve / Cancel;
   APPROVED → Cancel only, with a visible lock indicator and no edit affordance; CANCELLED → read-only.
   Approve and Cancel use confirmation dialogs (Cancel collects an optional reason). Hide actions the
   current role cannot perform. On `409 STALE_VERSION` reload and tell the user.
5. **Settings** — server section (editable for ADMIN, read-only otherwise): base currency, default
   currency, default tax mode, default tax rate, invoice prefix, exchange rate per currency. App
   section: API base URL override (stored locally; defaults to the compiled
   `--dart-define=API_BASE_URL`; "Test connection" button), theme mode, app version, signed-in user +
   role, Logout (revokes the refresh token).

**Engineering**
- `dio` interceptor attaches the access token; on `401` performs a single-flight refresh once, then logs
  out on failure.
- Base URL: `String.fromEnvironment('API_BASE_URL')` with a sane default; the Settings override wins
  when set.
- `freezed`/`json_serializable` models; run `build_runner` and commit generated files.
- Android: minSdk per `mobile_scanner` requirements, camera permission declared,
  `usesCleartextTraffic` false in release (HTTPS only); allow plain HTTP only in debug via a network
  security config for local testing against `10.0.2.2`.
- `flutter analyze` clean with `flutter_lints` (no `// ignore`), `flutter test` with unit tests for the
  calculator and at least one widget test (login form).
- App name "Triosuite Invoices", a simple generated launcher icon, applicationId
  `com.bsharat.triosuite_invoices`.

---

## 8. Execution plan (in order; every phase ends with a commit and a `docs/PROGRESS.md` update)

### Phase 0 — Environment check & plan
Detect and record versions in `docs/PROGRESS.md`: `java -version`, `docker --version`,
`docker compose version`, `mysql --version`, `flutter --version`, `flutter doctor`, `adb`, `gh --version`,
`git`. If Java 21 or Flutter are missing and cannot be installed, this is the one acceptable stop.
`git init`; `.gitignore` covering Java/Maven, Flutter/Dart, IDEs, `.env`, `*.jks`, `*.keystore`,
`key.properties`. Create `AGENT_BRIEF.md`, `docs/PROGRESS.md`, `docs/DECISIONS.md`.

### Phase 1 — Scaffolding
Backend project in `backend/` with the exact starters from §3; `application.yml` with `local`/`test`/`prod`
profiles, all values env-driven; `Dockerfile`; `docker-compose.yml` (MySQL 8 with a named volume +
backend); `.env.example`. Mobile project in `mobile/` (`flutter create`, Android required, iOS may stay
untouched); folder structure from §3; theme; router with the five routes as placeholders; dio client;
secure-storage wrapper.
**Exit:** `./mvnw -q verify` passes, `docker compose up` brings MySQL and the backend up healthy
(`/actuator/health` = UP), `flutter analyze` is clean, `flutter build apk --debug` succeeds.

### Phase 2 — Database
Flyway `V1__schema.sql` (full DDL from §4) and `V2__seed.sql`: users `admin`/`Admin#2026` (ADMIN) and
`sales`/`Sales#2026` (SALES) with generated BCrypt hashes; currencies ILS (base), USD, EUR, JOD (3
decimals), GBP with rates; 6 customers; 15 items with valid EAN-13 barcodes and mixed tax rates (16% and
0%); the settings row; sequences; 6 sample invoices covering all three statuses, at least two currencies
and both tax modes, each with lines and correct stored totals. Mirror the two files to
`database/schema.sql` and `database/seed.sql` (byte-identical — add a script/CI step that diffs them).
Write `database/README.md`, and generate `database/schema_description.md` from `SHOW CREATE TABLE` for
every table. `docs/ERD.md` (Mermaid `erDiagram`).
**Exit:** a fresh `docker compose up` migrates and seeds cleanly; a second start is a no-op; SELECT
sanity checks pass.

### Phase 3 — Backend implementation
`InvoiceCalculator` + its unit tests first. Then entities, repositories, services, DTOs, mappers,
controllers, numbering under lock, state machine, optimistic locking, global exception handler, security
config, JWT, refresh rotation, login rate limiter, OpenAPI.
Tests (must exist and pass): calculator unit tests; state-machine service tests; MockMvc/Testcontainers
integration tests for login (success, wrong password, rate limit), create invoice (number allocation +
totals in both modes and in a 3-decimal currency), edit approved → 409, approve, cancel, stale version →
409, barcode lookup (found / not found), unauthenticated → 401, SALES calling cancel → 403. Concurrency
test: parallel creates receive distinct, sequential numbers. `backend/scripts/smoke.sh` (curl + jq) that
runs the reviewer journey against any base URL.
**Exit:** `./mvnw verify` green; smoke script green; `docs/openapi.json` exported; `docs/API.md` written.

### Phase 4 — Mobile implementation
Implement §7 feature by feature against the local backend (`http://10.0.2.2:8080` on the emulator).
**Exit:** `flutter analyze` clean, `flutter test` green, `flutter build apk --release` succeeds.

### Phase 5 — End-to-end verification
With the backend running, execute the full reviewer journey via the smoke script (login → list → create a
USD, tax-inclusive invoice containing a barcode-looked-up item → approve → attempt edit → 409 → cancel →
confirm the record still exists) and record commands + responses in `docs/SMOKE_TEST.md`. Fix everything
found. Re-run the whole test suite.

### Phase 6 — Documentation, CI, release
Root `README.md`: project summary; architecture diagram (Mermaid); tech stack; Reviewer quick start
(install the APK → log in with the demo credentials → the backend is already live at `<public URL>`);
local setup (backend + DB via compose, mobile); build the APK; API docs (Swagger link); test credentials
and roles; SQL scripts location stated explicitly with paths; DB screenshots location; how to run tests;
barcode images to scan; link to `docs/DEPLOYMENT.md`; summary of key decisions; known limitations.
`.github/workflows/ci.yml`: backend `./mvnw verify` with a MySQL service container; mobile
`flutter analyze`, `flutter test`, `flutter build apk --release` uploading the APK as an artifact.
Release APK: generate a release keystore locally with `keytool`, wire `key.properties` (git-ignored) into
`android/app/build.gradle.kts`, build `release/app-release.apk`, commit the APK, and document how to
rebuild. Note that the APK should also be attached to a GitHub Release.
DB screenshots: reference these exact filenames in the README now, under `database/screenshots/`:
`01_schema_overview.png` (schema tree with all tables), `table_<name>.png` (structure view for every
table), `data_invoices.png`, `data_invoice_lines.png`. These are captured manually with MySQL
Workbench/DBeaver; list them in the final report.

### Phase 7 — Deployment guide + final audit
Write `docs/DEPLOYMENT.md` per §9. Final audit: go through §1 line by line and §6 item by item and confirm
each with evidence (file path / test name / command output) in `docs/PROGRESS.md`. `git status` clean. If
`gh` is authenticated, create the GitHub repository and push; otherwise give the exact commands.

---

## 9. Deployment guide (`docs/DEPLOYMENT.md`) — goal: the reviewer installs the APK, opens it, and it just works, at zero cost

Write it for someone deploying for the first time: numbered steps, exact commands, exact env-var names
and values, expected output at each step, and a troubleshooting section. Verify the current free-tier
terms of each provider with a web search before writing — do not rely on memory, these change.

**Make the backend deployment-ready first:** Dockerfile respects `PORT` (`server.port=${PORT:8080}`),
runs as non-root, and uses JVM flags suited to a 512 MB container (e.g. `-XX:MaxRAMPercentage=75`,
`-XX:+UseSerialGC`, `-Xss512k`, `-XX:TieredStopAtLevel=1`) with Spring lazy initialization in `prod`.
`SPRING_PROFILES_ACTIVE=prod`; DB from `DB_URL`/`DB_USERNAME`/`DB_PASSWORD` (support `sslMode=REQUIRED`
for managed MySQL); Flyway runs on startup; `/actuator/health` is the platform health check.

**Option A (recommended, simplest): Render free web service + Aiven free MySQL.**
Aiven: always-free managed MySQL (1 CPU / 1 GB RAM / 1 GB storage, no credit card). Steps: create the
service, pick a region, collect host/port/database/user/password, build the JDBC URL with TLS. Render:
free web service built from `backend/Dockerfile` (set the root directory), same region as the DB, env
vars from `.env.example`, health check path `/actuator/health`. Note for the reader: the free tier sleeps
after 15 minutes idle and a JVM cold start takes ~45–60 s; Render may ask for a card for verification but
does not charge within the free tier. Keep it awake: a free UptimeRobot (or cron-job.org) HTTP monitor
hitting `/actuator/health` every 5 minutes (750 free hours/month covers 24/7 for one service). Then: run
`backend/scripts/smoke.sh https://<service>.onrender.com`, rebuild the APK with
`--dart-define=API_BASE_URL=https://<service>.onrender.com`, commit `release/app-release.apk`, put the URL
in the README, take the DB screenshots against the hosted DB if preferred.

**Option B (always-on, more setup): Oracle Cloud Always Free ARM VM.**
One Always Free Ampere VM; Docker + docker compose running MySQL + backend with
`restart: unless-stopped`; Caddy for automatic HTTPS on a free DNS name (e.g. DuckDNS); open 80/443 in
both the OCI security list and the VM firewall; basic backup note (`mysqldump` cron).

**Also cover:** a local-vs-prod checklist (`.env.example` → platform env vars) and how to generate a
strong `JWT_SECRET`; running Flyway against the managed DB the first time and verifying the tables;
changing the demo passwords and rotating `JWT_SECRET`; a review-day checklist (monitor is green, open the
app, log in, create one invoice); the reviewer fallback: the Settings screen's API URL override,
documented in the README.

---

## 10. Final report (last message)

1. What was built — one paragraph.
2. A table mapping every assessment requirement in §1 to where it is satisfied (path / endpoint /
   screen / test name).
3. The manual steps required, in order, with exact commands: create the GitHub repo and push (if not
   done), capture the DB screenshots (exact filenames), deploy with Option A (summarized), rebuild the
   APK with the public URL, attach the APK to a GitHub Release.
4. Demo credentials and the local run commands.
5. Known limitations — honest and short.
