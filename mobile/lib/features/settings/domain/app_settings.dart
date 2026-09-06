import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/money/tax_mode.dart';
import '../../../core/network/json_converters.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

/// Company-wide invoicing defaults, read once at start-up.
///
/// [baseCurrencyCode] is the reporting currency: every invoice also carries its grand total
/// converted into it, which is what makes a list of invoices in five currencies comparable.
@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    required String baseCurrencyCode,
    required String defaultCurrencyCode,
    required TaxMode defaultTaxMode,
    @DecimalConverter() required Decimal defaultTaxRate,
    required String invoiceNumberPrefix,
    required DateTime updatedAt,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);
}
