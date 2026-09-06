package com.bsharat.triosuite.catalog.dto;

import com.bsharat.triosuite.catalog.Currency;
import io.swagger.v3.oas.annotations.media.Schema;

/**
 * A currency the app may issue invoices in.
 *
 * @param code       ISO 4217 code
 * @param name       display name
 * @param symbol     symbol used when formatting amounts
 * @param minorUnits decimal places; the app rounds its live preview to this
 * @param active     whether new invoices may use it
 */
@Schema(name = "Currency")
public record CurrencyResponse(
        @Schema(example = "USD") String code,
        @Schema(example = "US Dollar") String name,
        @Schema(example = "$") String symbol,
        @Schema(example = "2") int minorUnits,
        boolean active) {

    public static CurrencyResponse from(Currency currency) {
        return new CurrencyResponse(currency.getCode(), currency.getName(), currency.getSymbol(),
                currency.getMinorUnits(), currency.isActive());
    }
}
