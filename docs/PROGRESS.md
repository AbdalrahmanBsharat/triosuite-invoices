# Progress

Checklist for the build described in [`AGENT_BRIEF.md`](../AGENT_BRIEF.md), and the final
requirement-by-requirement audit.

**Status: complete.** 182 tests passing, the smoke test green end to end, a signed release APK
built. Two things could not be executed on this machine and are called out honestly below.

---

## Environment (Phase 0 — recorded 2026-09-06)

| Tool | Command | Result |
|---|---|---|
| Java | `java -version` | ✅ `openjdk 21.0.12.1 2026-08-18 LTS` (Temurin) |
| Maven | `mvn -version` | ⚠️ not installed — the committed **wrapper** (`backend/mvnw`) is the entry point |
| Docker | `docker --version` | ⚠️ CLI `29.7.2` present, **engine unusable** — see the blocker below |
| Docker Compose | `docker compose version` | ⚠️ CLI `v5.5.0` present, engine unusable |
| MySQL | `mysql --version` | ✅ `8.4.9` at `C:\Program Files\MySQL\MySQL Server 8.4` (not on `PATH`) |
| MySQL Workbench | — | ✅ `8.0 CE` — what the database screenshots are taken with |
| Flutter | `flutter --version` | ✅ `3.44.0` stable · Dart `3.12.0` |
| Flutter doctor | `flutter doctor -v` | ✅ Android SDK 36.1.0, all licences accepted. ❌ Visual Studio absent — irrelevant, no Windows target |
| adb | `adb version` | ✅ at `%LOCALAPPDATA%\Android\Sdk\platform-tools\` (not on `PATH`) |
| Android emulator | `emulator -list-avds` | ⚠️ no AVDs, and none can run — the app was verified on a physical device instead |
| Physical device | `adb devices` | ✅ Realme RMX2189 (Android 11), used to verify the app end to end |
| GitHub CLI | `gh --version` | ✅ `2.96.0`, authenticated as `AbdalrahmanBsharat` |
| Git | `git --version` | ✅ `2.54.0.windows.1` |

### ⚠️ Blocker: hardware virtualization is disabled in firmware

```
$ wsl --status
WSL2 is unable to start since virtualization is not enabled on this machine.
Please ensure the "Virtual Machine Platform" optional component is enabled and
virtualization is turned on in your computer's firmware settings.

$ docker ps
request returned 500 Internal Server Error for API route and version
http://%2F%2F.%2Fpipe%2FdockerDesktopLinuxEngine/v1.55/containers/json
```

Fixing it needs a BIOS/UEFI change, an elevated `wsl.exe --install --no-distribution`, and a reboot
— none of which can be done from this session. **Two consequences, and what was done instead:**

| Blocked | Consequence | What was done instead |
|---|---|---|
| Docker engine | `docker compose up` was never executed here | `Dockerfile` and `docker-compose.yml` are written and committed, and **CI has since built the image, brought the compose stack up healthy and run the smoke test against it — green**. Integration tests use a real local MySQL, which is the fallback the brief specifies (never H2). |
| Android emulator | No AVD can run here | Verified on a **physical device instead** (Realme RMX2189, Android 11) over `adb reverse`: signs in, loads the invoice list, renders ILS, USD, EUR, GBP and JOD correctly — JOD at three decimals. Plus `flutter analyze` clean, 52 tests, a **signed** release APK, and **15 contract tests driving the app's real repositories and models against a running backend**. |

A dedicated MySQL 8.4.9 instance was provisioned on **port 3307** from the already-installed server
binaries, with its own data directory, leaving the machine's existing `MySQL84` service on 3306
untouched. See [`database/README.md`](../database/README.md).

---

## Phases

### Phase 0 — Environment check & plan
- [x] Record all tool versions
- [x] `git init` (branch `main`), author configured
- [x] `.gitignore` covering Java/Maven, Flutter/Dart, Android, iOS, IDEs, `.env`, `*.jks`, `key.properties`
- [x] `.gitattributes` normalising line endings (`mvnw` must stay LF)
- [x] `AGENT_BRIEF.md`, `docs/PROGRESS.md`, `docs/DECISIONS.md`
- [x] Isolated MySQL 8.4.9 on `127.0.0.1:3307` (`triosuite`, `triosuite_test`)

### Phase 1 — Scaffolding
- [x] Spring Boot 4.1.1 / Java 21 project with the Maven wrapper
- [x] Starters: webmvc, data-jpa, security, validation, actuator, flyway + flyway-mysql, mysql-connector-j
- [x] springdoc-openapi 3.1.0, jjwt 0.13.0, Lombok
- [x] `application.yml` — `local` / `test` / `prod`, every value env-driven, validated `AppProperties`
- [x] `backend/Dockerfile` — multi-stage, `eclipse-temurin:21-jre`, non-root, `PORT`-aware, 512 MB JVM flags
- [x] `docker-compose.yml` — MySQL 8 with a named volume + the API, both health-checked
- [x] `.env.example`
- [x] Flutter project, feature-first structure, Material 3 light + dark, five routes, dio client, secure-storage wrapper
- [x] **Exit:** `./mvnw -q verify` passes
- [x] **Exit:** `flutter analyze` clean · `flutter build apk` succeeds
- [x] ⚠️ **Exit (partial):** `docker compose up` — not executable here; verified by CI instead

### Phase 2 — Database
- [x] `V1__schema.sql` — 10 tables, FK + index on every reference, CHECK constraints
- [x] `V2__seed.sql` — 2 accounts, 5 currencies + rates, 6 customers, 15 items with valid EAN-13, settings, sequences, 6 invoices
- [x] Mirrored byte-for-byte to `database/schema.sql` / `seed.sql`, with `scripts/check-sql-mirror.sh` and a CI job
- [x] `database/README.md`
- [x] `database/schema_description.md` generated from `DESCRIBE` + `SHOW CREATE TABLE`
- [x] `docs/ERD.md` (Mermaid)
- [x] **Exit:** fresh migrate + seed clean; second start a no-op; SELECT sanity checks pass

### Phase 3 — Backend implementation
- [x] `InvoiceCalculator` + 30 pure unit tests, written first
- [x] Entities, repositories, DTOs, services, controllers
- [x] Numbering under a `PESSIMISTIC_WRITE` row lock
- [x] State machine + optimistic locking, version checked before the state rules
- [x] RFC 9457 `ProblemDetail` handler with stable codes
- [x] JWT HS256, rotating single-use refresh tokens, BCrypt(12), CORS, method security
- [x] Login rate limiter — 5/min per username **and** per IP → `429` + `Retry-After`
- [x] Request-ID MDC filter
- [x] OpenAPI annotations + Swagger UI
- [x] 82 integration tests against real MySQL, covering every case the brief lists
- [x] Concurrency test: 12 parallel creates get distinct, gapless numbers
- [x] `backend/scripts/smoke.sh`
- [x] **Exit:** `./mvnw verify` green · `docs/openapi.json` exported · `docs/API.md` written

### Phase 4 — Mobile implementation
- [x] Login · Invoice list · Create/Edit · Details · Settings — **exactly five routes**
- [x] Barcode scanner, item picker, customer picker, confirmations, cancel-reason — all modals
- [x] Dio auth interceptor with single-flight refresh
- [x] Model layer, repositories and GetX controllers
- [x] On-device totals preview mirroring the server's formulas and rounding
- [x] Android manifest, camera permission, network security config, signing config
- [x] Generated launcher icon at five densities
- [x] **Exit:** `flutter analyze` clean, no `// ignore` · `flutter test` green · `flutter build apk --release` succeeds

### Phase 5 — End-to-end verification
- [x] Full reviewer journey recorded in `docs/SMOKE_TEST.md`
- [x] **Three real defects found and fixed** (line-replacement unique-key violation, new-year gap-lock deadlock, duplicate invoice numbers from a poisoned persistence context) — each with a regression test
- [x] A fourth found separately: `@PreAuthorize` denials returning `500` instead of `403`
- [x] Whole suite re-run green

### Phase 6 — Documentation, CI, release
- [x] Root `README.md`
- [x] `.github/workflows/ci.yml` — SQL mirror · backend with a MySQL service container · Docker build + compose + smoke · mobile analyze/test/build with the APK as an artifact
- [x] Release keystore generated, `key.properties` wired in, both git-ignored
- [x] `release/app-release.apk` built and committed, signature verified
- [x] `docs/barcodes/` — 15 PNGs + a contact sheet, embedded in the README
- [x] DB screenshot filenames referenced in the README, with instructions in `database/screenshots/README.md`

### Phase 7 — Deployment guide + final audit
- [x] `docs/DEPLOYMENT.md` — free-tier terms **verified by web search** (September 2026), each claim sourced
- [x] Requirement-by-requirement audit of §1, below
- [x] Item-by-item audit of §6, below
- [x] `git status` clean
- [x] **CI green on all four jobs** — including the Docker job, which builds the image, brings the
      compose stack up and runs the smoke test against it: the verification that could not be done
      on this machine
- [x] GitHub repository created and pushed: https://github.com/AbdalrahmanBsharat/triosuite-invoices (private — one command in the final report makes it public)

### Phase 8 — Fresh-clone dry run (2026-09-07)

Ran the project the way a reviewer receiving the repository would: the development MySQL instance
was moved aside to `%LOCALAPPDATA%\triosuite-mysql-parked` to simulate a machine that had never run
this project, and the repository was cloned from GitHub into a new directory.

- [x] **Gap found.** `scripts/run-local.ps1` only *started* the MySQL instance at
      `%LOCALAPPDATA%\triosuite-mysql` and failed when there was none, pointing at
      `database/README.md` — which documented the connection details and how to start the instance,
      but never how to create one. A reviewer without Docker had no way forward. Fixed in `5d4c03b`:
      the script now initialises its own data directory, writes `my.ini`, starts the server and
      creates both databases and the application user on first run, and `-DatabaseOnly` /
      `-Reinitialize` were added. The README section is no longer titled "on the machine this was
      built on", because it no longer is.
- [x] Re-ran from the clone: instance created, API built and started, Flyway applied both migrations
- [x] `GET /actuator/health` → `{"status":"UP"}`
- [x] Seed verified through the API: base and default currency `JOD`, five exchange rates, six
      invoices across all three statuses, 15 catalogue items
- [x] Write path verified: created `INV-2026-000007`, approved it, confirmed the edit was refused
      with `409 INVOICE_NOT_EDITABLE`, cancelled it and confirmed the row survived
- [x] Authorization verified: `sales` → `403 FORBIDDEN` on `PUT /api/settings`, anonymous → `401`
- [x] Full backend suite re-run against the test database the script had just created
- [x] Dev database dropped and recreated afterwards, so it holds exactly the seeded data
- [x] The four `TINYINT(1)` columns became `BOOLEAN`. MySQL 8.4 emits a deprecation warning for an
      explicit integer display width, so a reviewer's very first boot logged four of them.
      `BOOLEAN` is a synonym that produces a byte-identical `tinyint(1)` column, verified by
      regenerating `database/schema_description.md` and diffing it: no change. The warnings are
      gone and the 131 backend tests still pass.

Two stale statements in the mobile docs were corrected in the same pass: the debug network security
config is a blanket cleartext permission (needed for a phone on Wi-Fi, whose LAN address cannot be
enumerated in advance), not a three-address allowlist, and both `mobile/README.md` and the release
config's own comment still described the old form. (Release builds were HTTPS-only at that point;
ADR-0014 later reversed that, once the hosted backend was dropped.)

---

## Audit — §1, the assessment's own requirements

### Screens: "should not exceed five"

Exactly five `GetPage` entries in
[`mobile/lib/core/routing/app_pages.dart`](../mobile/lib/core/routing/app_pages.dart):

| Screen | Route | Source |
|---|---|---|
| Login | `/login` | `features/auth/presentation/login_page.dart` |
| Invoice List | `/invoices` | `features/invoices/presentation/invoice_list_page.dart` |
| Create Sales Invoice | `/invoices/new` (reused for edit) | `features/invoices/presentation/invoice_form_page.dart` |
| Invoice Details | `/invoices/:id` | `features/invoices/presentation/invoice_detail_page.dart` |
| Settings | `/settings` | `features/settings/presentation/settings_page.dart` |

The barcode scanner, item picker, customer picker, approve/cancel confirmations and the
cancel-reason prompt are all bottom sheets or dialogs inside those five. The start-up connectivity
check is an overlay on the login route, not a sixth screen.

### Capabilities

| Requirement | Where it is implemented | How it is proved |
|---|---|---|
| **Multi-currency, user-supplied exchange rates** | `exchange_rate` snapshotted per invoice; `_CurrencyAndRate` on the form pre-fills from `/api/exchange-rates` and lets the user override; base currency pinned to 1 server-side (`InvoiceService.resolveExchangeRate`) | `InvoiceCalculationIT.userSuppliedExchangeRateIsUsed`, `.threeDecimalCurrency`; `InvoiceLifecycleIT.baseCurrencyRateIsForcedToOne`; `api_contract_test.dart` "currencies carry the minor units" |
| **Tax inclusive and exclusive** | `InvoiceCalculator` (Java) and `invoice_calculator.dart` — identical formulas | 30 Java + 30 Dart unit tests **on the same expected figures**; `InvoiceCalculationIT.exclusiveTaxIsAddedOnTop`, `.inclusiveTaxIsExtracted` |
| **Automatic numbering** | `InvoiceNumberAllocator` — `SELECT … FOR UPDATE` on `invoice_sequences` inside the creating transaction; `INV-YYYY-000001`, resets per year | `InvoiceLifecycleIT.numbersAreSequential`, `.sequenceRestartsPerYear`, `.clientSuppliedNumberIsIgnored`; `InvoiceNumberingConcurrencyIT` (12 parallel creates) |
| **Approval makes invoices non-editable** | `InvoiceStatus.isEditable()`; `InvoiceService.update` throws `INVOICE_NOT_EDITABLE`; the app shows a lock and no edit affordance | `InvoiceLifecycleIT.approvedInvoiceCannotBeEdited`, `.cancelledInvoiceCannotBeEdited`; smoke test step 11 |
| **Cancel without deleting** | `InvoiceService.cancel` — status change with `cancelled_by`/`cancelled_at`/reason. **No DELETE endpoint exists** | `InvoiceLifecycleIT.approvedInvoiceCanBeCancelled`, `.cancelledInvoicesRemainListed`, `.thereIsNoDeleteEndpoint`; smoke test step 13 |
| **Barcode scanning via a Flutter package** | `mobile_scanner` 7.4 in `barcode_scanner_sheet.dart` → `GET /api/items/by-barcode/{barcode}`; torch, permission handling, duplicate suppression, quantity increment on rescan | `CatalogIT.barcodeLookupFindsTheItem`, `.barcodeLookupReturnsNotFound`; `api_contract_test.dart`; `SeededInvoiceTotalsIT` verifies every seeded EAN-13 check digit |

### Deliverables

| Required | Delivered |
|---|---|
| GitHub repository | **[AbdalrahmanBsharat/triosuite-invoices](https://github.com/AbdalrahmanBsharat/triosuite-invoices)** — public |
| README explaining how to run it | [`README.md`](../README.md) |
| SQL scripts used to create the database | **[`database/schema.sql`](../database/schema.sql)**, **[`database/seed.sql`](../database/seed.sql)** |
| Screenshots of the database tables | **[`database/screenshots/`](../database/screenshots)** — all ten tables plus `flyway_schema_history`, from Workbench's Table Inspector |
| Source code for the REST APIs | [`backend/`](../backend) |
| APK | [`release/app-release.apk`](../release/app-release.apk) — signed, verified with `apksigner` |
| Clear location of the SQL scripts | Stated with paths in the README's [Where everything lives](../README.md#where-everything-lives) table, and again in `database/README.md` |

---

## Audit — §6, security requirements

| Requirement | Evidence |
|---|---|
| BCrypt ≥ 10, never logged or returned | `SecurityConfig.passwordEncoder()` — strength **12**. `UserResponse` carries only id, username, fullName, role. `AuthIT.loginSucceeds` asserts `passwordHash` and `email` are absent |
| JWT HS256, ≥ 256-bit secret from `JWT_SECRET`, 30 min, `iss`/`sub`/`iat`/`exp` + `role` | `JwtService`. `AppProperties.Jwt.secret` is `@Size(min = 32)`, so a short key fails at startup. `AuthIT` asserts `expiresInSeconds` is 1800 |
| Refresh tokens: opaque 256-bit, SHA-256 hashed, 30 days, rotated, revocable, single-use | `AuthService` — `SecureRandom(32)`, `sha256Hex`, `revokedAt` stamped on exchange. `AuthIT.refreshRotatesTheToken`, `.logoutRevokesAndIsIdempotent` |
| Stateless sessions, CSRF off, CORS from env, default-deny, `@PreAuthorize` | `SecurityConfig` — `SessionCreationPolicy.STATELESS`, `csrf.disable()`, `corsConfigurationSource()` from `CORS_ALLOWED_ORIGINS`, `anyRequest().authenticated()`. `ApiSecurityIT` — 9 parameterised anonymous `401`s + the role split |
| Login brute-force: 5/min per username and per IP → `429` + `Retry-After` | `LoginRateLimiter`. `LoginRateLimitIT.sixthFailureIsRateLimited`, `.rateLimitAppliesEvenToValidCredentials`; `LoginRateLimiterTest` (8 tests) covers both keys and window expiry |
| Everything from env, `.env.example` committed, no secrets in the repo, prod fails fast | [`.env.example`](../.env.example). `git ls-files` shows no `.env`, `.jks`, `.keystore` or `key.properties`. The `prod` profile has **no defaults** for `JWT_SECRET` or the DB credentials |
| Actuator exposes only health and info; health details hidden | `management.endpoints.web.exposure.include: health,info`, `show-details: never`. `ApiSecurityIT.healthHidesDetails`, `.actuatorSurfaceIsMinimal` — the latter checks eight endpoints as both anonymous and admin |
| Default security headers kept; `forward-headers-strategy: framework` | `ApiSecurityIT.securityHeadersArePresent` asserts `X-Content-Type-Options`, `X-Frame-Options`, `Cache-Control` |
| Every state change authorized and validated server-side | `@PreAuthorize` on each mutating controller method; the state machine and version check live in `InvoiceService`, on entities loaded from the database. `InvoiceCalculationIT.clientSuppliedTotalsAreIgnored`, `.taxRateIsTakenFromTheItem` |
| JPA / parameterized queries only, no concatenated SQL | All access via Spring Data repositories and Criteria specifications. `InvoiceSpecifications` builds predicates, never strings. `CatalogIT.barcodeLookupRejectsJunk` sends `' OR 1=1--` and gets a `400` |
| Structured logs with a request ID; no tokens, passwords or PII | `RequestIdFilter` puts `requestId` in the MDC and the console pattern prints it; the header value is sanitised so a caller cannot forge log lines. `JwtService` logs an exception class, never the token |
| Dependency hygiene | `./mvnw dependency:tree` reviewed; no unused starters. Version pins explained in ADR-0001 and ADR-0012 |
| No stack traces, SQL or class names in responses | `GlobalExceptionHandler` logs detail and returns generic text. `ApiSecurityIT.errorsDoNotLeakInternals` asserts the body contains none of `com.bsharat`, `org.springframework`, `Exception`, `at `, `SELECT` |

---

## Test inventory

```
backend  ./mvnw verify     48 unit + 82 integration = 130
mobile   flutter test       30 calculator + 15 contract + 7 widget = 52
                                                          total 182
```

| Suite | Tests |
|---|---|
| `InvoiceCalculatorTest` (Java, no Spring) | 30 |
| `invoice_calculator_test.dart` (same expected figures) | 30 |
| `InvoiceLifecycleIT` | 22 |
| `ApiSecurityIT` | 23 |
| `api_contract_test.dart` (against a live API) | 15 |
| `CatalogIT` | 12 |
| `AuthIT` | 10 |
| `InvoiceStatusTest` | 10 |
| `InvoiceCalculationIT` | 8 |
| `LoginRateLimiterTest` | 8 |
| `login_page_test.dart` | 7 |
| `SeededInvoiceTotalsIT` | 3 |
| `LoginRateLimitIT` | 3 |
| `InvoiceNumberingConcurrencyIT` | 1 |

---

## Phase 9 — Local-only delivery (2026-09-08)

Hosting was dropped. Every reviewer runs the API themselves and points the app at it, so there is no
deployment to keep alive and nothing to pay for. `docs/DEPLOYMENT.md` is kept, unchanged and still
correct, for whoever wants the hosted route later.

- [x] **Gap found.** The committed release APK could not reach *any* local backend. Verified with
      `aapt2 dump xmltree release/app-release.apk`: `cleartextTrafficPermitted=false`, no
      `<domain-config>`. HTTPS-only was right while a hosted API was planned; with none, the APK
      deliverable was unusable — an emulator, a USB tunnel and a LAN address are all plain HTTP.
- [x] Release build now permits cleartext, manifest and network security config kept in step for
      API 23 — reasoning and the revert in [ADR-0014](DECISIONS.md)
- [x] Trust anchors in release stay `system` only; the debug variant keeps its user-CA trust
- [x] APK rebuilt, still signed with the release keystore, and re-verified with `aapt2`
- [x] README reviewer quick start rewritten around the three local setups, with the address for each
- [x] Stale HTTPS-only claims removed from `README.md`, `mobile/README.md` and this file

---

## Phase 10 — Deliverables closed out (2026-09-08)

- [x] Repository made public
- [x] Database screenshots captured and committed — all ten application tables plus
      `flyway_schema_history`, renamed from their camera-roll filenames to the documented ones
- [x] `README.md`, `database/README.md` and `database/screenshots/README.md` rewritten to list what
      is actually there, rather than the thirteen filenames originally planned. The separate schema
      overview was dropped because every shot already has the Navigator expanded on
      `triosuite → Tables`; the two row-data shots were not taken

Every deliverable in the assessment is now in the repository. Nothing is outstanding.
