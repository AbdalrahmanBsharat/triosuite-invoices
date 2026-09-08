import 'package:decimal/decimal.dart';

/// Reads a monetary or quantity field from a decoded JSON value as a [Decimal].
///
/// The API sends these as JSON numbers, so `dart:convert` has already turned them into `double`
/// by the time this runs. Going `double` -> [Decimal] naively would defeat the point of using
/// [Decimal] at all, so the conversion goes through the number's **shortest round-tripping decimal
/// representation**: Dart guarantees `double.toString()` produces a string that parses back to the
/// identical double, which for values with at most 15 significant digits is the exact decimal the
/// server sent. Every amount in this system is `DECIMAL(19,4)` at realistic invoice magnitudes, so
/// that condition holds with a wide margin.
///
/// Strings are accepted too, which is what the app sends *back*: requests serialise decimals as
/// strings so nothing the user typed is ever routed through a binary float on its way to the
/// server.
///
/// Returns [Decimal.zero] for a missing or unreadable value, so a malformed field cannot crash a
/// screen that is only displaying a total.
Decimal decimalFromJson(Object? value) {
  if (value == null) {
    return Decimal.zero;
  }
  if (value is String) {
    return Decimal.tryParse(value) ?? Decimal.zero;
  }
  if (value is int) {
    return Decimal.fromInt(value);
  }
  if (value is double) {
    // Exponent notation would not parse, so expand it first. Unreachable at invoice magnitudes,
    // but a parser that silently returns zero for a valid amount is not worth having.
    final text = value.toString();
    final parsable = text.contains('e') || text.contains('E')
        ? value.toStringAsFixed(10)
        : text;
    return Decimal.tryParse(parsable) ?? Decimal.zero;
  }
  return Decimal.tryParse(value.toString()) ?? Decimal.zero;
}
