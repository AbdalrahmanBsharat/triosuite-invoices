package com.bsharat.triosuite.catalog.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.math.BigDecimal;

/**
 * Body of PUT /api/exchange-rates/{currencyCode} (ADMIN only).
 *
 * @param rateToBase base-currency units per one unit of the addressed currency; must be positive
 */
@Schema(name = "UpdateExchangeRateRequest")
public record UpdateExchangeRateRequest(
        @NotNull @Positive @Digits(integer = 13, fraction = 6)
        @Schema(example = "3.650000") BigDecimal rateToBase) {
}
