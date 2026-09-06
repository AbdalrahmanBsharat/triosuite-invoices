import 'package:decimal/decimal.dart';

import '../../../core/money/tax_mode.dart';
import '../../../core/network/api_client.dart';
import '../domain/app_settings.dart';

/// Company-wide invoicing defaults.
class SettingsRepository {
  const SettingsRepository(this._api);

  final ApiClient _api;

  /// Readable by any signed-in user.
  Future<AppSettings> fetch() async {
    final json = await _api.get('/api/settings');
    return AppSettings.fromJson(json as Map<String, dynamic>);
  }

  /// Replaces every setting. Administrators only — a SALES caller gets 403.
  Future<AppSettings> update({
    required String baseCurrencyCode,
    required String defaultCurrencyCode,
    required TaxMode defaultTaxMode,
    required Decimal defaultTaxRate,
    required String invoiceNumberPrefix,
  }) async {
    final json = await _api.put('/api/settings', body: {
      'baseCurrencyCode': baseCurrencyCode,
      'defaultCurrencyCode': defaultCurrencyCode,
      'defaultTaxMode': defaultTaxMode.wireName,
      // Decimals go out as strings so nothing the user typed is routed through a binary float.
      'defaultTaxRate': defaultTaxRate.toString(),
      'invoiceNumberPrefix': invoiceNumberPrefix,
    });
    return AppSettings.fromJson(json as Map<String, dynamic>);
  }
}
