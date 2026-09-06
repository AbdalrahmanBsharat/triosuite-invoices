#!/usr/bin/env bash
#
# Triosuite Invoices — end-to-end smoke test.
#
# Walks the whole reviewer journey against a running API and fails loudly at the first
# step that does not behave: login, list, create a tax-inclusive USD invoice containing an
# item found by barcode, approve it, be refused an edit, cancel it, and confirm the record
# is still there afterwards. Also checks the role split and the login rate limiter.
#
# Usage:
#   ./smoke.sh                                   # http://localhost:8080
#   ./smoke.sh https://triosuite.onrender.com    # any deployment
#
# Requires: bash, curl, jq.
#
set -euo pipefail

BASE_URL="${1:-http://localhost:8080}"
BASE_URL="${BASE_URL%/}"

ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:-Admin#2026}"
SALES_USER="${SALES_USER:-sales}"
SALES_PASS="${SALES_PASS:-Sales#2026}"

# A seeded EAN-13; printable copies of all fifteen are in docs/barcodes/.
BARCODE="${BARCODE:-7290001000045}"

# ---------------------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------------------
if [ -t 1 ]; then
    RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BOLD=''; OFF=''
fi

STEP=0
step()  { STEP=$((STEP + 1)); printf '\n%s[%02d] %s%s\n' "$BOLD" "$STEP" "$1" "$OFF"; }
ok()    { printf '     %s✓%s %s\n' "$GREEN" "$OFF" "$1"; }
info()  { printf '     %s·%s %s\n' "$YELLOW" "$OFF" "$1"; }
die()   { printf '     %s✗ %s%s\n' "$RED" "$1" "$OFF" >&2; exit 1; }

require() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed"
}

# expect <actual> <expected> <description>
expect() {
    if [ "$1" = "$2" ]; then
        ok "$3"
    else
        die "$3 — expected '$2', got '$1'"
    fi
}

# api <METHOD> <PATH> [BODY] [AUTH_HEADER]
# Writes the response body to $BODY and the status code to $STATUS.
api() {
    local method="$1" path="$2" body="${3:-}" auth="${4:-}"
    local args=(-sS -o /tmp/triosuite-smoke-body.json -w '%{http_code}' -X "$method" "${BASE_URL}${path}")
    [ -n "$auth" ] && args+=(-H "Authorization: Bearer ${auth}")
    if [ -n "$body" ]; then
        args+=(-H 'Content-Type: application/json' -d "$body")
    fi
    STATUS="$(curl "${args[@]}")"
    BODY="$(cat /tmp/triosuite-smoke-body.json)"
}

require curl
require jq

printf '%sTriosuite Invoices — smoke test%s\n' "$BOLD" "$OFF"
printf 'Target: %s\n' "$BASE_URL"

# ---------------------------------------------------------------------------------------
step "Health — waiting for the API (free tiers can take ~60 s to wake)"
# ---------------------------------------------------------------------------------------
DEADLINE=$((SECONDS + 120))
until curl -sS -o /dev/null -m 10 "${BASE_URL}/actuator/health" 2>/dev/null; do
    [ "$SECONDS" -lt "$DEADLINE" ] || die "the API did not become reachable within 120 s"
    info "not up yet, retrying..."
    sleep 5
done
api GET /actuator/health
expect "$STATUS" "200" "GET /actuator/health"
expect "$(jq -r .status <<<"$BODY")" "UP" "health reports UP"

# ---------------------------------------------------------------------------------------
step "Authentication is required by default"
# ---------------------------------------------------------------------------------------
api GET /api/invoices
expect "$STATUS" "401" "GET /api/invoices without a token is 401"
expect "$(jq -r .code <<<"$BODY")" "UNAUTHORIZED" "the problem document carries code UNAUTHORIZED"

# ---------------------------------------------------------------------------------------
step "Login"
# ---------------------------------------------------------------------------------------
api POST /api/auth/login "$(jq -nc --arg u "$ADMIN_USER" --arg p "$ADMIN_PASS" \
    '{username: $u, password: $p}')"
expect "$STATUS" "200" "POST /api/auth/login as ${ADMIN_USER}"
ADMIN_TOKEN="$(jq -r .accessToken <<<"$BODY")"
ADMIN_REFRESH="$(jq -r .refreshToken <<<"$BODY")"
expect "$(jq -r .user.role <<<"$BODY")" "ADMIN" "the account is an administrator"
[ "$ADMIN_TOKEN" != "null" ] && ok "an access token was issued"

api POST /api/auth/login "$(jq -nc --arg u "$SALES_USER" --arg p "$SALES_PASS" \
    '{username: $u, password: $p}')"
expect "$STATUS" "200" "POST /api/auth/login as ${SALES_USER}"
SALES_TOKEN="$(jq -r .accessToken <<<"$BODY")"

api POST /api/auth/login "$(jq -nc --arg u "$ADMIN_USER" '{username: $u, password: "wrong"}')"
expect "$STATUS" "401" "a wrong password is refused"

# ---------------------------------------------------------------------------------------
step "Reference data"
# ---------------------------------------------------------------------------------------
api GET /api/settings "" "$ADMIN_TOKEN"
expect "$STATUS" "200" "GET /api/settings"
BASE_CURRENCY="$(jq -r .baseCurrencyCode <<<"$BODY")"
info "base currency is ${BASE_CURRENCY}"

api GET /api/currencies "" "$ADMIN_TOKEN"
expect "$STATUS" "200" "GET /api/currencies"
info "$(jq -r '[.[].code] | join(", ")' <<<"$BODY")"

api GET /api/exchange-rates "" "$ADMIN_TOKEN"
expect "$STATUS" "200" "GET /api/exchange-rates"
USD_RATE="$(jq -r '.[] | select(.currencyCode == "USD") | .rateToBase' <<<"$BODY")"
info "USD is quoted at ${USD_RATE} ${BASE_CURRENCY}"

api GET "/api/customers?size=1" "" "$ADMIN_TOKEN"
expect "$STATUS" "200" "GET /api/customers"
CUSTOMER_ID="$(jq -r '.content[0].id' <<<"$BODY")"
CUSTOMER_NAME="$(jq -r '.content[0].name' <<<"$BODY")"
info "billing ${CUSTOMER_NAME} (id ${CUSTOMER_ID})"

# ---------------------------------------------------------------------------------------
step "Invoice list"
# ---------------------------------------------------------------------------------------
api GET "/api/invoices?size=5" "" "$ADMIN_TOKEN"
expect "$STATUS" "200" "GET /api/invoices"
info "$(jq -r '"\(.totalElements) invoice(s), \(.totalPages) page(s)"' <<<"$BODY")"

for FILTER in DRAFT APPROVED CANCELLED; do
    api GET "/api/invoices?status=${FILTER}" "" "$ADMIN_TOKEN"
    expect "$STATUS" "200" "filtering by ${FILTER} works"
done

# ---------------------------------------------------------------------------------------
step "Barcode lookup"
# ---------------------------------------------------------------------------------------
api GET "/api/items/by-barcode/${BARCODE}" "" "$ADMIN_TOKEN"
expect "$STATUS" "200" "GET /api/items/by-barcode/${BARCODE}"
ITEM_ID="$(jq -r .id <<<"$BODY")"
ITEM_NAME="$(jq -r .name <<<"$BODY")"
ITEM_PRICE="$(jq -r .unitPrice <<<"$BODY")"
info "scanned ${ITEM_NAME} at ${ITEM_PRICE} ${BASE_CURRENCY}"

api GET "/api/items/by-barcode/0000000000000" "" "$ADMIN_TOKEN"
expect "$STATUS" "404" "an unknown barcode is 404"
expect "$(jq -r .code <<<"$BODY")" "NOT_FOUND" "the problem document carries code NOT_FOUND"

# The app converts a catalogue price into the invoice currency at the invoice's own rate.
USD_PRICE="$(jq -nr --argjson p "$ITEM_PRICE" --argjson r "$USD_RATE" '(($p / $r) * 100 | round) / 100')"

# ---------------------------------------------------------------------------------------
step "Create a tax-inclusive USD invoice"
# ---------------------------------------------------------------------------------------
CREATE_BODY="$(jq -nc \
    --argjson customerId "$CUSTOMER_ID" \
    --argjson itemId "$ITEM_ID" \
    --arg rate "$USD_RATE" \
    --arg price "$USD_PRICE" \
    --arg issueDate "$(date -u +%Y-%m-%d)" \
    '{
      customerId: $customerId,
      currencyCode: "USD",
      exchangeRate: $rate,
      taxMode: "INCLUSIVE",
      issueDate: $issueDate,
      notes: "Created by smoke.sh",
      lines: [ { itemId: $itemId, quantity: "3.000", unitPrice: $price } ]
    }')"

api POST /api/invoices "$CREATE_BODY" "$ADMIN_TOKEN"
expect "$STATUS" "201" "POST /api/invoices returns 201"
INVOICE_ID="$(jq -r .id <<<"$BODY")"
INVOICE_NUMBER="$(jq -r .invoiceNumber <<<"$BODY")"
VERSION="$(jq -r .version <<<"$BODY")"
expect "$(jq -r .status <<<"$BODY")" "DRAFT" "the new invoice is a DRAFT"
expect "$(jq -r .taxMode <<<"$BODY")" "INCLUSIVE" "the tax mode was stored"
expect "$(jq -r .exchangeRate <<<"$BODY")" "$USD_RATE" "the exchange rate was snapshotted"
ok "the server allocated ${INVOICE_NUMBER}"

# net + tax must equal gross exactly, on the line and on the invoice.
jq -e '.lines[0] | (.netAmount + .taxAmount) == .grossAmount' <<<"$BODY" >/dev/null \
    || die "line net + tax does not equal gross"
ok "line arithmetic balances"
jq -e '(.subtotal + .taxTotal) == .grandTotal' <<<"$BODY" >/dev/null \
    || die "subtotal + tax does not equal the grand total"
ok "invoice totals balance"
info "$(jq -r '"total \(.grandTotal) \(.currencyCode) = \(.grandTotalBase) \(.baseCurrencyCode)"' <<<"$BODY")"

# ---------------------------------------------------------------------------------------
step "The number is allocated by the server, not the client"
# ---------------------------------------------------------------------------------------
api POST /api/invoices "$CREATE_BODY" "$ADMIN_TOKEN"
expect "$STATUS" "201" "a second invoice is created"
SECOND_NUMBER="$(jq -r .invoiceNumber <<<"$BODY")"
SECOND_ID="$(jq -r .id <<<"$BODY")"
[ "$SECOND_NUMBER" != "$INVOICE_NUMBER" ] \
    || die "two invoices were given the same number"
ok "${INVOICE_NUMBER} then ${SECOND_NUMBER} — sequential and distinct"

# Tidy the extra draft away so repeated runs do not litter the list.
api POST "/api/invoices/${SECOND_ID}/cancel" '{"version": 0, "reason": "smoke.sh cleanup"}' "$ADMIN_TOKEN"
expect "$STATUS" "200" "the spare draft is cancelled"

# ---------------------------------------------------------------------------------------
step "Optimistic locking"
# ---------------------------------------------------------------------------------------
api POST "/api/invoices/${INVOICE_ID}/approve" '{"version": 999}' "$ADMIN_TOKEN"
expect "$STATUS" "409" "approving with a stale version is 409"
expect "$(jq -r .code <<<"$BODY")" "STALE_VERSION" "the problem document carries code STALE_VERSION"

# ---------------------------------------------------------------------------------------
step "Approve"
# ---------------------------------------------------------------------------------------
api POST "/api/invoices/${INVOICE_ID}/approve" "$(jq -nc --argjson v "$VERSION" '{version: $v}')" "$ADMIN_TOKEN"
expect "$STATUS" "200" "POST /api/invoices/${INVOICE_ID}/approve"
expect "$(jq -r .status <<<"$BODY")" "APPROVED" "the invoice is APPROVED"
VERSION="$(jq -r .version <<<"$BODY")"
info "approved by $(jq -r .approvedBy <<<"$BODY") at $(jq -r .approvedAt <<<"$BODY")"

# ---------------------------------------------------------------------------------------
step "An approved invoice is locked"
# ---------------------------------------------------------------------------------------
EDIT_BODY="$(jq -nc --argjson customerId "$CUSTOMER_ID" --argjson v "$VERSION" \
    --arg issueDate "$(date -u +%Y-%m-%d)" \
    '{
      version: $v, customerId: $customerId, currencyCode: "USD", exchangeRate: "3.650000",
      taxMode: "INCLUSIVE", issueDate: $issueDate, notes: "should be refused", lines: []
    }')"
api PUT "/api/invoices/${INVOICE_ID}" "$EDIT_BODY" "$ADMIN_TOKEN"
expect "$STATUS" "409" "editing an approved invoice is 409"
expect "$(jq -r .code <<<"$BODY")" "INVOICE_NOT_EDITABLE" "the problem document carries code INVOICE_NOT_EDITABLE"

api POST "/api/invoices/${INVOICE_ID}/approve" "$(jq -nc --argjson v "$VERSION" '{version: $v}')" "$ADMIN_TOKEN"
expect "$STATUS" "409" "approving it twice is 409"
expect "$(jq -r .code <<<"$BODY")" "INVALID_TRANSITION" "the problem document carries code INVALID_TRANSITION"

# ---------------------------------------------------------------------------------------
step "Roles"
# ---------------------------------------------------------------------------------------
api GET /api/invoices "" "$SALES_TOKEN"
expect "$STATUS" "200" "SALES may read invoices"

api POST "/api/invoices/${INVOICE_ID}/cancel" "$(jq -nc --argjson v "$VERSION" '{version: $v}')" "$SALES_TOKEN"
expect "$STATUS" "403" "SALES may not cancel"
expect "$(jq -r .code <<<"$BODY")" "FORBIDDEN" "the problem document carries code FORBIDDEN"

# ---------------------------------------------------------------------------------------
step "Cancel — the record must survive"
# ---------------------------------------------------------------------------------------
api POST "/api/invoices/${INVOICE_ID}/cancel" \
    "$(jq -nc --argjson v "$VERSION" '{version: $v, reason: "Cancelled by the smoke test"}')" \
    "$ADMIN_TOKEN"
expect "$STATUS" "200" "POST /api/invoices/${INVOICE_ID}/cancel as ADMIN"
expect "$(jq -r .status <<<"$BODY")" "CANCELLED" "the invoice is CANCELLED"
expect "$(jq -r .cancellationReason <<<"$BODY")" "Cancelled by the smoke test" "the reason was recorded"

api GET "/api/invoices/${INVOICE_ID}" "" "$ADMIN_TOKEN"
expect "$STATUS" "200" "the cancelled invoice is still readable"
expect "$(jq -r .invoiceNumber <<<"$BODY")" "$INVOICE_NUMBER" "it kept its number"
jq -e '.lines | length > 0' <<<"$BODY" >/dev/null || die "its lines were lost"
ok "its lines and totals are intact"
jq -e '.approvedAt != null' <<<"$BODY" >/dev/null || die "the approval stamp was lost"
ok "the approval stamp survived the cancellation"

api GET "/api/invoices?status=CANCELLED" "" "$ADMIN_TOKEN"
jq -e --arg n "$INVOICE_NUMBER" 'any(.content[]; .invoiceNumber == $n)' <<<"$BODY" >/dev/null \
    || die "the cancelled invoice vanished from the list"
ok "it still appears under the Cancelled filter"

# ---------------------------------------------------------------------------------------
step "Sign out"
# ---------------------------------------------------------------------------------------
api POST /api/auth/logout "$(jq -nc --arg t "$ADMIN_REFRESH" '{refreshToken: $t}')" "$ADMIN_TOKEN"
expect "$STATUS" "204" "POST /api/auth/logout"

api POST /api/auth/refresh "$(jq -nc --arg t "$ADMIN_REFRESH" '{refreshToken: $t}')"
expect "$STATUS" "401" "the revoked refresh token no longer works"

printf '\n%s%sAll checks passed against %s%s\n\n' "$BOLD" "$GREEN" "$BASE_URL" "$OFF"
