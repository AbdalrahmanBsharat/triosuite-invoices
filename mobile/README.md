# Triosuite Invoices — Flutter app

The mobile half of the [Triosuite Invoices](../README.md) system. Five screens over the
[Spring Boot API](../backend).

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # emulator → host machine

flutter analyze                                                # clean, no ignore comments
flutter test                                                   # 52 tests
flutter build apk --release --dart-define=API_BASE_URL=https://your-api
```

`10.0.2.2` is the Android emulator's alias for `localhost` on the host. On a physical device use
your machine's LAN address — or install the APK and set the address in the app under
**Settings → API address**, which overrides whatever was compiled in.

---

## Layout

```
lib/
├── core/
│   ├── config/        API base URL resolution and timeouts
│   ├── money/         Decimal formatting, tax modes, the totals calculator
│   ├── network/       dio client, auth interceptor, problem+json mapping, JSON converters
│   ├── routing/       the five routes, and their bindings
│   ├── storage/       secure storage for tokens and device preferences
│   ├── theme/         Material 3 light + dark, and the theme preference
│   └── widgets/       loading/empty/error view, status badge, snackbars, API address sheet
└── features/
    ├── auth/          {data, domain, presentation}
    ├── invoices/      {data, domain, presentation/widgets}
    └── settings/      {data, domain, presentation}
```

`domain/` holds freezed models and enums, `data/` holds repositories over the API client, and
`presentation/` holds GetX controllers and widgets. Generated `.freezed.dart` and `.g.dart` files
are committed, and CI fails if they are stale.

```bash
dart run build_runner build     # after changing anything under domain/
```

---

## Five screens, and nothing else

The assessment caps the app at five, so there are exactly five `GetPage` entries in
[`lib/core/routing/app_pages.dart`](lib/core/routing/app_pages.dart):

| Route | Screen |
|---|---|
| `/login` | Login — also the start-up connectivity gate |
| `/invoices` | Invoice list |
| `/invoices/new` | Create, reused for edit via an `invoiceId` argument |
| `/invoices/:id` | Invoice details |
| `/settings` | Settings |

Everything else is a modal inside one of them: the barcode scanner, the item picker, the customer
picker, the approve and cancel confirmations, the cancellation-reason prompt and the API address
sheet.

---

## Three things worth knowing

**The totals footer is a preview.** `core/money/invoice_calculator.dart` mirrors the server's
`InvoiceCalculator` — same formulas, same half-up per-line rounding to the invoice currency's minor
units — so the figures move as you type without a round trip per keystroke. The server recomputes
everything on save and its answer is what gets stored and shown afterwards.
`test/core/invoice_calculator_test.dart` asserts **the same expected values as the Java test suite**,
so the two cannot drift apart unnoticed.

**Money never touches a `double`.** Amounts are `Decimal` end to end. Responses arrive as JSON
numbers, and `DecimalConverter` rebuilds them from the number's shortest round-tripping decimal text
rather than its binary value; requests send decimals as strings. See ADR-0013 in
[`docs/DECISIONS.md`](../docs/DECISIONS.md).

**A `401` triggers one refresh, not five.** The dio interceptor performs a single-flight refresh and
retries the original request once. Refresh tokens are single-use and rotate, so concurrent refreshes
would revoke each other's replacement and log the user out for no reason.

---

## Tests

```bash
flutter test                                    # 52
flutter test test/contract --tags contract      # needs a running backend
```

| File | Tests | What it covers |
|---|---|---|
| `test/core/invoice_calculator_test.dart` | 30 | Both tax modes, 2- and 3-decimal currencies, exact-half rounding, zero tax, rounding drift, `net + tax = gross`, base conversion |
| `test/contract/api_contract_test.dart` | 15 | The real repositories and models against a live API: every field, enum, date and decimal, plus the full invoice lifecycle |
| `test/features/login_page_test.dart` | 7 | Validation, the show/hide toggle, the error path, and that no registration affordance exists |

The contract tests skip themselves when nothing answers, so `flutter test` stays green without a
backend. They create and cancel a few invoices, so point them at a development database.

---

## Android

| | |
|---|---|
| Application ID | `com.bsharat.triosuite_invoices` |
| minSdk | 23 — what `mobile_scanner` 7 requires |
| Release networking | **HTTPS only.** No cleartext exception at all |
| Debug networking | Cleartext to `10.0.2.2`, `127.0.0.1` and `localhost` only |
| Permissions | `CAMERA` (optional — the picker works without it), `INTERNET` |
| Launcher icon | Generated: `java tool/GenerateLauncherIcon.java` |

Signing uses `android/key.properties` and a keystore, both git-ignored. When they are absent the
release build falls back to the debug key, so `flutter build apk --release` works for anyone. See
the [root README](../README.md#building-the-apk) for generating your own.
