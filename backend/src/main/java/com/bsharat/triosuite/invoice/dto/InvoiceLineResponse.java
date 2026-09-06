package com.bsharat.triosuite.invoice.dto;

import com.bsharat.triosuite.invoice.InvoiceLine;
import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;

/**
 * A priced line, as stored.
 *
 * <p>{@code itemName} and {@code barcode} are the snapshots taken when the line was written, not
 * the catalogue's current values, so an issued invoice always renders as it was issued.
 *
 * @param id           line identifier
 * @param lineNo       1-based position on the invoice
 * @param itemId       catalogue item this line came from
 * @param itemName     item name at the time the line was written
 * @param barcode      item barcode at the time the line was written
 * @param quantity     units sold
 * @param unitPrice    price per unit in the invoice currency
 * @param taxRate      tax rate applied, as a decimal fraction
 * @param netAmount    amount excluding tax, rounded to the currency
 * @param taxAmount    tax on this line, rounded to the currency
 * @param grossAmount  net + tax
 */
@Schema(name = "InvoiceLine")
public record InvoiceLineResponse(
        Long id,
        int lineNo,
        Long itemId,
        String itemName,
        String barcode,
        BigDecimal quantity,
        BigDecimal unitPrice,
        BigDecimal taxRate,
        BigDecimal netAmount,
        BigDecimal taxAmount,
        BigDecimal grossAmount) {

    public static InvoiceLineResponse from(InvoiceLine line) {
        return new InvoiceLineResponse(
                line.getId(),
                line.getLineNo(),
                line.getItem().getId(),
                line.getItemNameSnapshot(),
                line.getBarcodeSnapshot(),
                line.getQuantity(),
                line.getUnitPrice(),
                line.getTaxRate(),
                line.getNetAmount(),
                line.getTaxAmount(),
                line.getGrossAmount());
    }
}
