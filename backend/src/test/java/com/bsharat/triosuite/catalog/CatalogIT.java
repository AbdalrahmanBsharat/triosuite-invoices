package com.bsharat.triosuite.catalog;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.bsharat.triosuite.support.AbstractIntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;

/** Reference data: currencies, rates, customers, items and the barcode lookup. */
class CatalogIT extends AbstractIntegrationTest {

    // =================================================================================
    // Barcode
    // =================================================================================

    @Test
    @DisplayName("a seeded barcode resolves to its item")
    void barcodeLookupFindsTheItem() throws Exception {
        mockMvc.perform(get("/api/items/by-barcode/7290001000014")
                        .header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.sku").value("LAP-1401"))
                .andExpect(jsonPath("$.name").value("Business Laptop 14\""))
                .andExpect(jsonPath("$.barcode").value("7290001000014"))
                .andExpect(jsonPath("$.unitPrice").value(4299.0000))
                .andExpect(jsonPath("$.taxRate").value(0.1600))
                .andExpect(jsonPath("$.currencyCode").value("ILS"));
    }

    @Test
    @DisplayName("an unknown barcode is 404, which the scanner treats as 'item not found'")
    void barcodeLookupReturnsNotFound() throws Exception {
        mockMvc.perform(get("/api/items/by-barcode/9999999999999")
                        .header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_FOUND"));
    }

    @Test
    @DisplayName("a barcode containing characters no scanner emits is rejected as invalid input")
    void barcodeLookupRejectsJunk() throws Exception {
        mockMvc.perform(get("/api/items/by-barcode/' OR 1=1--")
                        .header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    // =================================================================================
    // Items
    // =================================================================================

    @Test
    @DisplayName("the catalogue lists all fifteen seeded items")
    void itemSearchListsEverything() throws Exception {
        mockMvc.perform(get("/api/items")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .param("size", "100"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(15))
                .andExpect(jsonPath("$.content.length()").value(15));
    }

    @Test
    @DisplayName("item search matches on name, SKU and barcode, case-insensitively")
    void itemSearchMatchesSeveralFields() throws Exception {
        String token = adminToken();

        mockMvc.perform(get("/api/items").header(HttpHeaders.AUTHORIZATION, token)
                        .param("search", "laptop"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].sku").value("LAP-1401"));

        mockMvc.perform(get("/api/items").header(HttpHeaders.AUTHORIZATION, token)
                        .param("search", "tnr-4401"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].name").value("Toner Cartridge Black"));

        mockMvc.perform(get("/api/items").header(HttpHeaders.AUTHORIZATION, token)
                        .param("search", "7290001000151"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].sku").value("WRT-0024"));
    }

    @Test
    @DisplayName("a search that matches nothing returns an empty page, not an error")
    void itemSearchCanReturnNothing() throws Exception {
        mockMvc.perform(get("/api/items")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .param("search", "there-is-no-such-item"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(0))
                .andExpect(jsonPath("$.content").isEmpty());
    }

    // =================================================================================
    // Customers
    // =================================================================================

    @Test
    @DisplayName("customer search returns only active customers")
    void customerSearchExcludesInactive() throws Exception {
        mockMvc.perform(get("/api/customers")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .param("size", "100"))
                .andExpect(status().isOk())
                // Six are seeded; Sahara Logistics is inactive.
                .andExpect(jsonPath("$.totalElements").value(5))
                .andExpect(jsonPath("$.content[*].name").value(
                        not(hasItem("Sahara Logistics"))));
    }

    @Test
    @DisplayName("customer search matches part of a name")
    void customerSearchMatchesName() throws Exception {
        mockMvc.perform(get("/api/customers")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .param("search", "quds"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].name").value("Al-Quds Trading Co."));
    }

    // =================================================================================
    // Currencies and rates
    // =================================================================================

    @Test
    @DisplayName("currencies carry the minor units the app rounds its preview with")
    void currenciesExposeMinorUnits() throws Exception {
        mockMvc.perform(get("/api/currencies").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(5))
                .andExpect(jsonPath("$[?(@.code == 'JOD')].minorUnits").value(
                        hasItem(3)))
                .andExpect(jsonPath("$[?(@.code == 'ILS')].minorUnits").value(
                        hasItem(2)))
                .andExpect(jsonPath("$[?(@.code == 'ILS')].symbol").value(
                        hasItem("₪")));
    }

    @Test
    @DisplayName("the base currency sits at a rate of exactly 1")
    void baseCurrencyRateIsOne() throws Exception {
        mockMvc.perform(get("/api/exchange-rates").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(5))
                .andExpect(jsonPath("$[?(@.currencyCode == 'ILS')].rateToBase").value(
                        hasItem(1.000000)))
                .andExpect(jsonPath("$[?(@.currencyCode == 'USD')].rateToBase").value(
                        hasItem(3.650000)));
    }

    // =================================================================================
    // Pagination
    // =================================================================================

    @Test
    @DisplayName("pages report their own size and the total")
    void paginationReportsItself() throws Exception {
        mockMvc.perform(get("/api/items")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .param("page", "1")
                        .param("size", "4"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(1))
                .andExpect(jsonPath("$.size").value(4))
                .andExpect(jsonPath("$.totalElements").value(15))
                .andExpect(jsonPath("$.totalPages").value(4))
                .andExpect(jsonPath("$.content.length()").value(4));
    }

    @Test
    @DisplayName("an oversized page request is capped rather than honoured")
    void pageSizeIsCapped() throws Exception {
        mockMvc.perform(get("/api/items")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .param("size", "5000"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.size").value(100));
    }
}
