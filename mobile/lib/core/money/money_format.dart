import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Formatting for the monetary values that come off the wire.
///
/// Amounts arrive as JSON numbers at full precision — `10443.2500` — and are parsed straight into
/// [Decimal]. They are turned into text only here, at the edge, so no rounding decision is ever
/// made accidentally by a formatter buried in a widget.
///
/// Note what this does *not* do: convert to `double`. `NumberFormat.format` takes a `num`, and
/// handing it a double would reintroduce exactly the binary-floating-point error the whole money
/// pipeline is built to avoid. The digits are produced by [Decimal.toStringAsFixed] and then
/// grouped by hand, using the locale's own separators.
abstract final class MoneyFormat {
  const MoneyFormat._();

  /// Formats an amount with its currency symbol, grouped for the device's locale.
  ///
  /// [minorUnits] comes from the currency, so JOD renders with three decimals and USD with two —
  /// exactly the scale the server rounded to.
  static String amount(
    Decimal value, {
    required String symbol,
    required int minorUnits,
  }) =>
      '$symbol${plain(value, minorUnits: minorUnits)}';

  /// The same without a symbol, for line totals inside a table that already names the currency.
  static String plain(Decimal value, {required int minorUnits}) {
    final symbols = NumberFormat.decimalPattern(Intl.getCurrentLocale()).symbols;

    final fixed = value.toStringAsFixed(minorUnits);
    final negative = fixed.startsWith('-');
    final unsigned = negative ? fixed.substring(1) : fixed;

    final separatorIndex = unsigned.indexOf('.');
    final whole = separatorIndex == -1 ? unsigned : unsigned.substring(0, separatorIndex);
    final fraction = separatorIndex == -1 ? '' : unsigned.substring(separatorIndex + 1);

    final buffer = StringBuffer();
    if (negative) {
      buffer.write(symbols.MINUS_SIGN);
    }
    buffer.write(_group(whole, symbols.GROUP_SEP));
    if (fraction.isNotEmpty) {
      buffer
        ..write(symbols.DECIMAL_SEP)
        ..write(fraction);
    }
    return buffer.toString();
  }

  /// Inserts a group separator every three digits, from the right.
  static String _group(String digits, String separator) {
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final remaining = digits.length - index;
      buffer.write(digits[index]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(separator);
      }
    }
    return buffer.toString();
  }

  /// Renders a tax rate as a percentage: `0.1600` becomes `16%`, `0.0750` becomes `7.5%`.
  static String taxRate(Decimal rate) {
    final percent = (rate * Decimal.fromInt(100)).toString();
    final trimmed = percent.contains('.')
        ? percent.replaceFirst(RegExp(r'\.?0+$'), '')
        : percent;
    return '${trimmed.isEmpty ? '0' : trimmed}%';
  }

  /// Renders an exchange rate at the six decimals the API stores it with.
  static String exchangeRate(Decimal rate) => rate.toStringAsFixed(6);

  /// Parses user input into a [Decimal], returning null when it is not a number.
  ///
  /// A comma is accepted as the decimal separator: numeric keyboards in many locales offer one,
  /// and typing `12,5` should not silently become an invalid quantity.
  static Decimal? tryParse(String? input) {
    if (input == null) {
      return null;
    }
    final normalised = input.trim().replaceAll(',', '.');
    if (normalised.isEmpty) {
      return null;
    }
    return Decimal.tryParse(normalised);
  }
}
