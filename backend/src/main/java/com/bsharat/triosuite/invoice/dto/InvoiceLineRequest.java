package com.bsharat.triosuite.invoice.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

/**
 * One line as submitted by the app.
 *
 * <p>Notice what is absent: no tax rate, no line totals. The tax rate is taken from the item and
 * the amounts are computed by the server, so a client cannot mis-state either.
 *
 * @param itemId    catalogue item; must exist and be active
 * @param quantity  units sold; strictly greater than zero, up to three decimal places
 * @param unitPrice price per unit in the invoice currency, net or gross per the invoice tax mode
 */
@Schema(name = "InvoiceLineRequest")
public record InvoiceLineRequest(

        @NotNull @Schema(example = "1") Long itemId,

        @NotNull
        @DecimalMin(value = "0", inclusive = false, message = "must be greater than 0")
        @Digits(integer = 9, fraction = 3)
        @Schema(example = "2.000") BigDecimal quantity,

        @NotNull
        @DecimalMin(value = "0.0", message = "must not be negative")
        @Digits(integer = 15, fraction = 4)
        @Schema(example = "4299.0000") BigDecimal unitPrice) {
}
