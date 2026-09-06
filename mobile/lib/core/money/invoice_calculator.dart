import 'package:decimal/decimal.dart';

import 'tax_mode.dart';

/// One line as the user has entered it, before any arithmetic.
class LineInput {
  const LineInput({
    required this.quantity,
    required this.unitPrice,
    required this.taxRate,
  });

  final Decimal quantity;
  final Decimal unitPrice;
  final Decimal taxRate;
}

/// A line after rounding. `netAmount + taxAmount == grossAmount` always holds.
class CalculatedLine {
  const CalculatedLine({
    required this.netAmount,
    required this.taxAmount,
    required this.grossAmount,
  });

  final Decimal netAmount;
  final Decimal taxAmount;
  final Decimal grossAmount;
}

/// A whole invoice after rounding.
class CalculatedInvoice {
  const CalculatedInvoice({
    required this.lines,
    required this.subtotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.grandTotalBase,
  });

  final List<CalculatedLine> lines;
  final Decimal subtotal;
  final Decimal taxTotal;
  final Decimal grandTotal;

  /// [grandTotal] converted at the invoice's exchange rate, rounded to the base currency.
  final Decimal grandTotalBase;
}

/// The on-device mirror of the server's `InvoiceCalculator`.
///
/// This exists for one reason: so the totals footer on the Create screen can update as the user
/// types, without a round trip per keystroke. It is a **preview**. The server recomputes everything
/// on save and its answer is what gets stored and displayed afterwards — this class never decides
/// what an invoice is worth.
///
/// That makes it all the more important that the two agree, because a preview that disagrees with
/// the saved invoice by a cent is worse than no preview at all. The formulas and the rounding rule
/// below are therefore identical to the Java implementation, line for line:
///
/// * **Exclusive**: `net = round(q·p)`, `tax = round(net·r)`, `gross = net + tax`
/// * **Inclusive**: `gross = round(q·p)`, `net = round(gross / (1 + r))`, `tax = gross − net`
///
/// Rounding is half-up, applied **per line**, to the invoice currency's minor units. Invoice totals
/// are the sum of the already-rounded lines, never a re-rounding of an unrounded sum. `Decimal`
/// keeps every value exact — no monetary amount in this app ever passes through a `double`.
///
/// `test/core/invoice_calculator_test.dart` re-checks the figures from the Java suite against this
/// implementation, so a change to one that is not made to the other fails the build.
abstract final class InvoiceCalculator {
  const InvoiceCalculator._();

  /// Working precision for the inclusive-mode division, far beyond any currency's scale.
  static const int _divisionScale = 12;

  /// Computes one line.
  static CalculatedLine line(
    LineInput input, {
    required TaxMode taxMode,
    required int minorUnits,
  }) {
    final extended = input.quantity * input.unitPrice;

    if (taxMode == TaxMode.exclusive) {
      final net = _round(extended, minorUnits);
      final tax = _round(net * input.taxRate, minorUnits);
      return CalculatedLine(
        netAmount: net,
        taxAmount: tax,
        grossAmount: net + tax,
      );
    }

    final gross = _round(extended, minorUnits);
    final divisor = Decimal.one + input.taxRate;
    final net = _round(
      (gross / divisor).toDecimal(scaleOnInfinitePrecision: _divisionScale),
      minorUnits,
    );
    return CalculatedLine(
      netAmount: net,
      taxAmount: gross - net,
      grossAmount: gross,
    );
  }

  /// Computes every line and the invoice totals.
  ///
  /// [lines] may be empty, which yields zero totals rather than an error — an invoice with no
  /// lines is a perfectly valid draft.
  static CalculatedInvoice invoice({
    required List<LineInput> lines,
    required TaxMode taxMode,
    required int currencyMinorUnits,
    required Decimal exchangeRate,
    required int baseCurrencyMinorUnits,
  }) {
    final calculated = <CalculatedLine>[];
    var subtotal = Decimal.zero;
    var taxTotal = Decimal.zero;
    var grandTotal = Decimal.zero;

    for (final input in lines) {
      final result = line(input, taxMode: taxMode, minorUnits: currencyMinorUnits);
      calculated.add(result);
      subtotal += result.netAmount;
      taxTotal += result.taxAmount;
      grandTotal += result.grossAmount;
    }

    return CalculatedInvoice(
      lines: List.unmodifiable(calculated),
      subtotal: subtotal,
      taxTotal: taxTotal,
      grandTotal: grandTotal,
      grandTotalBase: _round(grandTotal * exchangeRate, baseCurrencyMinorUnits),
    );
  }

  /// Half-up to [scale] decimal places.
  ///
  /// `Decimal.round` rounds half away from zero, which is the same thing for the non-negative
  /// amounts this app deals in — quantities are validated as positive and prices as non-negative,
  /// on both sides of the wire.
  static Decimal _round(Decimal value, int scale) => value.round(scale: scale);
}
