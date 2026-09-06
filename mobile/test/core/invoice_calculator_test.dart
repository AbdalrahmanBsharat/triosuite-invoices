import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:triosuite_invoices/core/money/invoice_calculator.dart';
import 'package:triosuite_invoices/core/money/tax_mode.dart';

/// The on-device totals preview, checked against the **same figures as the server's own test
/// suite**.
///
/// That is the whole point of this file. `InvoiceCalculatorTest.java` and this test assert the same
/// expected values for the same inputs, so if either implementation is changed without the other,
/// one of the two builds fails. A preview that quietly disagrees with the saved invoice by a cent
/// is worse than no preview at all, and this is what stops that happening.
void main() {
  const ils = 2;
  const usd = 2;
  const jod = 3;

  final rateOne = Decimal.parse('1.000000');

  LineInput line(String quantity, String unitPrice, String taxRate) => LineInput(
        quantity: Decimal.parse(quantity),
        unitPrice: Decimal.parse(unitPrice),
        taxRate: Decimal.parse(taxRate),
      );

  void expectDecimal(Decimal actual, String expected, {String? reason}) {
    expect(
      actual,
      Decimal.parse(expected),
      reason: reason ?? 'expected $expected but was $actual',
    );
  }

  group('EXCLUSIVE — the unit price is net and tax is added on top', () {
    test('whole quantities at 16%', () {
      final result = InvoiceCalculator.line(
        line('2', '1299.0000', '0.1600'),
        taxMode: TaxMode.exclusive,
        minorUnits: ils,
      );

      expectDecimal(result.netAmount, '2598.00');
      expectDecimal(result.taxAmount, '415.68');
      expectDecimal(result.grossAmount, '3013.68');
    });

    test('fractional quantity', () {
      final result = InvoiceCalculator.line(
        line('2.500', '45.9000', '0.1600'),
        taxMode: TaxMode.exclusive,
        minorUnits: ils,
      );

      expectDecimal(result.netAmount, '114.75');
      expectDecimal(result.taxAmount, '18.36');
      expectDecimal(result.grossAmount, '133.11');
    });

    test('zero tax rate leaves gross equal to net', () {
      final result = InvoiceCalculator.line(
        line('5', '1800.0000', '0.0000'),
        taxMode: TaxMode.exclusive,
        minorUnits: ils,
      );

      expectDecimal(result.netAmount, '9000.00');
      expectDecimal(result.taxAmount, '0.00');
      expectDecimal(result.grossAmount, '9000.00');
    });

    test('three-decimal currency keeps three decimals', () {
      final result = InvoiceCalculator.line(
        line('6', '223.3010', '0.1600'),
        taxMode: TaxMode.exclusive,
        minorUnits: jod,
      );

      expectDecimal(result.netAmount, '1339.806');
      expectDecimal(result.taxAmount, '214.369');
      expectDecimal(result.grossAmount, '1554.175');
      expect(result.netAmount.scale, jod);
    });
  });

  group('INCLUSIVE — the unit price already contains the tax', () {
    test('net is extracted from a round gross', () {
      final result = InvoiceCalculator.line(
        line('1', '100.0000', '0.1600'),
        taxMode: TaxMode.inclusive,
        minorUnits: ils,
      );

      expectDecimal(result.grossAmount, '100.00');
      expectDecimal(result.netAmount, '86.21');
      expectDecimal(result.taxAmount, '13.79');
    });

    test('recurring division still balances', () {
      final result = InvoiceCalculator.line(
        line('3', '45.9000', '0.1600'),
        taxMode: TaxMode.inclusive,
        minorUnits: ils,
      );

      expectDecimal(result.grossAmount, '137.70');
      expectDecimal(result.netAmount, '118.71');
      expectDecimal(result.taxAmount, '18.99');
    });

    test('zero tax rate leaves net equal to gross', () {
      final result = InvoiceCalculator.line(
        line('4', '220.0000', '0.0000'),
        taxMode: TaxMode.inclusive,
        minorUnits: ils,
      );

      expectDecimal(result.netAmount, '880.00');
      expectDecimal(result.taxAmount, '0.00');
      expectDecimal(result.grossAmount, '880.00');
    });

    test('three-decimal currency keeps three decimals', () {
      final result = InvoiceCalculator.line(
        line('2', '475.7280', '0.1600'),
        taxMode: TaxMode.inclusive,
        minorUnits: jod,
      );

      expectDecimal(result.grossAmount, '951.456');
      expectDecimal(result.netAmount, '820.221');
      expectDecimal(result.taxAmount, '131.235');
    });
  });

  group('Rounding is half-up, per line, to the currency minor units', () {
    test('an exact half on the extended amount rounds away from zero', () {
      final result = InvoiceCalculator.line(
        line('1', '2.0050', '0.0000'),
        taxMode: TaxMode.exclusive,
        minorUnits: ils,
      );

      expectDecimal(result.netAmount, '2.01');
    });

    test('an exact half on the tax amount rounds away from zero', () {
      final result = InvoiceCalculator.line(
        line('1', '10.1000', '0.1500'),
        taxMode: TaxMode.exclusive,
        minorUnits: ils,
      );

      expectDecimal(result.netAmount, '10.10');
      expectDecimal(result.taxAmount, '1.52');
      expectDecimal(result.grossAmount, '11.62');
    });

    // The same table as the server's parameterised rounding test.
    const cases = <List<String>>[
      ['1', '0.0050', '0.0000', '0.01', '0.00', '0.01'],
      ['1', '0.0049', '0.0000', '0.00', '0.00', '0.00'],
      ['3', '0.3350', '0.0000', '1.01', '0.00', '1.01'],
      ['1', '99.9950', '0.0000', '100.00', '0.00', '100.00'],
      ['7', '1.4285', '0.1600', '10.00', '1.60', '11.60'],
    ];

    for (final row in cases) {
      test('${row[0]} x ${row[1]} @ ${row[2]} -> ${row[3]} / ${row[4]} / ${row[5]}', () {
        final result = InvoiceCalculator.line(
          line(row[0], row[1], row[2]),
          taxMode: TaxMode.exclusive,
          minorUnits: ils,
        );

        expectDecimal(result.netAmount, row[3]);
        expectDecimal(result.taxAmount, row[4]);
        expectDecimal(result.grossAmount, row[5]);
      });
    }

    test('per-line rounding drift is visible and intentional', () {
      final lines = List.generate(10, (_) => line('1', '0.0050', '0.0000'));

      final invoice = InvoiceCalculator.invoice(
        lines: lines,
        taxMode: TaxMode.exclusive,
        currencyMinorUnits: ils,
        exchangeRate: rateOne,
        baseCurrencyMinorUnits: ils,
      );

      // Ten lines that each round 0.005 up to 0.01. Rounding the sum instead would give 0.05.
      expectDecimal(invoice.subtotal, '0.10');
      expectDecimal(invoice.grandTotal, '0.10');
    });
  });

  group('Invariants that must hold for every input', () {
    for (final mode in TaxMode.values) {
      for (final minorUnits in [2, 3]) {
        test('net + tax equals gross on every line (${mode.name}, $minorUnits dp)', () {
          final invoice = InvoiceCalculator.invoice(
            lines: [
              line('1', '0.0100', '0.1600'),
              line('2.375', '19.9900', '0.1600'),
              line('13', '7.7700', '0.0500'),
              line('1', '1000000.0000', '0.1600'),
              line('0.001', '0.0100', '0.1600'),
            ],
            taxMode: mode,
            currencyMinorUnits: minorUnits,
            exchangeRate: rateOne,
            baseCurrencyMinorUnits: minorUnits,
          );

          for (final calculated in invoice.lines) {
            expect(
              calculated.netAmount + calculated.taxAmount,
              calculated.grossAmount,
              reason: 'net + tax must equal gross',
            );
          }
        });
      }
    }

    test('invoice totals are the sum of the already-rounded lines', () {
      final invoice = InvoiceCalculator.invoice(
        lines: [
          line('3', '19.9900', '0.1600'),
          line('7', '4.4500', '0.1600'),
          line('1.5', '88.8800', '0.0000'),
          line('11', '0.9900', '0.1600'),
          line('2', '1234.5600', '0.1600'),
        ],
        taxMode: TaxMode.exclusive,
        currencyMinorUnits: ils,
        exchangeRate: rateOne,
        baseCurrencyMinorUnits: ils,
      );

      final summedNet = invoice.lines
          .map((line) => line.netAmount)
          .fold(Decimal.zero, (a, b) => a + b);
      final summedTax = invoice.lines
          .map((line) => line.taxAmount)
          .fold(Decimal.zero, (a, b) => a + b);
      final summedGross = invoice.lines
          .map((line) => line.grossAmount)
          .fold(Decimal.zero, (a, b) => a + b);

      expect(invoice.subtotal, summedNet);
      expect(invoice.taxTotal, summedTax);
      expect(invoice.grandTotal, summedGross);
      expect(invoice.subtotal + invoice.taxTotal, invoice.grandTotal);
    });

    test('an invoice with no lines has zero totals', () {
      final invoice = InvoiceCalculator.invoice(
        lines: const [],
        taxMode: TaxMode.exclusive,
        currencyMinorUnits: jod,
        exchangeRate: Decimal.parse('3.650000'),
        baseCurrencyMinorUnits: ils,
      );

      expect(invoice.lines, isEmpty);
      expect(invoice.subtotal, Decimal.zero);
      expect(invoice.taxTotal, Decimal.zero);
      expect(invoice.grandTotal, Decimal.zero);
      expect(invoice.grandTotalBase, Decimal.zero);
    });

    test('line results are returned in input order', () {
      final invoice = InvoiceCalculator.invoice(
        lines: [
          line('1', '10.0000', '0.0000'),
          line('1', '20.0000', '0.0000'),
          line('1', '30.0000', '0.0000'),
        ],
        taxMode: TaxMode.exclusive,
        currencyMinorUnits: ils,
        exchangeRate: rateOne,
        baseCurrencyMinorUnits: ils,
      );

      expect(
        invoice.lines.map((line) => line.grossAmount).toList(),
        [Decimal.parse('10.00'), Decimal.parse('20.00'), Decimal.parse('30.00')],
      );
    });
  });

  group('grandTotalBase converts at the invoice exchange rate', () {
    test('a rate of 1 leaves the total untouched', () {
      final invoice = InvoiceCalculator.invoice(
        lines: [line('2', '50.0000', '0.1600')],
        taxMode: TaxMode.exclusive,
        currencyMinorUnits: ils,
        exchangeRate: rateOne,
        baseCurrencyMinorUnits: ils,
      );

      expectDecimal(invoice.grandTotal, '116.00');
      expectDecimal(invoice.grandTotalBase, '116.00');
    });

    test('a USD invoice reports in ILS at 3.65', () {
      final invoice = InvoiceCalculator.invoice(
        lines: [line('1', '100.0000', '0.0000')],
        taxMode: TaxMode.exclusive,
        currencyMinorUnits: usd,
        exchangeRate: Decimal.parse('3.650000'),
        baseCurrencyMinorUnits: ils,
      );

      expectDecimal(invoice.grandTotal, '100.00');
      expectDecimal(invoice.grandTotalBase, '365.00');
    });

    test('conversion rounds to the base currency scale, not the invoice one', () {
      final invoice = InvoiceCalculator.invoice(
        lines: [line('1', '100.0000', '0.0000')],
        taxMode: TaxMode.exclusive,
        currencyMinorUnits: usd,
        exchangeRate: Decimal.parse('0.194175'),
        baseCurrencyMinorUnits: jod,
      );

      // 100.00 x 0.194175 = 19.4175 -> 19.418 at three decimals.
      expectDecimal(invoice.grandTotalBase, '19.418');
      expect(invoice.grandTotalBase.scale, jod);
    });

    test('a three-decimal invoice reports into a two-decimal base currency', () {
      final invoice = InvoiceCalculator.invoice(
        lines: [line('3', '10.1250', '0.0000')],
        taxMode: TaxMode.exclusive,
        currencyMinorUnits: jod,
        exchangeRate: Decimal.parse('5.150000'),
        baseCurrencyMinorUnits: ils,
      );

      expectDecimal(invoice.grandTotal, '30.375');
      expectDecimal(invoice.grandTotalBase, '156.43');
    });
  });

  test('the same catalogue price yields a higher gross exclusive than inclusive', () {
    final input = line('4', '250.0000', '0.1600');

    final exclusive =
        InvoiceCalculator.line(input, taxMode: TaxMode.exclusive, minorUnits: ils);
    final inclusive =
        InvoiceCalculator.line(input, taxMode: TaxMode.inclusive, minorUnits: ils);

    expectDecimal(exclusive.grossAmount, '1160.00');
    expectDecimal(inclusive.grossAmount, '1000.00');
    expectDecimal(exclusive.netAmount, '1000.00');
    expectDecimal(inclusive.netAmount, '862.07');
    expect(exclusive.grossAmount > inclusive.grossAmount, isTrue);
  });

  test('a realistic mixed invoice matches the figures the server produces', () {
    final invoice = InvoiceCalculator.invoice(
      lines: [
        line('2', '4299.0000', '0.1600'), // laptops
        line('2', '89.9000', '0.1600'), // mice
        line('10', '22.5000', '0.1600'), // paper
        line('1', '1800.0000', '0.0000'), // zero-rated licence
      ],
      taxMode: TaxMode.exclusive,
      currencyMinorUnits: ils,
      exchangeRate: rateOne,
      baseCurrencyMinorUnits: ils,
    );

    // toStringAsFixed, not toString: Dart's Decimal normalises away trailing zeros, so 8598.00
    // prints as "8598". That is a rendering difference, not an arithmetic one — the values are
    // identical to the server's — and it is why every amount reaches the UI through
    // MoneyFormat, which pads to the currency's minor units.
    expect(
      invoice.lines.map((line) => line.netAmount.toStringAsFixed(2)).join(', '),
      '8598.00, 179.80, 225.00, 1800.00',
    );
    expectDecimal(invoice.subtotal, '10802.80');
    expectDecimal(invoice.taxTotal, '1440.45');
    expectDecimal(invoice.grandTotal, '12243.25');
    expectDecimal(invoice.grandTotalBase, '12243.25');
  });

  test('reproduces the seeded JOD invoice exactly', () {
    // INV-2026-000003 from database/seed.sql, recomputed here.
    final invoice = InvoiceCalculator.invoice(
      lines: [
        line('6', '223.3010', '0.1600'),
        line('2', '475.7280', '0.1600'),
      ],
      taxMode: TaxMode.exclusive,
      currencyMinorUnits: jod,
      exchangeRate: Decimal.parse('5.150000'),
      baseCurrencyMinorUnits: ils,
    );

    expectDecimal(invoice.subtotal, '2291.262');
    expectDecimal(invoice.taxTotal, '366.602');
    expectDecimal(invoice.grandTotal, '2657.864');
    expectDecimal(invoice.grandTotalBase, '13688.00');
  });
}
