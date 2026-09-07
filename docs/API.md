# REST API

Base path `/api`. JSON in, JSON out.

**Interactive documentation:** `/swagger-ui.html` on any running instance — the fastest way to try
this. Sign in with `POST /api/auth/login`, paste the `accessToken` into **Authorize**, and every
other endpoint becomes callable from the browser.

**Machine-readable spec:** [`openapi.json`](openapi.json), exported from a running instance.

---

## Authentication

Every endpoint requires `Authorization: Bearer <accessToken>` except these four:

| Anonymous | Why |
|---|---|
| `POST /api/auth/login` | you have no token yet |
| `POST /api/auth/refresh` | the access token is the thing that expired |
| `GET /actuator/health` | the hosting platform's probe, and the app's start-up check |
| `/swagger-ui.html`, `/v3/api-docs` | the documentation |

Everything else is default-deny: an unmatched or unauthenticated request gets `401`, never a
partially-served response.

**Access tokens** are HS256 JWTs valid for 30 minutes, carrying `iss`, `sub` (the account id),
`iat`, `exp` and a `role` claim. They are stateless — no database read authorises an ordinary
request.

**Refresh tokens** are 256 bits of `SecureRandom`, valid for 30 days, and stored server-side only as
a SHA-256 digest. They are **single-use**: `POST /api/auth/refresh` revokes the token presented and
returns a new pair. Presenting a revoked, expired or unknown one is `401`.

---

## Endpoints

### Authentication

| Method | Path | Role | Description |
|---|---|---|---|
| `POST` | `/api/auth/login` | anonymous | Exchange credentials for a token pair. Rate limited — see below. |
| `POST` | `/api/auth/refresh` | anonymous | Rotate a refresh token for a new pair. |
| `POST` | `/api/auth/logout` | any | Revoke a refresh token. Idempotent; always `204`. |
| `GET` | `/api/auth/me` | any | The signed-in account. |

```console
$ curl -sS -X POST http://localhost:8080/api/auth/login \
       -H 'Content-Type: application/json' \
       -d '{"username":"admin","password":"Admin#2026"}'
```
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiJ9…",
  "refreshToken": "JTnMVSRbtnW8B8I3qb-iHGMvdktL_cLCFFbxPz4H1CU",
  "expiresInSeconds": 1800,
  "user": { "id": 1, "username": "admin", "fullName": "System Administrator", "role": "ADMIN" }
}
```

### Reference data

| Method | Path | Role | Description |
|---|---|---|---|
| `GET` | `/api/currencies` | any | Active currencies, with symbol and **minor units**. |
| `GET` | `/api/exchange-rates` | any | The rate suggested for each currency on a new invoice. |
| `PUT` | `/api/exchange-rates/{code}` | **ADMIN** | Set one currency's suggested rate. |
| `GET` | `/api/customers` | any | Active customers. `?search=&page=&size=` |
| `GET` | `/api/items` | any | Active catalogue items. `?search=&page=&size=` |
| `GET` | `/api/items/by-barcode/{barcode}` | any | Exact barcode lookup, or `404`. |
| `GET` | `/api/settings` | any | Company-wide defaults. |
| `PUT` | `/api/settings` | **ADMIN** | Replace them. |

`minorUnits` matters: it is 3 for JOD and 2 for the rest, and it is what both the server and the
app round to. A client that assumed two decimals everywhere would disagree with the server on every
JOD invoice.

### Invoices

| Method | Path | Role | Description |
|---|---|---|---|
| `GET` | `/api/invoices` | any | Paginated summaries. `?status=&search=&page=&size=&sort=` |
| `POST` | `/api/invoices` | ADMIN, SALES | Create a DRAFT. `201` + `Location`. |
| `GET` | `/api/invoices/{id}` | any | Full detail: lines, totals, audit trail. |
| `PUT` | `/api/invoices/{id}` | ADMIN, SALES | Replace a DRAFT's header and lines. |
| `POST` | `/api/invoices/{id}/approve` | ADMIN, SALES | DRAFT → APPROVED. |
| `POST` | `/api/invoices/{id}/cancel` | **ADMIN** | DRAFT \| APPROVED → CANCELLED. |

**There is no `DELETE`.** An invoice that should not stand is cancelled, which keeps the record, its
lines, its totals and its audit trail, and leaves it visible in the list under the Cancelled filter.

`sort` accepts `issueDate`, `invoiceNumber`, `grandTotal` and `status`, each with `,asc` or `,desc`.
An unknown property is a `400`, not a `500`.

---

## Roles

| | SALES | ADMIN |
|---|---|---|
| Read anything | ✅ | ✅ |
| Create and edit drafts | ✅ | ✅ |
| Approve | ✅ | ✅ |
| Cancel | ❌ `403` | ✅ |
| Change settings | ❌ `403` | ✅ |
| Change exchange rates | ❌ `403` | ✅ |

Enforced by `@PreAuthorize` on the controller methods, so the check happens on the server whatever
the client believes. The app hides the buttons a role cannot use, which is convenience only.

---

## The invoice lifecycle

```
DRAFT ──approve──▶ APPROVED ──cancel──▶ CANCELLED
  │                                         ▲
  └──────────────────cancel──────────────────┘
```

- **Editable in DRAFT only.** A `PUT` against an APPROVED or CANCELLED invoice is
  `409 INVOICE_NOT_EDITABLE`.
- **Approve** needs at least one line. Approving anything that is not a DRAFT is
  `409 INVALID_TRANSITION`.
- **Cancel** takes an optional reason and stamps who and when. Cancelling a cancelled invoice is
  `409 INVALID_TRANSITION`.
- `CANCELLED` is terminal.

### Optimistic locking

Every invoice response carries `version`, and every mutating call must send it back. The server
compares it **before** doing any work; a mismatch is `409 STALE_VERSION` and nothing is written. The
version check runs before the state-machine check, so a caller working from a stale copy is told to
reload rather than given an explanation of a state they have not seen.

---

## Numbering

`INV-YYYY-000001` — prefix from settings, the year of the issue date, and a six-digit counter that
restarts each year.

**The client never sends a number.** One is allocated by the server inside the same transaction as
the insert, under a `SELECT … FOR UPDATE` lock on the matching `invoice_sequences` row. Concurrent
creates therefore queue for the microsecond that takes and receive distinct, sequential numbers —
asserted by `InvoiceNumberingConcurrencyIT`, which runs twelve creates in parallel. A number sent in
a request body is ignored.

---

## Money

| | |
|---|---|
| Amounts | `DECIMAL(19,4)` |
| Exchange rates | `DECIMAL(19,6)` |
| Tax rates | `DECIMAL(5,4)` — `0.1600` is 16% |
| Quantities | `DECIMAL(12,3)` |

`BigDecimal` server-side, `Decimal` in the app. No monetary value passes through a `double` on
either side.

**Rounding** is `HALF_UP`, applied **per line**, to the invoice currency's minor units. Invoice
totals are the sum of the already-rounded lines, never a re-rounding of an unrounded sum — so
`Σ lines == invoice total` exactly.

**Tax modes**, with `q` = quantity, `p` = unit price, `r` = tax rate:

| Mode | Formulas |
|---|---|
| `EXCLUSIVE` | `net = round(q·p)`, `tax = round(net·r)`, `gross = net + tax` |
| `INCLUSIVE` | `gross = round(q·p)`, `net = round(gross / (1 + r))`, `tax = gross − net` |

**Exchange rate** is how many base-currency units one invoice-currency unit is worth: an invoice in
USD with base JOD carries `0.708738`. It is supplied per invoice, snapshotted at save time and never
re-read, so maintaining a new rate cannot change a document already issued. An invoice in the base
currency is pinned to exactly `1`. Every invoice reports `grandTotalBase` alongside its own total.

**The server never trusts totals sent by a client.** It recomputes every line and every total from
the lines on each write, and a line's tax rate comes from the catalogue item rather than the
request — a client that could name its own rate could invoice at 0% tax.

---

## Requests and responses

### Creating an invoice

```console
$ curl -sS -X POST http://localhost:8080/api/invoices \
       -H "Authorization: Bearer $TOKEN" \
       -H 'Content-Type: application/json' -d @create.json
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

Notice what a line does **not** carry: no tax rate and no amounts. Both are the server's to decide.

The response is the full invoice with `201 Created` and a `Location` header — see
[`SMOKE_TEST.md`](SMOKE_TEST.md#3-create-a-jod-invoice--a-three-decimal-currency-with-mixed-tax-rates)
for the body and a walk through its figures.

### Pagination

Every list endpoint returns the same envelope:

```json
{ "content": [ … ], "page": 0, "size": 20, "totalElements": 42, "totalPages": 3 }
```

`size` defaults to 20 and is capped at 100 — a larger request is quietly reduced rather than
refused.

### Timestamps

Stored as `DATETIME(6)` in UTC and serialised as ISO-8601 with a trailing `Z`
(`2026-09-06T14:45:47.776766Z`). `issueDate` is a plain calendar date (`2026-09-06`) with no time
and no zone, because that is what it is. The app formats both to the device's locale.

---

## Errors

Every error is an RFC 9457 problem document, `Content-Type: application/problem+json`:

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

**Branch on `code`, never on `detail`.** The code is part of the contract; the message is written
for a human and is free to be reworded.

<a id="validation_error"></a>
<a id="not_found"></a>
<a id="unauthorized"></a>
<a id="forbidden"></a>
<a id="invoice_not_editable"></a>
<a id="invalid_transition"></a>
<a id="stale_version"></a>
<a id="rate_limited"></a>
<a id="internal_error"></a>

| `code` | HTTP | When | What the client should do |
|---|---|---|---|
| `VALIDATION_ERROR` | 400 | A rejected field, malformed JSON, an inactive customer, currency or item, an unsortable property | Fix the input. Field-level failures also carry `errors` (below). |
| `UNAUTHORIZED` | 401 | No token, a bad or expired one, wrong credentials, a spent refresh token | Refresh, then sign in again. |
| `FORBIDDEN` | 403 | The role does not permit the operation | Nothing — this is not retryable. |
| `NOT_FOUND` | 404 | No such invoice, currency, or barcode | For a barcode this is routine: report it and keep scanning. |
| `INVOICE_NOT_EDITABLE` | 409 | A write against a non-DRAFT invoice | Reload; the invoice has moved on. |
| `INVALID_TRANSITION` | 409 | Approving a non-draft, or cancelling a cancelled invoice | Reload. |
| `STALE_VERSION` | 409 | The `version` sent does not match the stored one | Reload and let the user re-apply their change. |
| `RATE_LIMITED` | 429 | Too many failed logins | Wait for `Retry-After` seconds. |
| `INTERNAL_ERROR` | 500 | Anything unforeseen | Retry once, then report it. |

Validation failures list every rejected field:

```json
{
  "status": 400,
  "code": "VALIDATION_ERROR",
  "detail": "The request contains 5 invalid fields",
  "errors": [
    { "field": "currencyCode",         "message": "size must be between 3 and 3" },
    { "field": "customerId",           "message": "must not be null" },
    { "field": "exchangeRate",         "message": "must be greater than 0" },
    { "field": "lines[0].quantity",    "message": "must be greater than 0" },
    { "field": "lines[0].unitPrice",   "message": "must not be negative" }
  ]
}
```

**Nothing leaks.** No stack trace, no SQL, no internal class name ever reaches a client — a
constraint violation the application did not anticipate is logged in full and reported as a generic
conflict. `ApiSecurityIT.errorsDoNotLeakInternals` asserts it.

---

## Rate limiting

`POST /api/auth/login` allows **5 failed attempts per minute**, counted separately per username and
per client IP. Either counter tripping returns `429` with a `Retry-After` header in seconds.

Counting both matters: the username counter stops one account being ground through a wordlist, and
the IP counter stops one password being sprayed across every account. A successful login clears the
username's counter but deliberately not the address's — holding one valid credential should not
restore the allowance for everything else being tried from the same place.

---

## Trying it

```bash
# The whole reviewer journey, against any deployment
backend/scripts/smoke.sh                                    # localhost:8080
backend/scripts/smoke.sh https://your-service.onrender.com
```

`backend/scripts/smoke.sh` walks login → list → create a tax-inclusive USD invoice containing an
item found by barcode → approve → be refused an edit → cancel → confirm the record survives, and
exits non-zero at the first step that misbehaves. A recorded run is in
[`SMOKE_TEST.md`](SMOKE_TEST.md).
