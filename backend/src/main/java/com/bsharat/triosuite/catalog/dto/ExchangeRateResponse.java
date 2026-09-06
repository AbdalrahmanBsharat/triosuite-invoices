package com.bsharat.triosuite.catalog.dto;

import com.bsharat.triosuite.catalog.CurrencyExchangeRate;
import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;

/**
 * The rate suggested for a currency when a new invoice is created.
 *
 * @param currencyCode the currency this rate is for
 * @param rateToBase   base-currency units per one unit of currencyCode
 * @param updatedAt    when the rate was last maintained, UTC
 */
@Schema(name = "ExchangeRate")
public record ExchangeRateResponse(
        @Schema(example = "USD") String currencyCode,
        @Schema(example = "3.650000") BigDecimal rateToBase,
        Instant updatedAt) {

    public static ExchangeRateResponse from(CurrencyExchangeRate rate) {
        return new ExchangeRateResponse(rate.getCurrencyCode(), rate.getRateToBase(), rate.getUpdatedAt());
    }
}
