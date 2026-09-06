import 'package:decimal/decimal.dart';
import 'package:get/get.dart';

import '../../../core/network/api_exception.dart';
import '../../invoices/data/catalog_repository.dart';
import '../../invoices/domain/currency.dart';
import '../../invoices/domain/exchange_rate.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';

/// Reference data that the whole app leans on: the settings row, the currency list and the
/// suggested exchange rates.
///
/// Loaded once after sign-in and cached, because every invoice screen needs some of it — the base
/// currency to label a total, a currency's minor units to round a preview, a rate to pre-fill the
/// Create form — and re-fetching it per screen would be three requests for data that changes
/// perhaps twice a year.
class AppDataController extends GetxController {
  AppDataController({
    required SettingsRepository settingsRepository,
    required CatalogRepository catalogRepository,
  })  : _settings = settingsRepository,
        _catalog = catalogRepository;

  final SettingsRepository _settings;
  final CatalogRepository _catalog;

  final RxBool loading = false.obs;
  final RxnString error = RxnString();

  final Rxn<AppSettings> settings = Rxn<AppSettings>();
  final RxList<Currency> currencies = <Currency>[].obs;
  final RxList<ExchangeRate> exchangeRates = <ExchangeRate>[].obs;

  bool get isLoaded => settings.value != null && currencies.isNotEmpty;

  /// The reporting currency every invoice also reports its total in.
  Currency? get baseCurrency {
    final code = settings.value?.baseCurrencyCode;
    return code == null ? null : currencyOf(code);
  }

  /// Looks a currency up by code, or null when it is not in the list.
  Currency? currencyOf(String code) {
    for (final currency in currencies) {
      if (currency.code == code) {
        return currency;
      }
    }
    return null;
  }

  /// The decimal places a currency is quoted in, defaulting to 2 for an unknown code.
  int minorUnitsOf(String code) => currencyOf(code)?.minorUnits ?? 2;

  /// The symbol for a currency, falling back to its code so a total is never rendered bare.
  String symbolOf(String code) => currencyOf(code)?.symbol ?? code;

  /// The suggested rate for a currency, or null when none is maintained.
  Decimal? suggestedRateFor(String code) {
    for (final rate in exchangeRates) {
      if (rate.currencyCode == code) {
        return rate.rateToBase;
      }
    }
    return null;
  }

  /// Fetches all three in parallel. Safe to call repeatedly; the Settings screen uses it to refresh.
  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      final results = await Future.wait([
        _settings.fetch(),
        _catalog.currencies(),
        _catalog.exchangeRates(),
      ]);
      settings.value = results[0] as AppSettings;
      currencies.assignAll(results[1] as List<Currency>);
      exchangeRates.assignAll(results[2] as List<ExchangeRate>);
    } on ApiException catch (failure) {
      error.value = failure.message;
    } finally {
      loading.value = false;
    }
  }

  /// Loads once, if it has not been loaded already.
  Future<void> ensureLoaded() async {
    if (isLoaded || loading.value) {
      return;
    }
    await load();
  }

  /// Applies a settings change made on the Settings screen without a re-fetch.
  void applySettings(AppSettings updated) => settings.value = updated;

  /// Applies a rate change made on the Settings screen without a re-fetch.
  void applyExchangeRate(ExchangeRate updated) {
    final index = exchangeRates.indexWhere(
      (rate) => rate.currencyCode == updated.currencyCode,
    );
    if (index == -1) {
      exchangeRates.add(updated);
    } else {
      exchangeRates[index] = updated;
    }
  }

  /// Drops everything, so a different account never sees the previous one's cached data.
  void clear() {
    settings.value = null;
    currencies.clear();
    exchangeRates.clear();
    error.value = null;
  }
}
