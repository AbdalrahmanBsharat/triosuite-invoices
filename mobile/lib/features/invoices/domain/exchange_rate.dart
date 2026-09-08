import 'package:decimal/decimal.dart';

import '../../../core/money/decimal_json.dart';

/// The rate suggested for a currency when a new invoice is created.
///
/// [rateToBase] is how many base-currency units one unit of [currencyCode] is worth. It is only
/// ever a suggestion: the Create screen pre-fills it, the user may override it, and whatever the
/// invoice is saved with is snapshotted onto the invoice and never read back from here.
class ExchangeRate {
  const ExchangeRate({
    required this.currencyCode,
    required this.rateToBase,
    required this.updatedAt,
  });

  final String currencyCode;
  final Decimal rateToBase;
  final DateTime updatedAt;

  factory ExchangeRate.fromJson(Map<String, dynamic> json) {
    return ExchangeRate(
      currencyCode: json['currencyCode'] as String,
      rateToBase: decimalFromJson(json['rateToBase']),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
