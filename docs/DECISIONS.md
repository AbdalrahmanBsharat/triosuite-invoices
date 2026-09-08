# Architecture Decision Records

Short ADR-style entries for every non-obvious decision taken while building this project.
Newest at the bottom.

---

## ADR-0001 — Spring Boot 4.1.1 on Java 21

**Context.** The brief requires "latest stable GA Spring Boot, no milestones/snapshots".
`https://start.spring.io/metadata/client` reports the current default as **4.1.1** (GA), with
`4.2.0-M1` and several `-SNAPSHOT` lines available but excluded by the brief.

**Decision.** Use Spring Boot **4.1.1** with Java 21 (LTS) and the Maven wrapper.

**Consequences.**
- Spring Boot 4 renamed `spring-boot-starter-web` → `spring-boot-starter-webmvc` and split the old
  `spring-boot-starter-test` into per-slice test starters (`spring-boot-starter-webmvc-test`,
  `-data-jpa-test`, `-security-test`, …). The POM reflects the new names; the brief's starter list is
  satisfied by their current equivalents.
- Spring Framework 7 / Spring Security 7 / Hibernate 7 come with it. Security config uses the
  mandatory lambda DSL.
- `springdoc-openapi` **3.1.0** is the line that supports Spring Boot 4 (the `2.x` line targets Boot 3).
- Maven itself is not installed on the build machine; the wrapper (`backend/mvnw`) is the only
  supported entry point and is committed, as the brief requires.

---

## ADR-0002 — Integration tests run against a local MySQL 8.4, not Testcontainers

**Context.** The brief asks for Testcontainers-backed integration tests, with an explicit fallback:
"If Docker is not available on this machine, point a test profile at the local MySQL instead — never
fall back to H2, the DDL is MySQL-specific." Docker Desktop on this machine cannot start its Linux
engine because hardware virtualization is disabled in firmware, so WSL2 is unavailable
(`wsl --status` → *"WSL2 is unable to start since virtualization is not enabled on this machine"*).

**Decision.** Integration tests run against a **real MySQL 8.4.9** server. A dedicated instance is
started from the already-installed MySQL binaries on **port 3307** with its own data directory
(`%LOCALAPPDATA%\triosuite-mysql`), leaving the developer's existing `MySQL84` service on 3306
untouched. The Spring `test` profile targets database `triosuite_test` on that instance; every
connection detail is overridable through environment variables so the same test suite runs unchanged
against the MySQL **service container** in GitHub Actions CI.

**Consequences.**
- No H2. The DDL keeps its MySQL-specific features (`CHECK` constraints, `DATETIME(6)`, InnoDB,
  `utf8mb4`, `SELECT … FOR UPDATE`).
- Running the suite requires a reachable MySQL. The `test` profile document in
  `backend/src/main/resources/application.yml` holds the defaults, and every one of them is
  overridable by an environment variable, which is how CI points the same suite at its service
  container.
- Flyway migrates the test schema before each run, and the schema is dropped and recreated so runs are
  reproducible.
- `Dockerfile` and `docker-compose.yml` are still delivered and are exercised by CI, but they could not
  be executed on the development machine.

---

## ADR-0003 — Money, rounding and the units of the exchange rate

**Context.** Money must never be a binary float, and the rounding rule has to be identical on the
server (source of truth) and in the app (live preview) or the two will disagree by cents.

**Decision.**
- Java uses `BigDecimal` everywhere for amounts, rates, quantities and tax rates; Dart uses the
  `decimal` package. No `double`/`float` touches a monetary value on either side.
- Storage: `DECIMAL(19,4)` amounts, `DECIMAL(19,6)` exchange rates, `DECIMAL(5,4)` tax rates,
  `DECIMAL(12,3)` quantities.
- Rounding is **per line**, `HALF_UP`, to the **invoice currency's** minor units (2 for ILS/USD/EUR/GBP,
  3 for JOD). Invoice totals are the sum of the already-rounded line amounts — never a re-rounding of
  an unrounded sum. This keeps `Σ lines == invoice total` exactly, which is what an auditor checks.
- `exchange_rate` is defined as **how many base-currency units one invoice-currency unit is worth**
  (invoice in USD, base JOD, rate `0.708738` → 1 USD = 0.708738 JOD). `grand_total_base =
  round(grand_total × exchange_rate)` to the **base** currency's minor units.
- For an invoice in the base currency the rate is forced to `1.000000` server-side and locked in the UI.

**Consequences.** Storing amounts at scale 4 while rounding to 2 or 3 keeps room for currencies with
3 minor units and makes the rounding rule explicit rather than implied by the column type. The
`InvoiceCalculator` is pure and stateless so it can be unit-tested without a Spring context, and the
Dart implementation mirrors it line for line.

---

## ADR-0004 — Snapshot columns on invoice lines

**Context.** An approved invoice is a financial record. If it rendered live joins to `items`, a later
price or name change would silently rewrite history.

**Decision.** `invoice_lines` stores `item_name_snapshot`, `barcode_snapshot`, `unit_price` and
`tax_rate` copied at write time, alongside the `item_id` FK (kept for traceability and reporting).
`invoices` likewise snapshots `exchange_rate`.

**Consequences.** Line data is intentionally denormalized. The FK to `items` is `ON DELETE RESTRICT`
so a referenced item can never vanish; items are deactivated (`is_active = 0`), never deleted.

---

## ADR-0005 — Invoice numbering uses a locked sequence row, not `AUTO_INCREMENT`

**Context.** Numbers must be gapless-by-intent, formatted `INV-YYYY-000001`, reset per year, and
allocated by the server inside the same transaction as the insert.

**Decision.** A dedicated `invoice_sequences (prefix, year, next_value)` table. Allocation does
`SELECT … FOR UPDATE` (JPA `PESSIMISTIC_WRITE`) on the matching row, reads `next_value`, increments it,
and formats the number — all inside the invoice-creation transaction. If the row for a new year does
not exist it is inserted, and a concurrent duplicate insert is caught and retried once. The unique
index on `invoices.invoice_number` is the final guard.

**Consequences.** Concurrent creates serialize on one short row lock, which is correct and cheap at
this scale. `AUTO_INCREMENT` was rejected because it is not per-year, leaks gaps on rollback, and
cannot carry the prefix. A dedicated concurrency test asserts that parallel creates receive distinct,
sequential numbers.

---

## ADR-0006 — Optimistic locking is explicit in the API contract

**Context.** The brief requires `version` in every response and on every mutating call.

**Decision.** `invoices.version` is a JPA `@Version` column. Update, approve and cancel all take
`version` in the request body; the service compares it against the loaded entity **before** doing any
work and throws `StaleVersionException` → `409 STALE_VERSION`. Hibernate's own optimistic-lock check
remains as a second line of defence and is mapped to the same problem code.

**Consequences.** The client always knows whether it lost a race, and the check happens before the
state-machine validation so the user gets the most actionable error.

---

## ADR-0007 — Opaque, hashed, single-use refresh tokens

**Context.** JWT refresh tokens cannot be revoked; the brief requires revocation and rotation.

**Decision.** Access token = JWT (HS256, 30 min, `iss`/`sub`/`iat`/`exp` + `role`). Refresh token =
256 bits of `SecureRandom`, base64url-encoded, returned to the client once and stored **only** as a
SHA-256 hash. Refresh rotates: the presented token is marked revoked and a new pair is issued in the
same transaction. Presenting a revoked or expired token fails with `401 UNAUTHORIZED`.

**Consequences.** A database read is needed on refresh (not on ordinary requests, which stay
stateless). SHA-256 rather than BCrypt is deliberate here: the token is 256 bits of full-entropy
random, so the slow-hash property BCrypt buys for human passwords adds latency without adding security,
and the lookup must be an indexed equality match.

---

## ADR-0008 — Login rate limiting is a small in-memory limiter

**Context.** The brief asks for 5 attempts per minute per username and per IP, returning `429` with
`Retry-After`, and suggests Bucket4j "or a small in-memory implementation".

**Decision.** A ~70-line `LoginRateLimiter` using a `ConcurrentHashMap` of fixed windows with periodic
eviction of expired entries. No new dependency.

**Consequences.** Correct for the single-instance deployment this project targets. It resets on
restart and does not coordinate across replicas; both are called out as known limitations in the
README. A shared store (Redis) would be the change needed to scale horizontally.

---

## ADR-0009 — GetX for state, dio for HTTP

**Context.** The brief fixes the package list. `flutter_getx` is not a package on pub.dev; the GetX
package is published as `get`.

**Decision.** Use `get` (GetX) for state management, dependency injection and routing (`GetX`'s
`GetMaterialApp` + named routes covers the five-route constraint without a second routing package).
`dio` handles HTTP with an auth interceptor and `pretty_dio_logger` in debug builds only.

**Consequences.** One package provides state, DI and navigation, which keeps the dependency list at
exactly what the brief names. Controllers are `GetxController`s with explicit `Rx` state; no
`setState` in feature code.

---

## ADR-0010 — Exactly five routes; everything else is a sheet or dialog

**Context.** "The app should not exceed five screens" is an assessment requirement, and reviewers
count routes.

**Decision.** `GetPage` entries exist for exactly `/login`, `/invoices`, `/invoices/new`,
`/invoices/:id` and `/settings`. `/invoices/new` doubles as the edit screen via an `invoiceId`
argument. The barcode scanner, item picker, customer picker, cancel-reason prompt and all
confirmations are `showModalBottomSheet` / `showDialog` calls inside those pages. The startup
connectivity check is an overlay on the first route, not a route of its own.

**Consequences.** Route count is trivially verifiable in `lib/core/routing/app_pages.dart`.

---

## ADR-0011 — Catalogue prices are converted into the invoice's currency when an item is added

**Context.** The catalogue prices every item in one currency (JOD in the seed), but an invoice may
be issued in any of five. Dropping the raw catalogue figure onto a USD invoice would produce a
document that is silently wrong by a factor of the exchange rate — and it would be wrong in the
direction that overcharges the customer.

**Decision.** When an item is added — by picker or by scanner — the app converts its catalogue price
into the invoice's currency, via the base currency, at the invoice's own exchange rate:

```
priceInInvoiceCurrency = round(catalogue price × rate(item currency) ÷ invoice exchange rate)
```

rounded to the invoice currency's minor units. Changing the invoice's currency, or its rate,
re-prices every existing line the same way. The unit price stays fully editable afterwards, because
a negotiated price is a fact about the deal rather than about the catalogue.

**Consequences.** The line's `unitPrice` is what the app sends and what the server stores and
snapshots; the conversion is a convenience at data-entry time, not a rule the server enforces. The
seeded foreign-currency invoices were priced by exactly this formula, so the demo data and the app
agree. Going via the base currency rather than dividing directly means the calculation is still
correct if an item is ever priced in something other than the base currency.

---

## ADR-0012 — `flutter_secure_storage` is held at 10.x

**Context.** `flutter_secure_storage` 11.0.0 is the current release, and it is what the dependency
resolver picks. Its Android module hard-codes `compileSdk = 37`, and the Android SDK manager
publishes no `platforms;android-37` package — only `platforms;android-37.0`, a minor-versioned
release. Gradle resolves the plugin's request to the literal string `android-37`, finds nothing, and
the build dies with `Failed to find target with hash string 'android-37'`. No configuration in this
repository can fix it: the constraint lives inside the dependency.

**Decision.** Pin to `^10.3.1`, which compiles against SDK 36 and needs `minSdk 23` — the same
floor `mobile_scanner` 7 requires, so nothing else moves.

**Consequences.** The API this project uses is unchanged: `AndroidOptions(storageNamespace: …)`
exists in both lines, and 10.x already stores through the Android Keystore with an AES-GCM data key
wrapped by RSA, which is exactly what 11 does. `flutter pub outdated` will keep reporting 11.0.0 as
available; the comment in `pubspec.yaml` says why it is not taken. The pin can be lifted as soon as
either the plugin declares `compileSdkMinor` or an `android-37` platform package is published.

---

## ADR-0013 — Amounts cross the wire as JSON numbers and are parsed through their decimal text

**Context.** Money must not pass through a binary float, and `dart:convert` has no arbitrary-
precision number type: by the time a response is decoded, `10443.2500` is already a Dart `double`.

**Decision.** The API keeps sending amounts as JSON numbers, and `DecimalConverter` builds a
`Decimal` from the number's **shortest round-tripping decimal representation** rather than from its
binary value. Dart guarantees `double.toString()` produces a string that parses back to the same
double, which for a value of at most 15 significant digits is exactly the decimal the server sent.
Every amount here is `DECIMAL(19,4)` at invoice magnitudes, so that holds with several orders of
magnitude to spare. In the other direction the app sends decimals as **strings**, so nothing the
user typed is ever routed through a float on its way to the server.

**Consequences.** No precision is lost in practice, and the API stays readable and arithmetic-
friendly for anyone poking at it with `curl` and `jq` — the smoke script adds line amounts in `jq`
to check that net + tax equals gross, which strings would make impossible. The stricter alternative,
serialising `BigDecimal` as a JSON string, is the right move if amounts ever exceed 15 significant
digits; it is noted here so the reason for not doing it now is on the record rather than assumed.

---

## ADR-0014 — The release build permits cleartext HTTP, because there is no hosted backend

**Context.** Earlier builds were HTTPS-only: `usesCleartextTraffic="false"` and a network security
config with no cleartext exception. That was correct while the plan was to deploy the API behind
TLS, with the app talking to one known origin.

The plan changed. There is no hosted backend: every reviewer runs the API on their own machine and
points the app at it — an emulator at `10.0.2.2`, a USB tunnel at `localhost`, or a phone on the
same Wi-Fi using the PC's LAN address. With an HTTPS-only build none of those work, and the APK
that is a required deliverable cannot reach a server at all. That was verified against the shipped
APK, not assumed: `aapt2 dump xmltree` on `release/app-release.apk` showed
`cleartextTrafficPermitted=false` with no `<domain-config>`.

The tighter fix does not exist. A network security config matches **domain names, not address
ranges**, so `10.0.2.2` and `localhost` can be allowed individually but "any private address on
whatever network this phone joins" cannot be expressed. The LAN case is the main one, so the
permission has to be broad enough to cover it.

**Decision.** `cleartextTrafficPermitted="true"` in the release network security config, and
`android:usesCleartextTraffic="true"` in the manifest. The manifest attribute is ignored from API 24
up, but this app supports API 23, which predates the config format — the two are kept in step so
behaviour is the same across every supported version. Trust anchors in release stay `system` only:
the debug variant additionally trusts user-installed CAs for proxy inspection, and that difference
is preserved.

**Consequences.** The single committed APK works for all three local setups with no rebuild, which
is what makes "download the APK, run the backend, type an address" a real path. The cost is that a
bearer token would travel in the clear if the app were ever pointed at a remote plain-HTTP server —
acceptable here, where the server is on the reviewer's own machine or LAN and holds demo data. This
is a deliberate reversal of the original HTTPS-only rule, which existed to protect an internet-
facing deployment that no longer exists.

Reverting is two attributes: set both flags back to `false`. `docs/DEPLOYMENT.md` still documents
the hosted route in full, and step 5 there is the rebuild that would go with it.
