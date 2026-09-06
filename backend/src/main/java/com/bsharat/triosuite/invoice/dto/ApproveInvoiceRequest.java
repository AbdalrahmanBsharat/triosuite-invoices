package com.bsharat.triosuite.invoice.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

/**
 * Body of POST /api/invoices/{id}/approve.
 *
 * @param version the version last read by the client; a mismatch yields 409 STALE_VERSION
 */
@Schema(name = "ApproveInvoiceRequest")
public record ApproveInvoiceRequest(
        @NotNull @PositiveOrZero @Schema(example = "0") Long version) {
}
