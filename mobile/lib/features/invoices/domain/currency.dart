/// A currency an invoice may be issued in.
///
/// [minorUnits] is the number of decimal places the currency is quoted in — 2 for ILS, USD, EUR and
/// GBP, 3 for JOD. It drives every rounding decision in the on-device totals preview, so the app
/// rounds exactly where the server does rather than assuming two decimals everywhere.
class Currency {
  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.minorUnits,
    required this.active,
  });

  final String code;
  final String name;
  final String symbol;
  final int minorUnits;
  final bool active;

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      code: json['code'] as String,
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      minorUnits: json['minorUnits'] as int,
      active: json['active'] as bool? ?? true,
    );
  }
}
