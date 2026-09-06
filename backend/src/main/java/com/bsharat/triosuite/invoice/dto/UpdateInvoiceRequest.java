package com.bsharat.triosuite.invoice.dto;

import com.bsharat.triosuite.invoice.TaxMode;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Body of PUT /api/invoices/{id}. Replaces the header and every line of a DRAFT.
 *
 * <p>The invoice number and status are not part of this contract: numbering is immutable and status
 * changes go through the approve and cancel endpoints.
 *
 * @param version      the version last read by the client; a mismatch yields 409 STALE_VERSION
 * @param customerId   who is billed; must exist and be active
 * @param currencyCode invoice currency; must exist and be active
 * @param exchangeRate base-currency units per one invoice-currency unit
 * @param taxMode      whether unit prices are net (EXCLUSIVE) or gross (INCLUSIVE)
 * @param issueDate    document date
 * @param notes        free text, at most 1000 characters
 * @param lines        the replacement lines; may be empty on a draft, at most 200
 */
@Schema(name = "UpdateInvoiceRequest")
public record UpdateInvoiceRequest(

        @NotNull @PositiveOrZero @Schema(example = "0") Long version,

        @NotNull @Schema(example = "1") Long customerId,

        @NotBlank @Size(min = 3, max = 3) @Schema(example = "USD") String currencyCode,

        @NotNull @Positive @Digits(integer = 13, fraction = 6)
        @Schema(example = "3.650000") BigDecimal exchangeRate,

        @NotNull TaxMode taxMode,

        @NotNull @Schema(example = "2026-09-06") LocalDate issueDate,

        @Size(max = 1000) String notes,

        @NotNull @Size(max = 200, message = "an invoice may not have more than 200 lines")
        @Valid List<InvoiceLineRequest> lines) {
}
