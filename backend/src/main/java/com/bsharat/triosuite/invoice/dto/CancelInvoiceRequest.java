package com.bsharat.triosuite.invoice.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

/**
 * Body of POST /api/invoices/{id}/cancel.
 *
 * @param version the version last read by the client; a mismatch yields 409 STALE_VERSION
 * @param reason  optional free text recorded against the cancellation
 */
@Schema(name = "CancelInvoiceRequest")
public record CancelInvoiceRequest(
        @NotNull @PositiveOrZero @Schema(example = "1") Long version,
        @Size(max = 500) @Schema(example = "Customer postponed the rollout.") String reason) {
}
