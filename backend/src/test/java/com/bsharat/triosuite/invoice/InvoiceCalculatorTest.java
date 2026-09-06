package com.bsharat.triosuite.invoice;

import static org.assertj.core.api.Assertions.assertThat;

import com.bsharat.triosuite.invoice.InvoiceCalculator.CalculatedInvoice;
import com.bsharat.triosuite.invoice.InvoiceCalculator.CalculatedLine;
import com.bsharat.triosuite.invoice.InvoiceCalculator.LineInput;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

/**
 * Pure unit tests for the calculation engine. No Spring context, no database, no mocks.
 *
 * <p>Minor units used below: 2 for ILS/USD/EUR/GBP, 3 for JOD.
 */
class InvoiceCalculatorTest {

    private static final int ILS = 2;
    private static final int USD = 2;
    private static final int JOD = 3;

    private static final BigDecimal RATE_ONE = new BigDecimal("1.000000");

    private final InvoiceCalculator calculator = new InvoiceCalculator();

    private static LineInput line(String quantity, String unitPrice, String taxRate) {
        return new LineInput(new BigDecimal(quantity), new BigDecimal(unitPrice), new BigDecimal(taxRate));
    }

    // =================================================================================
    // Tax-exclusive mode
    // =================================================================================

    @Nested
    @DisplayName("EXCLUSIVE — the unit price is net and tax is added on top")
    class Exclusive {

        @Test
        @DisplayName("whole quantities at 16%")
        void wholeQuantities() {
            CalculatedLine result = calculator.calculateLine(line("2", "1299.0000", "0.1600"), TaxMode.EXCLUSIVE, ILS);

            assertThat(result.netAmount()).isEqualByComparingTo("2598.00");
            assertThat(result.taxAmount()).isEqualByComparingTo("415.68");
            assertThat(result.grossAmount()).isEqualByComparingTo("3013.68");
        }

        @Test
        @DisplayName("fractional quantity")
        void fractionalQuantity() {
            CalculatedLine result = calculator.calculateLine(line("2.500", "45.9000", "0.1600"), TaxMode.EXCLUSIVE, ILS);

            // 2.5 x 45.90 = 114.75 exactly; 114.75 x 0.16 = 18.36 exactly.
            assertThat(result.netAmount()).isEqualByComparingTo("114.75");
            assertThat(result.taxAmount()).isEqualByComparingTo("18.36");
            assertThat(result.grossAmount()).isEqualByComparingTo("133.11");
        }

        @Test
        @DisplayName("zero tax rate leaves gross equal to net")
        void zeroTaxRate() {
            CalculatedLine result = calculator.calculateLine(line("5", "1800.0000", "0.0000"), TaxMode.EXCLUSIVE, ILS);

            assertThat(result.netAmount()).isEqualByComparingTo("9000.00");
            assertThat(result.taxAmount()).isEqualByComparingTo("0.00");
            assertThat(result.grossAmount()).isEqualByComparingTo("9000.00");
        }

        @Test
        @DisplayName("three-decimal currency keeps three decimals")
        void threeDecimalCurrency() {
            CalculatedLine result = calculator.calculateLine(line("6", "223.3010", "0.1600"), TaxMode.EXCLUSIVE, JOD);

            // 6 x 223.301 = 1339.806; 1339.806 x 0.16 = 214.36896 -> 214.369
            assertThat(result.netAmount()).isEqualByComparingTo("1339.806");
            assertThat(result.taxAmount()).isEqualByComparingTo("214.369");
            assertThat(result.grossAmount()).isEqualByComparingTo("1554.175");
            assertThat(result.netAmount().scale()).isEqualTo(3);
        }
    }

    // =================================================================================
    // Tax-inclusive mode
    // =================================================================================

    @Nested
    @DisplayName("INCLUSIVE — the unit price already contains the tax")
    class Inclusive {

        @Test
        @DisplayName("net is extracted from a round gross")
        void extractsNetFromGross() {
            CalculatedLine result = calculator.calculateLine(line("1", "100.0000", "0.1600"), TaxMode.INCLUSIVE, ILS);

            // 100 / 1.16 = 86.2068965... -> 86.21, tax is the remainder.
            assertThat(result.grossAmount()).isEqualByComparingTo("100.00");
            assertThat(result.netAmount()).isEqualByComparingTo("86.21");
            assertThat(result.taxAmount()).isEqualByComparingTo("13.79");
        }

        @Test
        @DisplayName("recurring division still balances")
        void recurringDivision() {
            CalculatedLine result = calculator.calculateLine(line("3", "45.9000", "0.1600"), TaxMode.INCLUSIVE, ILS);

            // 3 x 45.90 = 137.70; 137.70 / 1.16 = 118.70689... -> 118.71
            assertThat(result.grossAmount()).isEqualByComparingTo("137.70");
            assertThat(result.netAmount()).isEqualByComparingTo("118.71");
            assertThat(result.taxAmount()).isEqualByComparingTo("18.99");
        }

        @Test
        @DisplayName("zero tax rate leaves net equal to gross")
        void zeroTaxRate() {
            CalculatedLine result = calculator.calculateLine(line("4", "220.0000", "0.0000"), TaxMode.INCLUSIVE, ILS);

            assertThat(result.netAmount()).isEqualByComparingTo("880.00");
            assertThat(result.taxAmount()).isEqualByComparingTo("0.00");
            assertThat(result.grossAmount()).isEqualByComparingTo("880.00");
        }

        @Test
        @DisplayName("three-decimal currency keeps three decimals")
        void threeDecimalCurrency() {
            CalculatedLine result = calculator.calculateLine(line("2", "475.7280", "0.1600"), TaxMode.INCLUSIVE, JOD);

            // 2 x 475.728 = 951.456; 951.456 / 1.16 = 820.2206896... -> 820.221
            assertThat(result.grossAmount()).isEqualByComparingTo("951.456");
            assertThat(result.netAmount()).isEqualByComparingTo("820.221");
            assertThat(result.taxAmount()).isEqualByComparingTo("131.235");
        }
    }

    // =================================================================================
    // Rounding
    // =================================================================================

    @Nested
    @DisplayName("Rounding is HALF_UP, per line, to the currency's minor units")
    class Rounding {

        @Test
        @DisplayName("an exact half on the extended amount rounds away from zero")
        void extendedAmountHalfRoundsUp() {
            // 1 x 2.0050 -> 2.005, which is exactly half a cent.
            CalculatedLine result = calculator.calculateLine(line("1", "2.0050", "0.0000"), TaxMode.EXCLUSIVE, ILS);

            assertThat(result.netAmount()).isEqualByComparingTo("2.01");
        }

        @Test
        @DisplayName("an exact half on the tax amount rounds away from zero")
        void taxAmountHalfRoundsUp() {
            // net 10.10 x 0.15 = 1.5150 -> 1.52, not 1.51.
            CalculatedLine result = calculator.calculateLine(line("1", "10.1000", "0.1500"), TaxMode.EXCLUSIVE, ILS);

            assertThat(result.netAmount()).isEqualByComparingTo("10.10");
            assertThat(result.taxAmount()).isEqualByComparingTo("1.52");
            assertThat(result.grossAmount()).isEqualByComparingTo("11.62");
        }

        @ParameterizedTest(name = "{0} x {1} @ {2} -> net {3}, tax {4}, gross {5}")
        @DisplayName("documented rounding cases")
        @CsvSource({
                // quantity, unitPrice, taxRate, net,    tax,   gross
                "1,     0.0050, 0.0000, 0.01,   0.00,  0.01",
                "1,     0.0049, 0.0000, 0.00,   0.00,  0.00",
                "3,     0.3350, 0.0000, 1.01,   0.00,  1.01",
                "1,    99.9950, 0.0000, 100.00, 0.00,  100.00",
                "7,     1.4285, 0.1600, 10.00,  1.60,  11.60",
        })
        void roundingTable(String quantity, String unitPrice, String taxRate,
                           String net, String tax, String gross) {
            CalculatedLine result =
                    calculator.calculateLine(line(quantity, unitPrice, taxRate), TaxMode.EXCLUSIVE, ILS);

            assertThat(result.netAmount()).isEqualByComparingTo(net);
            assertThat(result.taxAmount()).isEqualByComparingTo(tax);
            assertThat(result.grossAmount()).isEqualByComparingTo(gross);
        }

        @Test
        @DisplayName("per-line rounding drift is visible and intentional")
        void perLineRoundingDrift() {
            // Ten lines that each round 0.005 up to 0.01. Rounding the sum instead would give 0.05.
            List<LineInput> lines = new ArrayList<>();
            for (int i = 0; i < 10; i++) {
                lines.add(line("1", "0.0050", "0.0000"));
            }

            CalculatedInvoice invoice =
                    calculator.calculate(lines, TaxMode.EXCLUSIVE, ILS, RATE_ONE, ILS);

            assertThat(invoice.subtotal()).isEqualByComparingTo("0.10");
            assertThat(invoice.grandTotal()).isEqualByComparingTo("0.10");
        }
    }

    // =================================================================================
    // Invariants
    // =================================================================================

    @Nested
    @DisplayName("Invariants that must hold for every input")
    class Invariants {

        @ParameterizedTest(name = "{0}, minorUnits={1}")
        @CsvSource({
                "EXCLUSIVE, 2",
                "EXCLUSIVE, 3",
                "INCLUSIVE, 2",
                "INCLUSIVE, 3",
        })
        @DisplayName("net + tax equals gross on every line")
        void netPlusTaxEqualsGross(TaxMode mode, int minorUnits) {
            List<LineInput> lines = List.of(
                    line("1", "0.0100", "0.1600"),
                    line("2.375", "19.9900", "0.1600"),
                    line("13", "7.7700", "0.0500"),
                    line("1", "1000000.0000", "0.1600"),
                    line("0.001", "0.0100", "0.1600"));

            CalculatedInvoice invoice =
                    calculator.calculate(lines, mode, minorUnits, RATE_ONE, minorUnits);

            for (CalculatedLine calculatedLine : invoice.lines()) {
                assertThat(calculatedLine.netAmount().add(calculatedLine.taxAmount()))
                        .isEqualByComparingTo(calculatedLine.grossAmount());
            }
        }

        @Test
        @DisplayName("invoice totals are the sum of the already-rounded lines")
        void totalsAreTheSumOfRoundedLines() {
            List<LineInput> lines = List.of(
                    line("3", "19.9900", "0.1600"),
                    line("7", "4.4500", "0.1600"),
                    line("1.5", "88.8800", "0.0000"),
                    line("11", "0.9900", "0.1600"),
                    line("2", "1234.5600", "0.1600"));

            CalculatedInvoice invoice =
                    calculator.calculate(lines, TaxMode.EXCLUSIVE, ILS, RATE_ONE, ILS);

            assertThat(invoice.subtotal())
                    .isEqualByComparingTo(sum(invoice, CalculatedLine::netAmount));
            assertThat(invoice.taxTotal())
                    .isEqualByComparingTo(sum(invoice, CalculatedLine::taxAmount));
            assertThat(invoice.grandTotal())
                    .isEqualByComparingTo(sum(invoice, CalculatedLine::grossAmount));
            assertThat(invoice.subtotal().add(invoice.taxTotal()))
                    .isEqualByComparingTo(invoice.grandTotal());
        }

        @Test
        @DisplayName("line results are returned in input order")
        void preservesLineOrder() {
            List<LineInput> lines = List.of(
                    line("1", "10.0000", "0.0000"),
                    line("1", "20.0000", "0.0000"),
                    line("1", "30.0000", "0.0000"));

            CalculatedInvoice invoice =
                    calculator.calculate(lines, TaxMode.EXCLUSIVE, ILS, RATE_ONE, ILS);

            assertThat(invoice.lines())
                    .extracting(CalculatedLine::grossAmount)
                    .containsExactly(
                            new BigDecimal("10.00"), new BigDecimal("20.00"), new BigDecimal("30.00"));
        }

        @Test
        @DisplayName("an invoice with no lines has zero totals at the currency's scale")
        void emptyInvoice() {
            CalculatedInvoice invoice =
                    calculator.calculate(List.of(), TaxMode.EXCLUSIVE, JOD, new BigDecimal("3.650000"), ILS);

            assertThat(invoice.lines()).isEmpty();
            assertThat(invoice.subtotal()).isEqualByComparingTo("0");
            assertThat(invoice.taxTotal()).isEqualByComparingTo("0");
            assertThat(invoice.grandTotal()).isEqualByComparingTo("0");
            assertThat(invoice.grandTotalBase()).isEqualByComparingTo("0");
            assertThat(invoice.subtotal().scale()).isEqualTo(JOD);
            assertThat(invoice.grandTotalBase().scale()).isEqualTo(ILS);
        }

        @Test
        @DisplayName("the returned line list is immutable")
        void lineListIsImmutable() {
            CalculatedInvoice invoice = calculator.calculate(
                    List.of(line("1", "1.0000", "0.0000")), TaxMode.EXCLUSIVE, ILS, RATE_ONE, ILS);

            assertThat(invoice.lines()).isUnmodifiable();
        }

        private BigDecimal sum(CalculatedInvoice invoice,
                               java.util.function.Function<CalculatedLine, BigDecimal> field) {
            return invoice.lines().stream()
                    .map(field)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
        }
    }

    // =================================================================================
    // Base-currency conversion
    // =================================================================================

    @Nested
    @DisplayName("grandTotalBase converts at the invoice's snapshotted rate")
    class BaseCurrencyConversion {

        @Test
        @DisplayName("a rate of 1 leaves the total untouched")
        void rateOfOne() {
            CalculatedInvoice invoice = calculator.calculate(
                    List.of(line("2", "50.0000", "0.1600")), TaxMode.EXCLUSIVE, ILS, RATE_ONE, ILS);

            assertThat(invoice.grandTotal()).isEqualByComparingTo("116.00");
            assertThat(invoice.grandTotalBase()).isEqualByComparingTo("116.00");
        }

        @Test
        @DisplayName("a USD invoice reports in ILS at 3.65")
        void usdInvoiceInIls() {
            CalculatedInvoice invoice = calculator.calculate(
                    List.of(line("1", "100.0000", "0.0000")),
                    TaxMode.EXCLUSIVE, USD, new BigDecimal("3.650000"), ILS);

            assertThat(invoice.grandTotal()).isEqualByComparingTo("100.00");
            assertThat(invoice.grandTotalBase()).isEqualByComparingTo("365.00");
        }

        @Test
        @DisplayName("conversion rounds to the base currency's minor units, not the invoice's")
        void roundsToBaseCurrencyScale() {
            // A 2-decimal invoice reporting into a 3-decimal base currency.
            CalculatedInvoice invoice = calculator.calculate(
                    List.of(line("1", "100.0000", "0.0000")),
                    TaxMode.EXCLUSIVE, USD, new BigDecimal("0.194175"), JOD);

            // 100.00 x 0.194175 = 19.4175 -> 19.418 at three decimals.
            assertThat(invoice.grandTotalBase()).isEqualByComparingTo("19.418");
            assertThat(invoice.grandTotalBase().scale()).isEqualTo(JOD);
        }

        @Test
        @DisplayName("a three-decimal invoice reports into a two-decimal base currency")
        void jodInvoiceInIls() {
            CalculatedInvoice invoice = calculator.calculate(
                    List.of(line("3", "10.1250", "0.0000")),
                    TaxMode.EXCLUSIVE, JOD, new BigDecimal("5.150000"), ILS);

            // 3 x 10.125 = 30.375 JOD; 30.375 x 5.15 = 156.43125 -> 156.43
            assertThat(invoice.grandTotal()).isEqualByComparingTo("30.375");
            assertThat(invoice.grandTotalBase()).isEqualByComparingTo("156.43");
        }
    }

    // =================================================================================
    // The two modes side by side
    // =================================================================================

    @Test
    @DisplayName("the same catalogue price yields a higher gross exclusive than inclusive")
    void modesDifferAsExpected() {
        LineInput input = line("4", "250.0000", "0.1600");

        CalculatedLine exclusive = calculator.calculateLine(input, TaxMode.EXCLUSIVE, ILS);
        CalculatedLine inclusive = calculator.calculateLine(input, TaxMode.INCLUSIVE, ILS);

        assertThat(exclusive.grossAmount()).isEqualByComparingTo("1160.00");
        assertThat(inclusive.grossAmount()).isEqualByComparingTo("1000.00");
        assertThat(exclusive.netAmount()).isEqualByComparingTo("1000.00");
        assertThat(inclusive.netAmount()).isEqualByComparingTo("862.07");
        assertThat(exclusive.grossAmount()).isGreaterThan(inclusive.grossAmount());
    }

    @Test
    @DisplayName("a realistic mixed invoice matches hand-computed figures")
    void realisticMixedInvoice() {
        List<LineInput> lines = List.of(
                line("2", "4299.0000", "0.1600"),   // laptops
                line("2", "89.9000", "0.1600"),     // mice
                line("10", "22.5000", "0.1600"),    // paper
                line("1", "1800.0000", "0.0000"));  // zero-rated licence

        CalculatedInvoice invoice =
                calculator.calculate(lines, TaxMode.EXCLUSIVE, ILS, RATE_ONE, ILS);

        assertThat(invoice.lines().stream()
                .map(CalculatedLine::netAmount)
                .map(BigDecimal::toPlainString)
                .collect(Collectors.joining(", ")))
                .isEqualTo("8598.00, 179.80, 225.00, 1800.00");

        assertThat(invoice.subtotal()).isEqualByComparingTo("10802.80");
        assertThat(invoice.taxTotal()).isEqualByComparingTo("1440.45");
        assertThat(invoice.grandTotal()).isEqualByComparingTo("12243.25");
        assertThat(invoice.grandTotalBase()).isEqualByComparingTo("12243.25");
    }
}
