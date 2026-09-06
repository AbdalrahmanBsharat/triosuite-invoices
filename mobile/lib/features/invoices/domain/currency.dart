import 'package:freezed_annotation/freezed_annotation.dart';

part 'currency.freezed.dart';
part 'currency.g.dart';

/// A currency an invoice may be issued in.
///
/// [minorUnits] is the number of decimal places the currency is quoted in — 2 for ILS, USD, EUR and
/// GBP, 3 for JOD. It drives every rounding decision in the on-device totals preview, so the app
/// rounds exactly where the server does rather than assuming two decimals everywhere.
@freezed
abstract class Currency with _$Currency {
  const factory Currency({
    required String code,
    required String name,
    required String symbol,
    required int minorUnits,
    required bool active,
  }) = _Currency;

  factory Currency.fromJson(Map<String, dynamic> json) => _$CurrencyFromJson(json);
}
