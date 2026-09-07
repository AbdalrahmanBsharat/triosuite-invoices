import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/money/money_format.dart';
import '../../../core/money/tax_mode.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/presentation/session_controller.dart';
import '../../invoices/data/catalog_repository.dart';
import '../../invoices/domain/currency.dart';
import '../data/settings_repository.dart';
import 'app_data_controller.dart';

/// The Settings screen.
///
/// Two halves that behave quite differently. The **server** half is shared company configuration —
/// editable by an administrator, read-only for everyone else, and the read-only case is a real
/// state rather than disabled inputs, because a SALES user should be able to see what the defaults
/// are. The **app** half is this device's own preferences and never leaves it.
class SettingsController extends GetxController {
  SettingsController({
    required SettingsRepository settingsRepository,
    required CatalogRepository catalogRepository,
    required AppDataController appDataController,
    required SessionController sessionController,
    required ApiClient apiClient,
  })  : _settings = settingsRepository,
        _catalog = catalogRepository,
        _appData = appDataController,
        _session = sessionController,
        _api = apiClient;

  final SettingsRepository _settings;
  final CatalogRepository _catalog;
  final AppDataController _appData;
  final SessionController _session;
  final ApiClient _api;

  final TextEditingController taxRateController = TextEditingController();
  final TextEditingController prefixController = TextEditingController();

  final RxBool saving = false.obs;
  final RxString appVersion = ''.obs;

  /// The address the client is currently pointed at.
  ///
  /// Observable rather than a getter over the client: the row that displays it sits in an `Obx`,
  /// which throws if nothing observable is read inside it, and it has to repaint when the address
  /// is changed from the sheet.
  final RxString apiBaseUrl = ''.obs;

  final RxString baseCurrencyCode = ''.obs;
  final RxString defaultCurrencyCode = ''.obs;
  final Rx<TaxMode> defaultTaxMode = TaxMode.exclusive.obs;

  /// Which currency's rate is currently being saved, so only that row shows a spinner.
  final RxnString savingRateFor = RxnString();

  bool get isAdmin => _session.isAdmin;

  bool get loading => _appData.loading.value;

  String? get loadError => _appData.error.value;

  List<Currency> get currencies => _appData.currencies;

  String get signedInAs => _session.user.value?.fullName ?? '—';

  String get signedInUsername => _session.user.value?.username ?? '';

  String get roleLabel => _session.user.value?.role.label ?? '';

  @override
  void onInit() {
    super.onInit();
    apiBaseUrl.value = _api.baseUrl;
    unawaited(_loadVersion());
    unawaited(refreshAll());
  }

  @override
  void onClose() {
    taxRateController.dispose();
    prefixController.dispose();
    super.onClose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    appVersion.value = '${info.version} (${info.buildNumber})';
  }

  /// Re-reads settings, currencies and rates, then refills the form fields from them.
  Future<void> refreshAll() async {
    apiBaseUrl.value = _api.baseUrl;
    await _appData.load();
    _applyToForm();
  }

  void _applyToForm() {
    final settings = _appData.settings.value;
    if (settings == null) {
      return;
    }
    baseCurrencyCode.value = settings.baseCurrencyCode;
    defaultCurrencyCode.value = settings.defaultCurrencyCode;
    defaultTaxMode.value = settings.defaultTaxMode;
    taxRateController.text = MoneyFormat.taxRate(settings.defaultTaxRate).replaceAll('%', '');
    prefixController.text = settings.invoiceNumberPrefix;
  }

  void setBaseCurrency(String code) => baseCurrencyCode.value = code;

  void setDefaultCurrency(String code) => defaultCurrencyCode.value = code;

  void setDefaultTaxMode(TaxMode mode) => defaultTaxMode.value = mode;

  /// The current rate for a currency, as text for its row.
  String rateTextFor(String currencyCode) {
    final rate = _appData.suggestedRateFor(currencyCode);
    return rate == null ? '—' : MoneyFormat.exchangeRate(rate);
  }

  /// Saves the server-side defaults.
  Future<void> saveSettings() async {
    final percent = MoneyFormat.tryParse(taxRateController.text);
    if (percent == null || percent < Decimal.zero || percent > Decimal.fromInt(100)) {
      AppSnackbar.failure('The default tax rate must be between 0 and 100.');
      return;
    }
    final prefix = prefixController.text.trim().toUpperCase();
    if (prefix.isEmpty || !RegExp(r'^[A-Z0-9]+$').hasMatch(prefix)) {
      AppSnackbar.failure('The prefix may contain only letters and digits.');
      return;
    }

    saving.value = true;
    try {
      // The API stores the rate as a fraction; the field takes a percentage because that is how
      // people talk about tax.
      final asFraction = (percent / Decimal.fromInt(100))
          .toDecimal(scaleOnInfinitePrecision: 8)
          .round(scale: 4);

      final updated = await _settings.update(
        baseCurrencyCode: baseCurrencyCode.value,
        defaultCurrencyCode: defaultCurrencyCode.value,
        defaultTaxMode: defaultTaxMode.value,
        defaultTaxRate: asFraction,
        invoiceNumberPrefix: prefix,
      );
      _appData.applySettings(updated);
      _applyToForm();
      AppSnackbar.success('Settings saved.');
    } on ApiException catch (failure) {
      AppSnackbar.failure(failure.message);
    } finally {
      saving.value = false;
    }
  }

  /// Saves one currency's suggested rate.
  Future<void> saveExchangeRate(String currencyCode, String rawRate) async {
    final rate = MoneyFormat.tryParse(rawRate);
    if (rate == null || rate <= Decimal.zero) {
      AppSnackbar.failure('The rate must be more than 0.');
      return;
    }

    savingRateFor.value = currencyCode;
    try {
      final updated = await _catalog.updateExchangeRate(
        currencyCode: currencyCode,
        rateToBase: rate,
      );
      _appData.applyExchangeRate(updated);
      AppSnackbar.success('$currencyCode is now $rawRate ${baseCurrencyCode.value}.');
    } on ApiException catch (failure) {
      AppSnackbar.failure(failure.message);
    } finally {
      savingRateFor.value = null;
    }
  }

  /// Signs out, clearing the cached reference data so a different account starts clean.
  Future<void> signOut() async {
    _appData.clear();
    await _session.signOut();
  }
}
