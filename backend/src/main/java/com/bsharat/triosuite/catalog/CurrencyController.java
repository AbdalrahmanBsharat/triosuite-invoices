package com.bsharat.triosuite.catalog;

import com.bsharat.triosuite.catalog.dto.CurrencyResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** The currencies an invoice may be issued in. */
@RestController
@RequestMapping("/api/currencies")
@RequiredArgsConstructor
@Tag(name = "Currencies", description = "Currencies available for invoicing")
public class CurrencyController {

    private final CatalogService catalog;

    @GetMapping
    @Operation(
            summary = "List active currencies",
            description = """
                    Returns every active currency with its symbol and minor units. The app uses
                    minorUnits to round its live totals preview exactly as the server will.""")
    public List<CurrencyResponse> list() {
        return catalog.listCurrencies();
    }
}
