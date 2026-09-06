package com.bsharat.triosuite.invoice.dto;

import com.bsharat.triosuite.invoice.InvoiceStatus;
import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * A row of the invoice list.
 *
 * <p>Built by a JPQL constructor expression so listing a page costs exactly one query and never
 * loads an invoice's lines.
 *
 * @param id             invoice identifier
 * @param invoiceNumber  the allocated number
 * @param customerName   who is billed
 * @param issueDate      document date
 * @param currencyCode   invoice currency
 * @param currencySymbol symbol for formatting the total
 * @param grandTotal     total in the invoice currency
 * @param grandTotalBase the same total converted to the base currency, for mixed-currency sorting
 * @param status         DRAFT, APPROVED or CANCELLED
 */
@Schema(name = "InvoiceSummary")
public record InvoiceSummaryResponse(
        Long id,
        @Schema(example = "INV-2026-000001") String invoiceNumber,
        String customerName,
        LocalDate issueDate,
        @Schema(example = "ILS") String currencyCode,
        @Schema(example = "₪") String currencySymbol,
        BigDecimal grandTotal,
        BigDecimal grandTotalBase,
        InvoiceStatus status) {
}
