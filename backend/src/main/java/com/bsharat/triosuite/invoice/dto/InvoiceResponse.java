package com.bsharat.triosuite.invoice.dto;

import com.bsharat.triosuite.invoice.Invoice;
import com.bsharat.triosuite.invoice.InvoiceStatus;
import com.bsharat.triosuite.invoice.TaxMode;
import com.bsharat.triosuite.user.User;
import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/**
 * A full invoice: header, lines, server-computed totals and the audit trail.
 *
 * <p>{@code version} must be echoed back on update, approve and cancel. {@code currencyMinorUnits}
 * and {@code baseCurrencyCode} are included so the app can format amounts and render the
 * base-currency total without a second round trip.
 *
 * @param id                  invoice identifier
 * @param invoiceNumber       the allocated number, e.g. INV-2026-000001
 * @param status              DRAFT, APPROVED or CANCELLED
 * @param version             optimistic lock; send this back on every mutating call
 * @param customerId          who is billed
 * @param customerName        name of the customer at read time
 * @param currencyCode        invoice currency
 * @param currencySymbol      symbol for formatting amounts
 * @param currencyMinorUnits  decimal places of the invoice currency
 * @param exchangeRate        snapshotted base-currency units per one invoice-currency unit
 * @param baseCurrencyCode    the reporting currency grandTotalBase is expressed in
 * @param taxMode             EXCLUSIVE or INCLUSIVE
 * @param issueDate           document date
 * @param notes               free text
 * @param subtotal            sum of the rounded line net amounts
 * @param taxTotal            sum of the rounded line tax amounts
 * @param grandTotal          sum of the rounded line gross amounts
 * @param grandTotalBase      grandTotal converted at exchangeRate
 * @param lines               the priced lines, in line-number order
 * @param createdBy           who created the invoice
 * @param createdAt           when it was created, UTC
 * @param approvedBy          who approved it, if it has been
 * @param approvedAt          when it was approved, UTC
 * @param cancelledBy         who cancelled it, if it has been
 * @param cancelledAt         when it was cancelled, UTC
 * @param cancellationReason  why it was cancelled, if a reason was given
 * @param updatedAt           when the record last changed, UTC
 */
@Schema(name = "Invoice")
public record InvoiceResponse(
        Long id,
        @Schema(example = "INV-2026-000001") String invoiceNumber,
        InvoiceStatus status,
        @Schema(example = "0") Long version,

        Long customerId,
        String customerName,

        @Schema(example = "USD") String currencyCode,
        @Schema(example = "$") String currencySymbol,
        @Schema(example = "2") int currencyMinorUnits,
        @Schema(example = "3.650000") BigDecimal exchangeRate,
        @Schema(example = "ILS") String baseCurrencyCode,

        TaxMode taxMode,
        LocalDate issueDate,
        String notes,

        BigDecimal subtotal,
        BigDecimal taxTotal,
        BigDecimal grandTotal,
        BigDecimal grandTotalBase,

        List<InvoiceLineResponse> lines,

        String createdBy,
        Instant createdAt,
        String approvedBy,
        Instant approvedAt,
        String cancelledBy,
        Instant cancelledAt,
        String cancellationReason,
        Instant updatedAt) {

    /**
     * Maps a loaded invoice onto its response.
     *
     * @param invoice          the aggregate, with lines and associations reachable
     * @param baseCurrencyCode the reporting currency from application settings
     */
    public static InvoiceResponse from(Invoice invoice, String baseCurrencyCode) {
        return new InvoiceResponse(
                invoice.getId(),
                invoice.getInvoiceNumber(),
                invoice.getStatus(),
                invoice.getVersion(),
                invoice.getCustomer().getId(),
                invoice.getCustomer().getName(),
                invoice.getCurrency().getCode(),
                invoice.getCurrency().getSymbol(),
                invoice.getCurrency().getMinorUnits(),
                invoice.getExchangeRate(),
                baseCurrencyCode,
                invoice.getTaxMode(),
                invoice.getIssueDate(),
                invoice.getNotes(),
                invoice.getSubtotal(),
                invoice.getTaxTotal(),
                invoice.getGrandTotal(),
                invoice.getGrandTotalBase(),
                invoice.getLines().stream().map(InvoiceLineResponse::from).toList(),
                nameOf(invoice.getCreatedBy()),
                invoice.getCreatedAt(),
                nameOf(invoice.getApprovedBy()),
                invoice.getApprovedAt(),
                nameOf(invoice.getCancelledBy()),
                invoice.getCancelledAt(),
                invoice.getCancellationReason(),
                invoice.getUpdatedAt());
    }

    private static String nameOf(User user) {
        return user == null ? null : user.getFullName();
    }
}
