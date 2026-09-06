package com.bsharat.triosuite.invoice;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import org.springframework.stereotype.Component;

/**
 * The single source of truth for invoice arithmetic.
 *
 * <p>Pure and stateless: every input arrives as an argument and nothing is cached, so the class can
 * be unit-tested with {@code new InvoiceCalculator()} and no Spring context. The server calls it on
 * every create and every update and stores what it returns — totals sent by a client are read for
 * nothing but comparison and are otherwise ignored.
 *
 * <p><b>Rounding.</b> {@link RoundingMode#HALF_UP} applied <em>per line</em>, to the invoice
 * currency's minor units (2 for ILS/USD/EUR/GBP, 3 for JOD). Invoice totals are the sum of the
 * already-rounded line amounts, never a re-rounding of an unrounded sum, so
 * {@code Σ lines == invoice total} holds exactly. See ADR-0003.
 *
 * <p><b>Formulas.</b> With {@code q} = quantity, {@code p} = unit price and {@code r} = tax rate:
 * <ul>
 *   <li>{@link TaxMode#EXCLUSIVE}: {@code net = round(q·p)}, {@code tax = round(net·r)},
 *       {@code gross = net + tax}</li>
 *   <li>{@link TaxMode#INCLUSIVE}: {@code gross = round(q·p)}, {@code net = round(gross / (1 + r))},
 *       {@code tax = gross − net}</li>
 * </ul>
 * In both modes {@code gross} is derived by addition or subtraction rather than by a second
 * rounding, which is what keeps {@code net + tax == gross} true for every line.
 */
@Component
public class InvoiceCalculator {

    /** Intermediate scale for the inclusive-mode division, well beyond any currency's precision. */
    private static final int DIVISION_SCALE = 12;

    /**
     * One line as submitted by a client, before any arithmetic.
     *
     * @param quantity  units sold; must be greater than zero
     * @param unitPrice price per unit, net or gross depending on the invoice's tax mode
     * @param taxRate   tax rate as a decimal fraction, e.g. {@code 0.1600} for 16%
     */
    public record LineInput(BigDecimal quantity, BigDecimal unitPrice, BigDecimal taxRate) {

        public LineInput {
            Objects.requireNonNull(quantity, "quantity");
            Objects.requireNonNull(unitPrice, "unitPrice");
            Objects.requireNonNull(taxRate, "taxRate");
        }
    }

    /**
     * A line after rounding. {@code netAmount + taxAmount == grossAmount} always holds.
     *
     * @param netAmount   amount excluding tax
     * @param taxAmount   tax on this line
     * @param grossAmount amount including tax
     */
    public record CalculatedLine(BigDecimal netAmount, BigDecimal taxAmount, BigDecimal grossAmount) {
    }

    /**
     * A whole invoice after rounding.
     *
     * @param lines          per-line results, positionally matching the input
     * @param subtotal       Σ net
     * @param taxTotal       Σ tax
     * @param grandTotal     Σ gross
     * @param grandTotalBase {@code grandTotal × exchangeRate}, rounded to the base currency
     */
    public record CalculatedInvoice(
            List<CalculatedLine> lines,
            BigDecimal subtotal,
            BigDecimal taxTotal,
            BigDecimal grandTotal,
            BigDecimal grandTotalBase) {

        public CalculatedInvoice {
            lines = List.copyOf(lines);
        }
    }

    /**
     * Computes one line.
     *
     * @param line        quantity, unit price and tax rate
     * @param taxMode     whether {@code unitPrice} is net or gross
     * @param minorUnits  decimal places of the invoice currency
     * @return the rounded net, tax and gross amounts
     */
    public CalculatedLine calculateLine(LineInput line, TaxMode taxMode, int minorUnits) {
        Objects.requireNonNull(line, "line");
        Objects.requireNonNull(taxMode, "taxMode");

        BigDecimal extended = line.quantity().multiply(line.unitPrice());
        BigDecimal net;
        BigDecimal tax;
        BigDecimal gross;

        if (taxMode == TaxMode.EXCLUSIVE) {
            net = extended.setScale(minorUnits, RoundingMode.HALF_UP);
            tax = net.multiply(line.taxRate()).setScale(minorUnits, RoundingMode.HALF_UP);
            gross = net.add(tax);
        } else {
            gross = extended.setScale(minorUnits, RoundingMode.HALF_UP);
            BigDecimal divisor = BigDecimal.ONE.add(line.taxRate());
            net = gross.divide(divisor, DIVISION_SCALE, RoundingMode.HALF_UP)
                    .setScale(minorUnits, RoundingMode.HALF_UP);
            tax = gross.subtract(net);
        }

        return new CalculatedLine(net, tax, gross);
    }

    /**
     * Computes every line and the invoice totals.
     *
     * @param lines                  the lines to price; may be empty, which yields zero totals
     * @param taxMode                whether unit prices are net or gross
     * @param currencyMinorUnits     decimal places of the invoice currency
     * @param exchangeRate           base-currency units per one invoice-currency unit
     * @param baseCurrencyMinorUnits decimal places of the base (reporting) currency
     * @return the rounded lines and totals
     */
    public CalculatedInvoice calculate(
            List<LineInput> lines,
            TaxMode taxMode,
            int currencyMinorUnits,
            BigDecimal exchangeRate,
            int baseCurrencyMinorUnits) {

        Objects.requireNonNull(lines, "lines");
        Objects.requireNonNull(exchangeRate, "exchangeRate");

        List<CalculatedLine> calculated = new ArrayList<>(lines.size());
        BigDecimal subtotal = zero(currencyMinorUnits);
        BigDecimal taxTotal = zero(currencyMinorUnits);
        BigDecimal grandTotal = zero(currencyMinorUnits);

        for (LineInput line : lines) {
            CalculatedLine result = calculateLine(line, taxMode, currencyMinorUnits);
            calculated.add(result);
            subtotal = subtotal.add(result.netAmount());
            taxTotal = taxTotal.add(result.taxAmount());
            grandTotal = grandTotal.add(result.grossAmount());
        }

        BigDecimal grandTotalBase = grandTotal.multiply(exchangeRate)
                .setScale(baseCurrencyMinorUnits, RoundingMode.HALF_UP);

        return new CalculatedInvoice(calculated, subtotal, taxTotal, grandTotal, grandTotalBase);
    }

    private static BigDecimal zero(int minorUnits) {
        return BigDecimal.ZERO.setScale(minorUnits, RoundingMode.UNNECESSARY);
    }
}
