# Triosuite Invoices

An ERP sales-invoice system: a **Flutter** app on a **Spring Boot** REST API over **MySQL 8**.

Multi-currency invoicing with user-supplied exchange rates, tax-inclusive and tax-exclusive
calculation, server-side automatic numbering, an approval and cancellation lifecycle, and barcode
scanning — across exactly five screens.

Built for the Triosuite technical assessment. The full brief is in
[`AGENT_BRIEF.md`](AGENT_BRIEF.md).

---

## Jump to what you need

| | |
|---|---|
| 📱 **Install and try it** | [Reviewer quick start](#reviewer-quick-start) |
| 🗄️ **The SQL scripts** | **[`database/schema.sql`](database/schema.sql)** and **[`database/seed.sql`](database/seed.sql)** — see [Where everything lives](#where-everything-lives) |
| 📸 **Database screenshots** | [`database/screenshots/`](database/screenshots) |
| 🔌 **The REST API source** | [`backend/src/main/java/com/bsharat/triosuite/`](backend/src/main/java/com/bsharat/triosuite) |
| 📦 **The APK** | [`release/app-release.apk`](release/app-release.apk) |
| 📖 **API reference** | [`docs/API.md`](docs/API.md) · Swagger UI at `/swagger-ui.html` |
| 🧪 **Proof it works** | [`docs/SMOKE_TEST.md`](docs/SMOKE_TEST.md) |
| 🤔 **Why it is built this way** | [`docs/DECISIONS.md`](docs/DECISIONS.md) |

---

## Reviewer quick start

**1. Install the app.** Download [`release/app-release.apk`](release/app-release.apk) onto an
Android phone (Android 6.0 / API 23 or newer) and open it. Android will ask you to allow installing
from this source.

**2. Sign in.**

| Username | Password | Role | Can do |
|---|---|---|---|
| `admin` | `Admin#2026` | ADMIN | Everything — including cancelling invoices and editing settings |
| `sales` | `Sales#2026` | SALES | Read everything, create and edit drafts, approve. **Cannot** cancel or change settings |

Sign in as both. The difference is visible: the Cancel button simply is not there for `sales`, and
the Settings screen becomes read-only.

**3. Point it at a backend.** The committed APK is built for the Android emulator against a local
backend (`http://10.0.2.2:8080`). On a physical phone, or against a deployment, set the address once
in the app:

> **Settings → API address** → type the base URL → **Test connection** → **Save**
>
> The same button appears on the "cannot reach the server" screen, which is where you would want it.

To run the backend yourself, see [Running it locally](#running-it-locally) — it is one command.

**4. Things worth trying.**

- **Scan a barcode.** New invoice → **Scan** → point the camera at one of the
  [barcodes below](#barcodes-to-scan) on another screen. It adds the item; scan it again and the
  quantity goes up.
- **Watch the tax mode.** Switch Exclusive ↔ Inclusive on an invoice with lines. Exclusive adds tax
  on top; Inclusive extracts it from the price you typed. The total changes accordingly.
- **Change the currency to JOD.** Every figure switches to three decimals, because that is how the
  dinar is quoted — and the lines are re-priced at the new rate.
- **Approve an invoice.** It locks. The Edit button disappears, and a lock notice replaces it.
- **Cancel one** (as `admin`). It stays in the list under the **Cancelled** filter, with its lines,
  totals and approval stamp intact. Nothing is ever deleted.
- **Look at an invoice number.** You never typed one. The server allocates them, under a row lock,
  so two people creating invoices at the same moment cannot collide.

---

## Where everything lives

The assessment asks for specific deliverables. Here they are, by path.

| Deliverable | Path |
|---|---|
| **SQL script — schema** | **[`database/schema.sql`](database/schema.sql)** |
| **SQL script — demo data** | **[`database/seed.sql`](database/seed.sql)** |
| Schema description (`DESCRIBE`, `SHOW CREATE TABLE`) | [`database/schema_description.md`](database/schema_description.md) |
| How to run the scripts | [`database/README.md`](database/README.md) |
| **Database table screenshots** | **[`database/screenshots/`](database/screenshots)** |
| **REST API source** | [`backend/`](backend) |
| **APK** | **[`release/app-release.apk`](release/app-release.apk)** |
| Flutter source | [`mobile/`](mobile) |

The two SQL files are **byte-for-byte copies** of the Flyway migrations the application actually
runs (`backend/src/main/resources/db/migration/`). They exist separately so they can be read and run
on their own, and CI fails the build if the two ever drift apart —
[`scripts/check-sql-mirror.sh`](scripts/check-sql-mirror.sh).

---

## Architecture

```mermaid
flowchart LR
    subgraph phone["📱 Flutter app"]
        direction TB
        ui["5 screens<br/>login · list · form · detail · settings"]
        calc["InvoiceCalculator<br/><i>preview only</i>"]
        dio["dio<br/>bearer token + single-flight refresh"]
        ui --> calc
        ui --> dio
    end

    subgraph api["☕ Spring Boot 4.1 · Java 21"]
        direction TB
        sec["Security filter chain<br/>JWT · RBAC · rate limiting"]
        ctl["Controllers<br/>DTOs only, never entities"]
        svc["Services<br/>state machine · numbering · optimistic locking"]
        engine["InvoiceCalculator<br/><b>source of truth</b>"]
        sec --> ctl --> svc --> engine
    end

    db[("🗄️ MySQL 8<br/>10 tables · Flyway")]

    dio -- "HTTPS · JSON" --> sec
    svc -- "JPA · SELECT … FOR UPDATE" --> db

    style phone fill:#e0f2f1,stroke:#00696d
    style api fill:#e8eaf6,stroke:#3949ab
    style db fill:#fff3e0,stroke:#ef6c00
```

The app computes totals on-device so the figures move as you type — but it is a **preview**. The
server recomputes every line and every total on each write and stores its own answer, and the
detail screen shows that. Both implementations use identical formulas and identical rounding, and
[each is tested against the same expected figures](#tests), so they cannot silently diverge.

### Stack

| | |
|---|---|
| **Backend** | Java 21 · Spring Boot 4.1.1 · Spring Security 7 · Hibernate 7 · Flyway 12 · springdoc-openapi 3 · jjwt |
| **Database** | MySQL 8.4 · InnoDB · utf8mb4 |
| **Mobile** | Flutter 3.44 · Dart 3.12 · GetX · dio · freezed · mobile_scanner · decimal · flutter_secure_storage |
| **Build** | Maven wrapper · Gradle (Kotlin DSL) · GitHub Actions · multi-stage Docker |

---

## Running it locally

### Everything at once, with Docker

```bash
cp .env.example .env      # then set MYSQL_ROOT_PASSWORD, DB_PASSWORD and JWT_SECRET
docker compose up --build

curl -sS localhost:8080/actuator/health     # {"status":"UP"}
```

Flyway creates and seeds the schema on first start; a second start is a no-op.

> The Docker artifacts were **not** run on the machine this was built on — hardware virtualization
> is disabled in its firmware, so Docker Desktop's backend cannot start. They are exercised by CI
> instead, which builds the image, brings the stack up and runs the smoke test against it. See
> [Known limitations](#known-limitations).

### Backend against your own MySQL

```bash
mysql -u root -p -e "CREATE DATABASE triosuite CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"

cd backend
DB_URL='jdbc:mysql://127.0.0.1:3306/triosuite?sslMode=DISABLED&allowPublicKeyRetrieval=true&characterEncoding=utf8&connectionTimeZone=UTC&forceConnectionTimeZoneToSession=true' \
DB_USERNAME=root DB_PASSWORD=yourpassword \
./mvnw spring-boot:run
```

The `local` profile carries development defaults, so with a MySQL on `127.0.0.1:3307` and the
credentials in [`database/README.md`](database/README.md), `./mvnw spring-boot:run` alone is enough.

### The app

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080     # emulator
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080 # physical device on your LAN
```

`10.0.2.2` is how the Android emulator reaches `localhost` on the host machine.

### Building the APK

```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.example.com
cp build/app/outputs/flutter-apk/app-release.apk ../release/app-release.apk
```

To sign with your own key rather than the debug one:

```bash
keytool -genkeypair -v -keystore mobile/android/triosuite-release.jks \
    -alias triosuite -keyalg RSA -keysize 4096 -validity 10000

cat > mobile/android/key.properties <<'EOF'
storeFile=triosuite-release.jks
storePassword=<yours>
keyAlias=triosuite
keyPassword=<yours>
EOF
```

Both files are git-ignored. When `key.properties` is absent the release build falls back to the
debug key, so `flutter build apk --release` works for anyone who just wants to try it.

---

## API

Full reference: **[`docs/API.md`](docs/API.md)**. Machine-readable spec:
[`docs/openapi.json`](docs/openapi.json).

**Swagger UI is at `/swagger-ui.html`** on any running instance — the fastest way to explore this.
Call `POST /api/auth/login`, paste the `accessToken` into **Authorize**, and everything becomes
callable from the browser.

| | |
|---|---|
| Auth | `POST /api/auth/login` `/refresh` `/logout` · `GET /api/auth/me` |
| Reference | `GET /api/currencies` `/exchange-rates` `/customers` `/items` `/settings` |
| Barcode | `GET /api/items/by-barcode/{barcode}` |
| Invoices | `GET`/`POST` `/api/invoices` · `GET`/`PUT` `/api/invoices/{id}` · `POST` `/api/invoices/{id}/approve` `/cancel` |

Errors are RFC 9457 problem documents with a stable `code` — clients branch on that, never on the
message. There is deliberately **no delete endpoint**: an invoice that should not stand is
cancelled.

---

## Tests

```bash
cd backend && ./mvnw verify        # 48 unit + 82 integration
cd mobile  && flutter test         # 52
cd mobile  && flutter analyze      # clean, no ignore comments
```

**182 tests**, all passing.

| Suite | Count | What it proves |
|---|---|---|
| `InvoiceCalculatorTest` (Java) | 30 | Both tax modes, 2- and 3-decimal currencies, exact-half rounding, zero tax, fractional quantities, per-line rounding drift, `net + tax = gross`, base conversion. No Spring context. |
| `invoice_calculator_test.dart` | 30 | **The same expected figures**, against the Dart implementation — so changing one side without the other fails a build. |
| `InvoiceLifecycleIT` | 22 | Create, numbering and its per-year reset, update, approve, `INVOICE_NOT_EDITABLE`, `INVALID_TRANSITION`, `STALE_VERSION`, cancel, and that no delete endpoint exists. |
| `ApiSecurityIT` | 23 | Anonymous `401` on every protected route, tampered tokens, the SALES/ADMIN split, the actuator surface, security headers, and that no error leaks an internal name. |
| `api_contract_test.dart` | 15 | The app's real models and repositories against a **running API** — every field, enum, date and decimal, plus the full lifecycle from the app's side. |
| `CatalogIT` | 12 | Barcode found and not found, search across name/SKU/barcode, inactive customers excluded, pagination and its cap. |
| `AuthIT` | 10 | Login, wrong password, unknown username, refresh rotation, single-use refresh tokens, idempotent logout. |
| `InvoiceStatusTest`, `LoginRateLimiterTest` | 18 | The state machine as a closed table; rate-limit windows, expiry, per-username and per-IP scoping. |
| `InvoiceCalculationIT` | 8 | Both modes and JOD through the API; client-supplied totals ignored; tax rate taken from the catalogue. |
| `login_page_test.dart` | 7 | Validation, the show/hide toggle, the error path, and that no registration affordance exists. |
| `SeededInvoiceTotalsIT` | 3 | Every seeded invoice re-derived with the production calculator; every seeded EAN-13 check digit verified. |
| `LoginRateLimitIT` | 3 | Five failures then `429` + `Retry-After` — and that a *correct* password is refused too once the allowance is spent. |
| `InvoiceNumberingConcurrencyIT` | 1 | Twelve parallel creates receive distinct, gapless, sequential numbers. |

Integration tests run against a **real MySQL 8**, never H2 — the schema uses CHECK constraints,
`DATETIME(6)` and `SELECT … FOR UPDATE`, so anything else would be testing something other than
what ships.

### End to end

```bash
backend/scripts/smoke.sh                                   # localhost:8080
backend/scripts/smoke.sh https://your-api.example.com      # any deployment
```

Walks the whole reviewer journey and exits non-zero at the first thing that misbehaves. A recorded
run, with request and response bodies, is in [`docs/SMOKE_TEST.md`](docs/SMOKE_TEST.md) — including
the three real bugs it caught.

---

## Barcodes to scan

Every seeded item has a valid EAN-13. Open this on a second screen and scan from the app.

**All fifteen on one sheet:** [`docs/barcodes/all-barcodes.png`](docs/barcodes/all-barcodes.png)

| | | |
|---|---|---|
| ![Business Laptop](docs/barcodes/LAP-1401_7290001000014.png) | ![Wireless Mouse](docs/barcodes/MSE-2201_7290001000021.png) | ![Mechanical Keyboard](docs/barcodes/KBD-3310_7290001000038.png) |
| ![4K Monitor](docs/barcodes/MON-2704_7290001000045.png) | ![Docking Station](docs/barcodes/DCK-1102_7290001000052.png) | ![Laser Printer](docs/barcodes/PRN-4400_7290001000069.png) |
| ![Toner](docs/barcodes/TNR-4401_7290001000076.png) | ![Copy Paper](docs/barcodes/PPR-0500_7290001000083.png) | ![Office Chair](docs/barcodes/CHR-7700_7290001000090.png) |
| ![Standing Desk](docs/barcodes/DSK-1400_7290001000106.png) | ![Network Switch](docs/barcodes/NET-2400_7290001000113.png) | ![Patch Cable](docs/barcodes/CBL-0603_7290001000120.png) |
| ![Software Licence](docs/barcodes/LIC-0001_7290001000137.png) | ![Support Hour](docs/barcodes/SVC-0010_7290001000144.png) | ![Extended Warranty](docs/barcodes/WRT-0024_7290001000151.png) |

The last three are **zero-rated**, which is the quickest way to see tax handling behave correctly on
a mixed invoice.

Regenerate them with `java scripts/GenerateBarcodes.java` — it reads the codes out of `seed.sql` and
verifies every check digit before drawing, so the images cannot drift from the database.

---

## Database

Diagram: [`docs/ERD.md`](docs/ERD.md) · DDL: [`database/schema.sql`](database/schema.sql) ·
Column detail: [`database/schema_description.md`](database/schema_description.md)

Ten InnoDB tables in utf8mb4, with a foreign key and an index on every reference, and CHECK
constraints for the enum columns, non-negative amounts and positive quantities — so the data stays
correct even if a row is ever written by something other than this application.

Three conventions run through all of it:

- **Money is never a float.** `DECIMAL(19,4)` amounts, `DECIMAL(19,6)` rates, `DECIMAL(5,4)` tax
  rates, `DECIMAL(12,3)` quantities. `BigDecimal` in Java, `Decimal` in Dart.
- **Time is always UTC.** `DATETIME(6)`, ISO-8601 with a trailing `Z` on the wire, formatted to the
  device's locale by the app.
- **Nothing is deleted.** Invoice lines snapshot the item's name, barcode, price and tax rate, so an
  approved invoice renders identically in five years however the catalogue has changed.

### Screenshots

In [`database/screenshots/`](database/screenshots):

`01_schema_overview.png` · `table_users.png` · `table_refresh_tokens.png` · `table_currencies.png` ·
`table_currency_exchange_rates.png` · `table_customers.png` · `table_items.png` ·
`table_app_settings.png` · `table_invoice_sequences.png` · `table_invoices.png` ·
`table_invoice_lines.png` · `data_invoices.png` · `data_invoice_lines.png`

---

## Deployment

**[`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)** — two zero-cost routes, with exact commands, the
expected output at each step, and a troubleshooting table. Free-tier terms were verified in
September 2026 and each claim links to its source.

- **Option A** — Render free web service + Aiven free MySQL. About 25 minutes, all in a browser.
- **Option B** — Oracle Cloud Always Free ARM VM with Docker and Caddy. Always on, no cold start.

The backend needs no changes to deploy: it honours `PORT`, runs as a non-root user, is tuned for a
512 MB container, migrates its own schema, and refuses to start in `prod` without its secrets.

---

## Key decisions

Full record with the reasoning: **[`docs/DECISIONS.md`](docs/DECISIONS.md)** — 13 entries.
The ones that shaped the most code:

- **Rounding is per line, half-up, to the invoice currency's minor units, and invoice totals are the
  sum of the already-rounded lines** — never a re-rounding of an unrounded sum. That keeps
  `Σ lines == invoice total` exactly, which is the first thing an auditor checks. Both
  implementations follow it identically.
- **Invoice lines snapshot the catalogue** rather than joining to it, because an approved invoice is
  a financial record and must not change when a price does.
- **Numbering uses a locked sequence row**, not `AUTO_INCREMENT`, which cannot restart per year or
  carry a prefix. Allocation happens under `SELECT … FOR UPDATE` inside the creating transaction.
- **Refresh tokens are opaque, hashed, single-use and rotated** — a JWT refresh token cannot be
  revoked, and revocation was a requirement.
- **The version check runs before the state-machine check**, so a caller working from a stale copy
  is told to reload rather than given an explanation of a state they have not seen.
- **Integration tests use a real MySQL, never H2**, because the DDL is MySQL-specific.

---

## Known limitations

Stated plainly, because a reviewer will find them anyway.

- **The Docker artifacts were never run on the development machine.** Hardware virtualization is
  disabled in its firmware, so Docker Desktop's WSL2 backend cannot start. `Dockerfile` and
  `docker-compose.yml` are written and reviewed but were verified only by CI, which builds the
  image, brings the stack up and runs the smoke test against it.
- **The app was never run on a device or emulator.** The same firmware limitation blocks the Android
  emulator, and no physical device was available. What *is* verified: `flutter analyze` is clean, 52
  tests pass, `flutter build apk --release` produces a signed APK, and 15 contract tests drive the
  app's real repositories and models against a running backend — which covers the serialization and
  lifecycle an emulator run would have exercised. The UI itself has not been seen rendered.
- **Integration tests use a local MySQL rather than Testcontainers**, for the same reason. The
  fallback is the one the brief specifies, and CI uses a MySQL service container through the same
  environment variables.
- **The login rate limiter is in-memory.** Correct for the single instance this deploys as; it
  resets on restart and is not shared between replicas. Horizontal scaling would want Redis.
- **The APK is 68 MB.** It is a universal build — three ABIs plus ML Kit's bundled barcode model —
  so it installs anywhere without the reviewer choosing a variant. `--split-per-abi` produces builds
  about a third the size if that matters more than convenience.
- **Demo credentials are in a public repository.** Fine for a review; change them before anything
  else — [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md#before-anyone-else-uses-this) has the procedure.
- **No refresh-token cleanup job.** Expired rows are pruned opportunistically on login, which is
  enough at this scale but is not a substitute for a scheduled sweep.
- **English only.** `intl` formats dates and numbers to the device's locale, but the strings are not
  externalised.

---

## Repository layout

```
├── backend/                  Spring Boot REST API
│   ├── src/main/java/…       controllers · services · entities · security
│   ├── src/main/resources/
│   │   ├── application.yml   local · test · prod, fully env-driven
│   │   └── db/migration/     V1__schema.sql · V2__seed.sql  ← the source of truth
│   ├── src/test/java/…       48 unit + 82 integration tests
│   ├── scripts/smoke.sh      the reviewer journey against any base URL
│   └── Dockerfile            multi-stage, JRE-only, non-root
├── mobile/                   Flutter app
│   ├── lib/core/             network · storage · theme · routing · money
│   ├── lib/features/         auth · invoices · settings
│   ├── test/                 unit · widget · contract
│   └── tool/                 launcher-icon generator
├── database/                 schema.sql · seed.sql · schema_description.md · screenshots/
├── docs/                     API · ERD · DECISIONS · SMOKE_TEST · DEPLOYMENT · PROGRESS · barcodes/
├── release/app-release.apk   signed release build
├── scripts/                  SQL mirror check · schema dump · barcode generator
├── docker-compose.yml        MySQL 8 + the API
└── .github/workflows/ci.yml  SQL mirror · backend · Docker · mobile
```

---

## Licence

MIT. Written by Abdalrahman Bsharat for the Triosuite technical assessment.
