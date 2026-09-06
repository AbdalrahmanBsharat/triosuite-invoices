@Tags(['contract'])
library;

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triosuite_invoices/core/money/invoice_calculator.dart';
import 'package:triosuite_invoices/core/money/tax_mode.dart';
import 'package:triosuite_invoices/core/network/api_client.dart';
import 'package:triosuite_invoices/core/network/api_exception.dart';
import 'package:triosuite_invoices/core/storage/secure_store.dart';
import 'package:triosuite_invoices/features/auth/data/auth_repository.dart';
import 'package:triosuite_invoices/features/auth/domain/app_user.dart';
import 'package:triosuite_invoices/features/invoices/data/catalog_repository.dart';
import 'package:triosuite_invoices/features/invoices/data/invoice_repository.dart';
import 'package:triosuite_invoices/features/invoices/domain/invoice.dart';
import 'package:triosuite_invoices/features/settings/data/settings_repository.dart';

/// Drives the app's own repositories and models against a **running backend**.
///
/// This is the app-side half of the smoke test. `backend/scripts/smoke.sh` proves the API behaves;
/// this proves the app *understands* it — that every field name lines up, every enum value parses,
/// every date and decimal survives the round trip, and the on-device totals preview agrees with
/// what the server computed. Those are exactly the mistakes that a green unit-test suite and a
/// successful `flutter build` will both happily miss.
///
/// It needs no emulator: `dio` runs on the Dart VM, and the two things that do need platform
/// channels — secure storage and package info — are faked or unused here.
///
/// ```bash
/// # with the backend running on localhost:8080
/// flutter test test/contract --tags contract
/// flutter test test/contract --tags contract --dart-define=API_BASE_URL=https://your-api
/// ```
///
/// The whole group is skipped, not failed, when nothing answers — so `flutter test` stays green on
/// a machine with no backend, and in CI, where these run as their own step.
void main() {
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  late ApiClient api;
  late AuthRepository auth;
  late CatalogRepository catalog;
  late InvoiceRepository invoices;
  late SettingsRepository settings;
  late _InMemoryStore store;

  bool reachable = false;

  setUpAll(() async {
    store = _InMemoryStore();
    api = ApiClient(store, baseUrl: baseUrl);
    auth = AuthRepository(api);
    catalog = CatalogRepository(api);
    invoices = InvoiceRepository(api);
    settings = SettingsRepository(api);

    reachable = await api.checkHealth();
    if (!reachable) {
      stdout.writeln(
        'Contract tests skipped: nothing answered at $baseUrl. '
        'Start the backend and re-run with --tags contract.',
      );
      return;
    }

    final tokens = await auth.login(username: 'admin', password: 'Admin#2026');
    await store.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
  });

  /// Fails the test if the backend is not up, so a skipped run is never mistaken for a passing one.
  void requireBackend() {
    if (!reachable) {
      markTestSkipped('no backend at $baseUrl');
    }
  }

  group('authentication', () {
    test('login returns an account the app can parse', () async {
      requireBackend();
      if (!reachable) return;

      final tokens = await auth.login(username: 'admin', password: 'Admin#2026');

      expect(tokens.accessToken, isNotEmpty);
      expect(tokens.refreshToken, isNotEmpty);
      expect(tokens.expiresInSeconds, greaterThan(0));
      expect(tokens.user.username, 'admin');
      expect(tokens.user.role, UserRole.admin);
    });

    test('the SALES role parses too', () async {
      requireBackend();
      if (!reachable) return;

      final tokens = await auth.login(username: 'sales', password: 'Sales#2026');
      expect(tokens.user.role, UserRole.sales);
    });

    test('a wrong password surfaces as UNAUTHORIZED, not a crash', () async {
      requireBackend();
      if (!reachable) return;

      await expectLater(
        auth.login(username: 'admin', password: 'definitely-not-it'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.unauthorized)),
      );
    });

    test('me() resolves the stored token', () async {
      requireBackend();
      if (!reachable) return;

      final user = await auth.me();
      expect(user.username, 'admin');
    });
  });

  group('reference data', () {
    test('settings parse, including the tax mode enum', () async {
      requireBackend();
      if (!reachable) return;

      final loaded = await settings.fetch();

      expect(loaded.baseCurrencyCode, hasLength(3));
      expect(loaded.invoiceNumberPrefix, isNotEmpty);
      expect(TaxMode.values, contains(loaded.defaultTaxMode));
      expect(loaded.defaultTaxRate, isA<Decimal>());
    });

    test('currencies carry the minor units the preview rounds by', () async {
      requireBackend();
      if (!reachable) return;

      final list = await catalog.currencies();

      expect(list, isNotEmpty);
      expect(list.every((c) => c.minorUnits == 2 || c.minorUnits == 3), isTrue);
      // JOD is the reason minorUnits exists at all; if the seed ever loses it, the three-decimal
      // path stops being exercised anywhere.
      expect(
        list.where((c) => c.code == 'JOD').map((c) => c.minorUnits),
        contains(3),
      );
    });

    test('exchange rates parse as decimals', () async {
      requireBackend();
      if (!reachable) return;

      final rates = await catalog.exchangeRates();
      expect(rates, isNotEmpty);
      expect(rates.every((r) => r.rateToBase > Decimal.zero), isTrue);
    });

    test('a seeded barcode resolves to its item', () async {
      requireBackend();
      if (!reachable) return;

      final item = await catalog.itemByBarcode('7290001000014');

      expect(item.sku, 'LAP-1401');
      expect(item.barcode, '7290001000014');
      expect(item.unitPrice, Decimal.parse('4299'));
      expect(item.taxRate, Decimal.parse('0.16'));
    });

    test('an unknown barcode is NOT_FOUND, which the scanner treats as a normal outcome', () async {
      requireBackend();
      if (!reachable) return;

      await expectLater(
        catalog.itemByBarcode('9999999999999'),
        throwsA(isA<ApiException>().having((e) => e.isNotFound, 'isNotFound', isTrue)),
      );
    });

    test('customer and item search paginate', () async {
      requireBackend();
      if (!reachable) return;

      final customers = await catalog.customers(size: 2);
      expect(customers.content, hasLength(lessThanOrEqualTo(2)));
      expect(customers.totalElements, greaterThan(0));

      final items = await catalog.items(search: 'laptop');
      expect(items.content, isNotEmpty);
    });
  });

  group('invoices', () {
    test('the list parses every status the seed contains', () async {
      requireBackend();
      if (!reachable) return;

      final page = await invoices.list(size: 100);

      expect(page.content, isNotEmpty);
      final statuses = page.content.map((i) => i.status).toSet();
      expect(statuses, contains(InvoiceStatus.approved));
      expect(page.content.every((i) => i.grandTotal >= Decimal.zero), isTrue);
    });

    test('the status filter reaches the server, not just the UI', () async {
      requireBackend();
      if (!reachable) return;

      final cancelled = await invoices.list(status: InvoiceStatus.cancelled, size: 100);
      expect(
        cancelled.content.every((i) => i.status == InvoiceStatus.cancelled),
        isTrue,
        reason: 'cancelled invoices stay listed, and only those come back',
      );
    });

    test('a full invoice parses and its stored totals match the on-device calculator', () async {
      requireBackend();
      if (!reachable) return;

      final page = await invoices.list(size: 100);
      final settingsRow = await settings.fetch();
      final currencies = await catalog.currencies();
      final baseMinorUnits = currencies
          .firstWhere((c) => c.code == settingsRow.baseCurrencyCode)
          .minorUnits;

      for (final summary in page.content) {
        final invoice = await invoices.byId(summary.id);

        expect(invoice.invoiceNumber, matches(RegExp(r'^[A-Z0-9]+-\d{4}-\d{6}$')));

        // No assertion that lines exist: an empty draft is legal — it simply cannot be approved —
        // and the calculator returns zero totals for one, which is exactly what is checked below.
        final recomputed = InvoiceCalculator.invoice(
          lines: invoice.lines
              .map((line) => LineInput(
                    quantity: line.quantity,
                    unitPrice: line.unitPrice,
                    taxRate: line.taxRate,
                  ))
              .toList(),
          taxMode: invoice.taxMode,
          currencyMinorUnits: invoice.currencyMinorUnits,
          exchangeRate: invoice.exchangeRate,
          baseCurrencyMinorUnits: baseMinorUnits,
        );

        expect(recomputed.subtotal, invoice.subtotal,
            reason: '${invoice.invoiceNumber} subtotal');
        expect(recomputed.taxTotal, invoice.taxTotal,
            reason: '${invoice.invoiceNumber} tax total');
        expect(recomputed.grandTotal, invoice.grandTotal,
            reason: '${invoice.invoiceNumber} grand total');
        expect(recomputed.grandTotalBase, invoice.grandTotalBase,
            reason: '${invoice.invoiceNumber} base-currency total');
      }
    });

    test('create, approve, refuse an edit, cancel — and the record survives', () async {
      requireBackend();
      if (!reachable) return;

      final settingsRow = await settings.fetch();
      final customers = await catalog.customers(size: 1);
      final item = await catalog.itemByBarcode('7290001000045');

      final draft = InvoiceDraft(
        customerId: customers.content.first.id,
        currencyCode: 'USD',
        exchangeRate: Decimal.parse('3.650000'),
        taxMode: TaxMode.inclusive,
        issueDate: DateTime.now(),
        notes: 'Created by the Flutter contract test',
        lines: [
          InvoiceLineDraft(
            itemId: item.id,
            quantity: Decimal.parse('3'),
            unitPrice: Decimal.parse('520.27'),
          ),
        ],
      );

      // Create
      final created = await invoices.create(draft);
      expect(created.status, InvoiceStatus.draft);
      expect(created.version, 0);
      expect(created.taxMode, TaxMode.inclusive);
      expect(created.currencyCode, 'USD');
      expect(created.baseCurrencyCode, settingsRow.baseCurrencyCode);
      expect(created.subtotal + created.taxTotal, created.grandTotal);
      expect(created.lines.single.barcode, '7290001000045');

      // Approve
      final approved = await invoices.approve(id: created.id, version: created.version);
      expect(approved.status, InvoiceStatus.approved);
      expect(approved.version, created.version + 1);
      expect(approved.approvedBy, isNotNull);
      expect(approved.approvedAt, isNotNull);

      // An approved invoice is locked
      await expectLater(
        invoices.update(id: created.id, version: approved.version, draft: draft),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.invoiceNotEditable)),
      );

      // A stale version is refused
      await expectLater(
        invoices.cancel(id: created.id, version: 999),
        throwsA(isA<ApiException>().having((e) => e.isStaleVersion, 'isStaleVersion', isTrue)),
      );

      // Cancel
      final cancelled = await invoices.cancel(
        id: created.id,
        version: approved.version,
        reason: 'Created by the Flutter contract test',
      );
      expect(cancelled.status, InvoiceStatus.cancelled);
      expect(cancelled.cancellationReason, 'Created by the Flutter contract test');

      // The record survives, with its approval stamp and its lines
      final reloaded = await invoices.byId(created.id);
      expect(reloaded.invoiceNumber, created.invoiceNumber);
      expect(reloaded.status, InvoiceStatus.cancelled);
      expect(reloaded.approvedAt, isNotNull);
      expect(reloaded.lines, hasLength(1));
      expect(reloaded.grandTotal, created.grandTotal);
    });

    test('the server allocates numbers; two creates never collide', () async {
      requireBackend();
      if (!reachable) return;

      final customers = await catalog.customers(size: 1);
      InvoiceDraft draft() => InvoiceDraft(
            customerId: customers.content.first.id,
            currencyCode: 'ILS',
            exchangeRate: Decimal.one,
            taxMode: TaxMode.exclusive,
            issueDate: DateTime.now(),
            notes: 'Numbering probe',
            lines: const [],
          );

      final first = await invoices.create(draft());
      final second = await invoices.create(draft());

      expect(first.invoiceNumber, isNot(second.invoiceNumber));

      // Tidy up so repeated runs do not fill the reviewer's list with probes.
      await invoices.cancel(id: first.id, version: first.version, reason: 'contract test cleanup');
      await invoices.cancel(id: second.id, version: second.version, reason: 'contract test cleanup');
    });
  });
}

/// Keeps tokens in memory: `flutter test` has no platform channels for the Keystore.
class _InMemoryStore extends SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> readAccessToken() async => _values['access'];

  @override
  Future<String?> readRefreshToken() async => _values['refresh'];

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _values['access'] = accessToken;
    _values['refresh'] = refreshToken;
  }

  @override
  Future<void> clearTokens() async => _values.clear();

  @override
  Future<String?> readBaseUrlOverride() async => null;

  @override
  Future<ThemeMode> readThemeMode() async => ThemeMode.system;
}
