package com.bsharat.triosuite.catalog;

import com.bsharat.triosuite.catalog.dto.ExchangeRateResponse;
import com.bsharat.triosuite.catalog.dto.UpdateExchangeRateRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Pattern;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** The exchange rates suggested when a new invoice is created. */
@Validated
@RestController
@RequestMapping("/api/exchange-rates")
@RequiredArgsConstructor
@Tag(name = "Exchange rates", description = "Suggested conversion rates to the base currency")
public class ExchangeRateController {

    private final CatalogService catalog;

    @GetMapping
    @Operation(
            summary = "List exchange rates",
            description = """
                    Each rate is how many base-currency units one unit of that currency is worth.
                    The Create Invoice screen pre-fills from here, and the user may override the
                    value per invoice.""")
    public List<ExchangeRateResponse> list() {
        return catalog.listExchangeRates();
    }

    @PutMapping("/{currencyCode}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(
            summary = "Set an exchange rate",
            description = """
                    Updates the rate suggested for one currency. Invoices already issued are
                    unaffected: each keeps the rate it snapshotted when it was saved.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Rate updated"),
            @ApiResponse(responseCode = "403", description = "Caller is not an administrator", content = @Content),
            @ApiResponse(responseCode = "404", description = "Unknown currency", content = @Content)
    })
    public ExchangeRateResponse update(
            @PathVariable @Pattern(regexp = "[A-Za-z]{3}", message = "must be a three-letter code")
            String currencyCode,
            @Valid @RequestBody UpdateExchangeRateRequest request) {

        return catalog.updateExchangeRate(currencyCode, request.rateToBase());
    }
}
