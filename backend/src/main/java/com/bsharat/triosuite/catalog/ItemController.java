package com.bsharat.triosuite.catalog;

import com.bsharat.triosuite.catalog.dto.ItemResponse;
import com.bsharat.triosuite.common.web.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Catalogue lookup, by search and by barcode. */
@Validated
@RestController
@RequestMapping("/api/items")
@RequiredArgsConstructor
@Tag(name = "Items", description = "The catalogue that invoice lines are built from")
public class ItemController {

    private final CatalogService catalog;

    @GetMapping
    @Operation(
            summary = "Search items",
            description = """
                    Active items only, matched case-insensitively on name, SKU or barcode.
                    Omit the search term to list the whole catalogue.""")
    public PageResponse<ItemResponse> search(
            @Parameter(description = "Free-text term matched against name, SKU and barcode")
            @RequestParam(required = false) String search,
            @PageableDefault(size = 20, sort = "name", direction = Sort.Direction.ASC) Pageable pageable) {

        return catalog.searchItems(search, pageable);
    }

    @GetMapping("/by-barcode/{barcode}")
    @Operation(
            summary = "Look an item up by barcode",
            description = """
                    Exact match on the scanned code. This is what the scanner sheet calls after each
                    detection; a 404 is expected and simply means the code is not in the catalogue,
                    so the app reports it and keeps scanning.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "The item carrying this barcode"),
            @ApiResponse(responseCode = "404", description = "No item carries this barcode", content = @Content)
    })
    public ItemResponse byBarcode(
            @Parameter(description = "The scanned code, e.g. an EAN-13", example = "7290001000014")
            @PathVariable @Size(min = 1, max = 64)
            @Pattern(regexp = "[A-Za-z0-9._-]+", message = "contains characters that are not valid in a barcode")
            String barcode) {

        return catalog.findByBarcode(barcode);
    }
}
