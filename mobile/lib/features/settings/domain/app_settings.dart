import 'package:decimal/decimal.dart';

import '../../../core/money/decimal_json.dart';
import '../../../core/money/tax_mode.dart';

/// Company-wide invoicing defaults, read once at start-up.
///
/// [baseCurrencyCode] is the reporting currency: every invoice also carries its grand total
/// converted into it, which is what makes a list of invoices in five currencies comparable.
class AppSettings {
  const AppSettings({
    required this.baseCurrencyCode,
    required this.defaultCurrencyCode,
    required this.defaultTaxMode,
    required this.defaultTaxRate,
    required this.invoiceNumberPrefix,
    required this.updatedAt,
  });

  final String baseCurrencyCode;
  final String defaultCurrencyCode;
  final TaxMode defaultTaxMode;
  final Decimal defaultTaxRate;
  final String invoiceNumberPrefix;
  final DateTime updatedAt;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      baseCurrencyCode: json['baseCurrencyCode'] as String,
      defaultCurrencyCode: json['defaultCurrencyCode'] as String,
      defaultTaxMode: TaxMode.fromWire(json['defaultTaxMode'] as String?),
      defaultTaxRate: decimalFromJson(json['defaultTaxRate']),
      invoiceNumberPrefix: json['invoiceNumberPrefix'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
