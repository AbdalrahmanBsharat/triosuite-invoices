package com.bsharat.triosuite.settings.dto;

import com.bsharat.triosuite.invoice.TaxMode;
import com.bsharat.triosuite.settings.AppSettings;
import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.Instant;

/**
 * Company-wide defaults, read by every client on start-up.
 *
 * @param baseCurrencyCode    reporting currency; every invoice also reports its total in this
 * @param defaultCurrencyCode currency pre-selected on a new invoice
 * @param defaultTaxMode      tax mode pre-selected on a new invoice
 * @param defaultTaxRate      rate used when an item carries none
 * @param invoiceNumberPrefix the INV in INV-2026-000001
 * @param updatedAt           when settings were last changed, UTC
 */
@Schema(name = "Settings")
public record SettingsResponse(
        @Schema(example = "ILS") String baseCurrencyCode,
        @Schema(example = "ILS") String defaultCurrencyCode,
        TaxMode defaultTaxMode,
        @Schema(example = "0.1600") BigDecimal defaultTaxRate,
        @Schema(example = "INV") String invoiceNumberPrefix,
        Instant updatedAt) {

    public static SettingsResponse from(AppSettings settings) {
        return new SettingsResponse(
                settings.getBaseCurrency().getCode(),
                settings.getDefaultCurrency().getCode(),
                settings.getDefaultTaxMode(),
                settings.getDefaultTaxRate(),
                settings.getInvoiceNumberPrefix(),
                settings.getUpdatedAt());
    }
}
