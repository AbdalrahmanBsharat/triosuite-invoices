import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/network/json_converters.dart';

part 'exchange_rate.freezed.dart';
part 'exchange_rate.g.dart';

/// The rate suggested for a currency when a new invoice is created.
///
/// [rateToBase] is how many base-currency units one unit of [currencyCode] is worth. It is only
/// ever a suggestion: the Create screen pre-fills it, the user may override it, and whatever the
/// invoice is saved with is snapshotted onto the invoice and never read back from here.
@freezed
abstract class ExchangeRate with _$ExchangeRate {
  const factory ExchangeRate({
    required String currencyCode,
    @DecimalConverter() required Decimal rateToBase,
    required DateTime updatedAt,
  }) = _ExchangeRate;

  factory ExchangeRate.fromJson(Map<String, dynamic> json) => _$ExchangeRateFromJson(json);
}
