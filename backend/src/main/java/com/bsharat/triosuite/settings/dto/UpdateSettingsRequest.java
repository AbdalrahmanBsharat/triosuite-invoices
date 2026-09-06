package com.bsharat.triosuite.settings.dto;

import com.bsharat.triosuite.invoice.TaxMode;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

/**
 * Body of PUT /api/settings (ADMIN only).
 *
 * @param baseCurrencyCode    reporting currency; must be an active currency
 * @param defaultCurrencyCode currency pre-selected on a new invoice; must be an active currency
 * @param defaultTaxMode      tax mode pre-selected on a new invoice
 * @param defaultTaxRate      fallback tax rate, between 0 and 1 inclusive
 * @param invoiceNumberPrefix upper-case letters and digits only, so numbers stay sortable
 */
@Schema(name = "UpdateSettingsRequest")
public record UpdateSettingsRequest(
        @NotBlank @Size(min = 3, max = 3) @Schema(example = "ILS") String baseCurrencyCode,
        @NotBlank @Size(min = 3, max = 3) @Schema(example = "ILS") String defaultCurrencyCode,
        @NotNull TaxMode defaultTaxMode,
        @NotNull @DecimalMin("0.0") @DecimalMax("1.0") @Digits(integer = 1, fraction = 4)
        @Schema(example = "0.1600") BigDecimal defaultTaxRate,
        @NotBlank @Size(min = 1, max = 10)
        @Pattern(regexp = "[A-Z0-9]+", message = "must contain only upper-case letters and digits")
        @Schema(example = "INV") String invoiceNumberPrefix) {
}
