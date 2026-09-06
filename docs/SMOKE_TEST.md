# End-to-end smoke test

A recorded run of the complete reviewer journey against a running API:
**log in → list → create a tax-inclusive USD invoice containing an item found by barcode →
approve → be refused an edit → cancel → confirm the record still exists.**

The run below was executed on **2026-09-06** against `http://localhost:8080` — the backend
started from `backend/target/triosuite-invoices-api-1.0.0.jar` with `SPRING_PROFILES_ACTIVE=local`,
against MySQL 8.4.9 freshly migrated and seeded by Flyway.

Reproduce it with:

```bash
backend/scripts/smoke.sh                                    # defaults to http://localhost:8080
backend/scripts/smoke.sh https://<service>.onrender.com     # or any deployment
```

The script needs `bash`, `curl` and `jq`. It exits non-zero at the first step that misbehaves, so
it is equally usable as a post-deploy gate.

---

## Recorded run

```
Triosuite Invoices — smoke test
Target: http://localhost:8080

[01] Health — waiting for the API (free tiers can take ~60 s to wake)
     ✓ GET /actuator/health
     ✓ health reports UP

[02] Authentication is required by default
     ✓ GET /api/invoices without a token is 401
     ✓ the problem document carries code UNAUTHORIZED

[03] Login
     ✓ POST /api/auth/login as admin
     ✓ the account is an administrator
     ✓ an access token was issued
     ✓ POST /api/auth/login as sales
     ✓ a wrong password is refused

[04] Reference data
     ✓ GET /api/settings
     · base currency is ILS
     ✓ GET /api/currencies
     · EUR, GBP, ILS, JOD, USD
     ✓ GET /api/exchange-rates
     · USD is quoted at 3.650000 ILS
     ✓ GET /api/customers
     · billing Al-Quds Trading Co. (id 1)

[05] Invoice list
     ✓ GET /api/invoices
     · 6 invoice(s), 2 page(s)
     ✓ filtering by DRAFT works
     ✓ filtering by APPROVED works
     ✓ filtering by CANCELLED works

[06] Barcode lookup
     ✓ GET /api/items/by-barcode/7290001000045
     · scanned 27" 4K Monitor at 1899.0000 ILS
     ✓ an unknown barcode is 404
     ✓ the problem document carries code NOT_FOUND

[07] Create a tax-inclusive USD invoice
     ✓ POST /api/invoices returns 201
     ✓ the new invoice is a DRAFT
     ✓ the tax mode was stored
     ✓ the exchange rate was snapshotted
     ✓ the server allocated INV-2026-000007
     ✓ line arithmetic balances
     ✓ invoice totals balance
     · total 1560.81 USD = 5696.96 ILS

[08] The number is allocated by the server, not the client
     ✓ a second invoice is created
     ✓ INV-2026-000007 then INV-2026-000008 — sequential and distinct
     ✓ the spare draft is cancelled

[09] Optimistic locking
     ✓ approving with a stale version is 409
     ✓ the problem document carries code STALE_VERSION

[10] Approve
     ✓ POST /api/invoices/7/approve
     ✓ the invoice is APPROVED
     · approved by System Administrator at 2026-09-06T14:45:47.776766200Z

[11] An approved invoice is locked
     ✓ editing an approved invoice is 409
     ✓ the problem document carries code INVOICE_NOT_EDITABLE
     ✓ approving it twice is 409
     ✓ the problem document carries code INVALID_TRANSITION

[12] Roles
     ✓ SALES may read invoices
     ✓ SALES may not cancel
     ✓ the problem document carries code FORBIDDEN

[13] Cancel — the record must survive
     ✓ POST /api/invoices/7/cancel as ADMIN
     ✓ the invoice is CANCELLED
     ✓ the reason was recorded
     ✓ the cancelled invoice is still readable
     ✓ it kept its number
     ✓ its lines and totals are intact
     ✓ the approval stamp survived the cancellation
     ✓ it still appears under the Cancelled filter

[14] Sign out
     ✓ POST /api/auth/logout
     ✓ the revoked refresh token no longer works

All checks passed against http://localhost:8080
```

---

## Selected request and response pairs

Access and refresh tokens are redacted below; everything else is verbatim.

### 1. Login

```console
$ curl -sS -X POST http://localhost:8080/api/auth/login \
       -H "Content-Type: application/json" \
       -d '{"username":"admin","password":"Admin#2026"}'
```
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiJ9.<redacted>",
  "refreshToken": "<redacted>",
  "expiresInSeconds": 1800,
  "user": {
    "id": 1,
    "username": "admin",
    "fullName": "System Administrator",
    "role": "ADMIN"
  }
}
```

### 2. Invoice list, filtered and paginated

```console
$ curl -sS "http://localhost:8080/api/invoices?status=APPROVED&size=3" \
       -H "Authorization: Bearer $TOKEN"
```
```json
{
  "content": [
    {
      "id": 2,
      "invoiceNumber": "INV-2026-000002",
      "customerName": "Bethlehem Electronics",
      "issueDate": "2026-03-19",
      "currencyCode": "USD",
      "currencySymbol": "$",
      "grandTotal": 2176.8300,
      "grandTotalBase": 7945.4300,
      "status": "APPROVED"
    },
    {
      "id": 1,
      "invoiceNumber": "INV-2026-000001",
      "customerName": "Al-Quds Trading Co.",
      "issueDate": "2026-02-11",
      "currencyCode": "ILS",
      "currencySymbol": "₪",
      "grandTotal": 10443.2500,
      "grandTotalBase": 10443.2500,
      "status": "APPROVED"
    }
  ],
  "page": 0,
  "size": 3,
  "totalElements": 2,
  "totalPages": 1
}
```

### 3. Create a JOD invoice — a three-decimal currency with mixed tax rates

This one is worth reading closely. JOD carries **three** minor units, the base currency ILS carries
two, and the second line is zero-rated. Every figure below was computed by the server.

```console
$ curl -sS -X POST http://localhost:8080/api/invoices \
       -H "Authorization: Bearer $TOKEN" \
       -H "Content-Type: application/json" -d @create.json
```
```json
{
  "customerId": 2,
  "currencyCode": "JOD",
  "exchangeRate": "5.150000",
  "taxMode": "EXCLUSIVE",
  "issueDate": "2026-09-06",
  "notes": "Three-decimal currency demonstration",
  "lines": [
    { "itemId": 9,  "quantity": "6.000", "unitPrice": "223.3010" },
    { "itemId": 13, "quantity": "1.000", "unitPrice": "349.5150" }
  ]
}
```

Response — `201 Created`, `Location: /api/invoices/9`:

```json
{
  "id": 9,
  "invoiceNumber": "INV-2026-000009",
  "status": "DRAFT",
  "version": 0,
  "customerId": 2,
  "customerName": "Bethlehem Electronics",
  "currencyCode": "JOD",
  "currencySymbol": "JD",
  "currencyMinorUnits": 3,
  "exchangeRate": 5.150000,
  "baseCurrencyCode": "ILS",
  "taxMode": "EXCLUSIVE",
  "issueDate": "2026-09-06",
  "notes": "Three-decimal currency demonstration",
  "subtotal": 1689.321,
  "taxTotal": 214.369,
  "grandTotal": 1903.690,
  "grandTotalBase": 9804.00,
  "lines": [
    {
      "id": 17, "lineNo": 1, "itemId": 9,
      "itemName": "Ergonomic Office Chair", "barcode": "7290001000090",
      "quantity": 6.000, "unitPrice": 223.3010, "taxRate": 0.1600,
      "netAmount": 1339.806, "taxAmount": 214.369, "grossAmount": 1554.175
    },
    {
      "id": 18, "lineNo": 2, "itemId": 13,
      "itemName": "Annual Software Licence", "barcode": "7290001000137",
      "quantity": 1.000, "unitPrice": 349.5150, "taxRate": 0.0000,
      "netAmount": 349.515, "taxAmount": 0.000, "grossAmount": 349.515
    }
  ],
  "createdBy": "System Administrator",
  "createdAt": "2026-09-06T14:46:23.724526100Z",
  "updatedAt": "2026-09-06T14:46:23.724526100Z"
}
```

What to check:

- **Three decimals are preserved.** `6 × 223.301 = 1339.806`; tax `1339.806 × 0.16 = 214.36896`
  rounds HALF_UP to `214.369`. Nothing was truncated to two places.
- **The second line is zero-rated**, and its tax rate came from the catalogue, not the request.
- **Totals are the sum of the rounded lines.** `1339.806 + 349.515 = 1689.321`, and
  `1689.321 + 214.369 = 1903.690` — the grand total exactly.
- **The base conversion rounds to the base currency's scale**, not the invoice's:
  `1903.690 × 5.15 = 9804.0035 → 9804.00`.

### 4. Editing an approved invoice is refused

```console
$ curl -sS -i -X PUT http://localhost:8080/api/invoices/1 \
       -H "Authorization: Bearer $TOKEN" \
       -H "Content-Type: application/json" -d @edit.json
```
```http
HTTP/1.1 409
Content-Type: application/problem+json
```
```json
{
  "type": "https://github.com/AbdalrahmanBsharat/triosuite-invoices/blob/main/docs/API.md#invoice_not_editable",
  "title": "Invoice is not editable",
  "status": 409,
  "detail": "Invoice INV-2026-000001 is APPROVED and can no longer be edited",
  "instance": "/api/invoices/1",
  "code": "INVOICE_NOT_EDITABLE"
}
```

### 5. A SALES user may not cancel

```console
$ curl -sS -i -X POST http://localhost:8080/api/invoices/3/cancel \
       -H "Authorization: Bearer $SALES_TOKEN" \
       -H "Content-Type: application/json" -d '{"version":0}'
```
```http
HTTP/1.1 403
Content-Type: application/problem+json
```
```json
{
  "type": "https://github.com/AbdalrahmanBsharat/triosuite-invoices/blob/main/docs/API.md#forbidden",
  "title": "Access denied",
  "status": 403,
  "detail": "Your role does not permit this operation",
  "instance": "/api/invoices/3/cancel",
  "code": "FORBIDDEN"
}
```

### 6. Login rate limiting

```console
$ for i in 1 2 3 4 5 6; do
    curl -sS -o /dev/null \
         -w "attempt $i -> %{http_code} Retry-After=%header{retry-after}\n" \
         -X POST http://localhost:8080/api/auth/login \
         -H "Content-Type: application/json" \
         -d '{"username":"probe","password":"wrong"}'
  done

attempt 1 -> 401 Retry-After=
attempt 2 -> 401 Retry-After=
attempt 3 -> 401 Retry-After=
attempt 4 -> 401 Retry-After=
attempt 5 -> 401 Retry-After=
attempt 6 -> 429 Retry-After=58
```

The sixth response body:

```json
{
  "type": "https://github.com/AbdalrahmanBsharat/triosuite-invoices/blob/main/docs/API.md#rate_limited",
  "title": "Too many requests",
  "status": 429,
  "detail": "Too many login attempts. Try again in 58 seconds.",
  "instance": "/api/auth/login",
  "code": "RATE_LIMITED"
}
```

---

## Defects this exercise found, and their fixes

Running the journey for real — rather than trusting the unit tests — turned up three genuine bugs.
All three are fixed, and each now has a regression test.

| Symptom | Root cause | Fix |
|---|---|---|
| `PUT /api/invoices/{id}` on a draft returned `400`, complaining about existing data | `uk_invoice_lines_invoice_line_no` was violated: clearing and re-adding the line collection made Hibernate insert the new line 1 before deleting the old one | `Invoice.replaceLines` rewrites rows in place and trims only the surplus tail (`InvoiceLifecycleIT.draftCanBeUpdated`) |
| The first invoice of a new year hung for 50 s, then `500` | `SELECT … FOR UPDATE` on a row that does not exist takes an InnoDB **gap lock**, which then blocked the insert that had to create that very row | Existence is checked without a lock before the locking read (`InvoiceLifecycleIT.sequenceRestartsPerYear`) |
| Two concurrent creates were handed `INV-2026-000007` | The existence check above was first written as `findById`, which put the entity in the persistence context — so the `FOR UPDATE` read returned that stale instance rather than the locked row | The check is a scalar `COUNT`, which cannot load the entity (`InvoiceNumberingConcurrencyIT`) |

A `@PreAuthorize` denial was also being reported as `500 INTERNAL_ERROR` rather than `403 FORBIDDEN`,
because method security throws inside the controller where the catch-all advice saw it first. An
explicit `AccessDeniedException` handler fixes it, covered by `ApiSecurityIT.salesMayNotCancel`.

---

## Automated coverage

`./mvnw verify` runs the whole suite: **48 unit tests** (no Spring context) and **79 integration
tests** against a real MySQL 8.

```
[INFO] Tests run: 48, Failures: 0, Errors: 0, Skipped: 0     <- surefire  (*Test)
[INFO] Tests run: 79, Failures: 0, Errors: 0, Skipped: 0     <- failsafe  (*IT)
[INFO] BUILD SUCCESS
```

| Suite | What it covers |
|---|---|
| `InvoiceCalculatorTest` | 30 pure tests: both tax modes, 2- and 3-decimal currencies, exact-half rounding, zero tax, fractional quantities, per-line rounding drift, `net + tax = gross`, base conversion |
| `InvoiceStatusTest` | the state machine as a closed table |
| `LoginRateLimiterTest` | windows, expiry, per-username and per-IP scoping |
| `AuthIT` | login, wrong password, unknown username, `/me`, refresh rotation, single-use refresh, idempotent logout |
| `LoginRateLimitIT` | 5 failures then `429` + `Retry-After`, and that a correct password is refused too once the allowance is spent |
| `ApiSecurityIT` | anonymous `401` on every protected route, tampered tokens, the SALES/ADMIN split, actuator surface, security headers, no internals in error bodies |
| `InvoiceLifecycleIT` | create, number allocation and per-year reset, update, approve, `INVOICE_NOT_EDITABLE`, `INVALID_TRANSITION`, `STALE_VERSION`, cancel, and that no DELETE endpoint exists |
| `InvoiceCalculationIT` | both tax modes and JOD through the API, user-supplied rates, client totals ignored, tax rate taken from the catalogue, line snapshots |
| `InvoiceNumberingConcurrencyIT` | twelve parallel creates receive distinct, gapless, sequential numbers |
| `SeededInvoiceTotalsIT` | every seeded invoice re-derived with the production calculator; every seeded EAN-13 check digit verified |
| `CatalogIT` | barcode found and not found, item and customer search, inactive customers excluded, pagination and its cap |
