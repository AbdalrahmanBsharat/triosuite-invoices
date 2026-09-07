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
| Android emulator | No AVD can run here | Verified on a **physical device instead** (Realme RMX2189, Android 11) over `adb reverse`: signs in, loads the invoice list, renders ILS, USD, EUR, GBP and JOD correctly — JOD at three decimals. Plus `flutter analyze` clean, 52 tests, a **signed** release APK, and **15 contract tests driving the app's real repositories and freezed models against a running backend**. |

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
- [x] freezed / json_serializable models, generated code committed
- [x] On-device totals preview mirroring the server's formulas and rounding
- [x] Android manifest, camera permission, HTTPS-only release + debug-only cleartext, signing config
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
| GitHub repository | [AbdalrahmanBsharat/triosuite-invoices](https://github.com/AbdalrahmanBsharat/triosuite-invoices) — **private**; make it public before submitting |
| README explaining how to run it | [`README.md`](../README.md) |
| SQL scripts used to create the database | **[`database/schema.sql`](../database/schema.sql)**, **[`database/seed.sql`](../database/seed.sql)** |
| Screenshots of the database tables | [`database/screenshots/`](../database/screenshots) — filenames fixed and listed; capture is a manual step |
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

## Remaining manual steps

Everything that cannot be done from this session, in order, is listed in the final report:

1. Make the repository public (it was created private)
2. Capture the 13 database screenshots
3. Deploy (Option A in [`docs/DEPLOYMENT.md`](DEPLOYMENT.md))
4. Rebuild the APK with the public URL and commit it
5. Attach the APK to a GitHub Release
