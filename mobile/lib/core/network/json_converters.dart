import 'package:decimal/decimal.dart';
import 'package:json_annotation/json_annotation.dart';

/// Converts the API's monetary and quantity fields to [Decimal].
///
/// The API sends these as JSON numbers, so `dart:convert` has already turned them into `double`
/// by the time this runs. Going `double` → [Decimal] naively would defeat the point of using
/// `Decimal` at all, so the conversion goes through the number's **shortest round-tripping decimal
/// representation** — Dart guarantees `double.toString()` produces a string that parses back to the
/// identical double, which for values with at most 15 significant digits is the exact decimal the
/// server sent. Every amount in this system is `DECIMAL(19,4)` at realistic invoice magnitudes, so
/// that condition holds with a wide margin.
///
/// Amounts are also accepted as strings, which is what the app sends *back*: requests serialise
/// decimals as strings so nothing the user typed is ever routed through a binary float on its way
/// to the server.
class DecimalConverter implements JsonConverter<Decimal, Object> {
  const DecimalConverter();

  @override
  Decimal fromJson(Object json) => _parse(json) ?? Decimal.zero;

  @override
  Object toJson(Decimal value) => value.toString();

  static Decimal? _parse(Object? json) {
    if (json == null) {
      return null;
    }
    if (json is String) {
      return Decimal.tryParse(json);
    }
    if (json is int) {
      return Decimal.fromInt(json);
    }
    if (json is double) {
      // Exponent notation would not parse; expand it first. Unreachable for invoice-sized
      // numbers, but a converter that silently returns zero on a valid amount is not worth having.
      final text = json.toString();
      return Decimal.tryParse(text.contains('e') || text.contains('E')
          ? json.toStringAsFixed(10)
          : text);
    }
    return Decimal.tryParse(json.toString());
  }
}

/// The nullable counterpart of [DecimalConverter].
class NullableDecimalConverter implements JsonConverter<Decimal?, Object?> {
  const NullableDecimalConverter();

  @override
  Decimal? fromJson(Object? json) => DecimalConverter._parse(json);

  @override
  Object? toJson(Decimal? value) => value?.toString();
}
