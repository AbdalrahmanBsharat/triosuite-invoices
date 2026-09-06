package com.bsharat.triosuite.invoice;

import static org.assertj.core.api.Assertions.assertThat;

import com.bsharat.triosuite.invoice.InvoiceCalculator.CalculatedInvoice;
import com.bsharat.triosuite.invoice.InvoiceCalculator.LineInput;
import com.bsharat.triosuite.settings.SettingsService;
import com.bsharat.triosuite.support.AbstractIntegrationTest;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;

/**
 * Re-derives every seeded invoice with the production calculator and compares it against what
 * {@code V2__seed.sql} actually stored.
 *
 * <p>Hand-written demo data is the classic place for arithmetic to rot: someone tweaks a price, the
 * totals are not recomputed, and the reviewer's first screen shows an invoice that does not add up.
 * This test makes that impossible to miss.
 */
class SeededInvoiceTotalsIT extends AbstractIntegrationTest {

    @Autowired
    private InvoiceRepository invoices;

    @Autowired
    private InvoiceCalculator calculator;

    @Autowired
    private SettingsService settingsService;

    @Test
    @Transactional
    @DisplayName("every seeded invoice matches what the calculator produces from its own lines")
    void seededTotalsMatchTheCalculator() {
        int baseMinorUnits = settingsService.require().getBaseCurrency().getMinorUnits();
        List<Invoice> seeded = invoices.findAll();

        assertThat(seeded).as("the seed must provide six sample invoices").hasSize(6);

        for (Invoice invoice : seeded) {
            List<LineInput> inputs = invoice.getLines().stream()
                    .map(line -> new LineInput(
                            line.getQuantity(), line.getUnitPrice(), line.getTaxRate()))
                    .toList();

            CalculatedInvoice recomputed = calculator.calculate(
                    inputs,
                    invoice.getTaxMode(),
                    invoice.getCurrency().getMinorUnits(),
                    invoice.getExchangeRate(),
                    baseMinorUnits);

            String context = invoice.getInvoiceNumber();
            assertThat(invoice.getSubtotal())
                    .as("%s subtotal", context).isEqualByComparingTo(recomputed.subtotal());
            assertThat(invoice.getTaxTotal())
                    .as("%s tax total", context).isEqualByComparingTo(recomputed.taxTotal());
            assertThat(invoice.getGrandTotal())
                    .as("%s grand total", context).isEqualByComparingTo(recomputed.grandTotal());
            assertThat(invoice.getGrandTotalBase())
                    .as("%s grand total in base currency", context)
                    .isEqualByComparingTo(recomputed.grandTotalBase());

            for (int i = 0; i < invoice.getLines().size(); i++) {
                InvoiceLine stored = invoice.getLines().get(i);
                assertThat(stored.getNetAmount())
                        .as("%s line %d net", context, stored.getLineNo())
                        .isEqualByComparingTo(recomputed.lines().get(i).netAmount());
                assertThat(stored.getTaxAmount())
                        .as("%s line %d tax", context, stored.getLineNo())
                        .isEqualByComparingTo(recomputed.lines().get(i).taxAmount());
                assertThat(stored.getGrossAmount())
                        .as("%s line %d gross", context, stored.getLineNo())
                        .isEqualByComparingTo(recomputed.lines().get(i).grossAmount());
            }
        }
    }

    @Test
    @Transactional
    @DisplayName("the seed covers all three statuses, both tax modes and more than one currency")
    void seedCoversTheInterestingCases() {
        List<Invoice> seeded = invoices.findAll();

        assertThat(seeded).extracting(Invoice::getStatus)
                .contains(InvoiceStatus.DRAFT, InvoiceStatus.APPROVED, InvoiceStatus.CANCELLED);
        assertThat(seeded).extracting(Invoice::getTaxMode)
                .contains(TaxMode.EXCLUSIVE, TaxMode.INCLUSIVE);
        assertThat(seeded).extracting(invoice -> invoice.getCurrency().getCode())
                .contains("ILS", "USD", "JOD", "EUR", "GBP");
        assertThat(seeded).allSatisfy(invoice ->
                assertThat(invoice.getLines()).as("%s lines", invoice.getInvoiceNumber()).isNotEmpty());
    }

    @Test
    @Transactional
    @DisplayName("every seeded barcode is a valid EAN-13")
    void seededBarcodesHaveCorrectCheckDigits() {
        List<String> barcodes = invoices.findAll().stream()
                .flatMap(invoice -> invoice.getLines().stream())
                .map(InvoiceLine::getBarcodeSnapshot)
                .filter(java.util.Objects::nonNull)
                .distinct()
                .toList();

        assertThat(barcodes).isNotEmpty();
        assertThat(barcodes).allSatisfy(barcode -> {
            assertThat(barcode).as("length").hasSize(13);
            assertThat(barcode.charAt(12) - '0')
                    .as("check digit of %s", barcode)
                    .isEqualTo(ean13CheckDigit(barcode.substring(0, 12)));
        });
    }

    /** Standard EAN-13 modulo-10 check digit over the leading twelve digits. */
    private static int ean13CheckDigit(String twelveDigits) {
        int sum = 0;
        for (int i = 0; i < 12; i++) {
            int digit = twelveDigits.charAt(i) - '0';
            sum += (i % 2 == 0) ? digit : digit * 3;
        }
        return (10 - (sum % 10)) % 10;
    }
}
