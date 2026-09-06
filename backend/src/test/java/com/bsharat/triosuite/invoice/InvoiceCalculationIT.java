package com.bsharat.triosuite.invoice;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.bsharat.triosuite.support.AbstractIntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

/**
 * The calculation engine as reached through the API.
 *
 * <p>{@code InvoiceCalculatorTest} already proves the arithmetic in isolation. What is proved here
 * is the wiring: that the currency's minor units, the item's tax rate and the invoice's snapshotted
 * exchange rate are the values actually fed to it, and that what comes back is what gets stored.
 */
class InvoiceCalculationIT extends AbstractIntegrationTest {

    @Test
    @DisplayName("EXCLUSIVE: tax is added on top of the unit price")
    void exclusiveTaxIsAddedOnTop() throws Exception {
        mockMvc.perform(post("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerId": %d,
                                  "currencyCode": "ILS",
                                  "exchangeRate": "1.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": [
                                    {"itemId": %d, "quantity": "2.000", "unitPrice": "4299.0000"},
                                    {"itemId": %d, "quantity": "10.000", "unitPrice": "22.5000"}
                                  ]
                                }""".formatted(CUSTOMER_ACTIVE, ITEM_LAPTOP, ITEM_PAPER)))
                .andExpect(status().isCreated())
                // 2 x 4299.00 = 8598.00 net, tax 1375.68; 10 x 22.50 = 225.00 net, tax 36.00
                .andExpect(jsonPath("$.lines[0].netAmount").value(8598.00))
                .andExpect(jsonPath("$.lines[0].taxAmount").value(1375.68))
                .andExpect(jsonPath("$.lines[0].grossAmount").value(9973.68))
                .andExpect(jsonPath("$.lines[1].netAmount").value(225.00))
                .andExpect(jsonPath("$.lines[1].taxAmount").value(36.00))
                .andExpect(jsonPath("$.lines[1].grossAmount").value(261.00))
                .andExpect(jsonPath("$.subtotal").value(8823.00))
                .andExpect(jsonPath("$.taxTotal").value(1411.68))
                .andExpect(jsonPath("$.grandTotal").value(10234.68));
    }

    @Test
    @DisplayName("INCLUSIVE: the net amount is extracted from a unit price that already contains tax")
    void inclusiveTaxIsExtracted() throws Exception {
        mockMvc.perform(post("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerId": %d,
                                  "currencyCode": "USD",
                                  "exchangeRate": "3.650000",
                                  "taxMode": "INCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": [
                                    {"itemId": %d, "quantity": "1.000", "unitPrice": "100.0000"}
                                  ]
                                }""".formatted(CUSTOMER_ACTIVE, ITEM_LAPTOP)))
                .andExpect(status().isCreated())
                // 100.00 gross; 100 / 1.16 = 86.2068... -> 86.21 net; tax is the remainder.
                .andExpect(jsonPath("$.lines[0].grossAmount").value(100.00))
                .andExpect(jsonPath("$.lines[0].netAmount").value(86.21))
                .andExpect(jsonPath("$.lines[0].taxAmount").value(13.79))
                .andExpect(jsonPath("$.grandTotal").value(100.00))
                // 100.00 USD x 3.65 = 365.00 ILS
                .andExpect(jsonPath("$.grandTotalBase").value(365.00))
                .andExpect(jsonPath("$.baseCurrencyCode").value("ILS"));
    }

    @Test
    @DisplayName("a three-decimal currency keeps three decimals and still converts to a two-decimal base")
    void threeDecimalCurrency() throws Exception {
        mockMvc.perform(post("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerId": %d,
                                  "currencyCode": "JOD",
                                  "exchangeRate": "5.150000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": [
                                    {"itemId": %d, "quantity": "6.000", "unitPrice": "223.3010"}
                                  ]
                                }""".formatted(CUSTOMER_ACTIVE, ITEM_LAPTOP)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.currencyMinorUnits").value(3))
                // 6 x 223.301 = 1339.806; tax 214.36896 -> 214.369
                .andExpect(jsonPath("$.lines[0].netAmount").value(1339.806))
                .andExpect(jsonPath("$.lines[0].taxAmount").value(214.369))
                .andExpect(jsonPath("$.lines[0].grossAmount").value(1554.175))
                .andExpect(jsonPath("$.grandTotal").value(1554.175))
                // 1554.175 x 5.15 = 8004.00125 -> 8004.00 in the two-decimal base currency
                .andExpect(jsonPath("$.grandTotalBase").value(8004.00));
    }

    @Test
    @DisplayName("a zero-rated item produces no tax in either mode")
    void zeroRatedItem() throws Exception {
        mockMvc.perform(post("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerId": %d,
                                  "currencyCode": "ILS",
                                  "exchangeRate": "1.000000",
                                  "taxMode": "INCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": [
                                    {"itemId": %d, "quantity": "3.000", "unitPrice": "1800.0000"}
                                  ]
                                }""".formatted(CUSTOMER_ACTIVE, ITEM_ZERO_RATED)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.lines[0].taxRate").value(0.0000))
                .andExpect(jsonPath("$.lines[0].netAmount").value(5400.00))
                .andExpect(jsonPath("$.lines[0].taxAmount").value(0.00))
                .andExpect(jsonPath("$.lines[0].grossAmount").value(5400.00))
                .andExpect(jsonPath("$.taxTotal").value(0.00));
    }

    @Test
    @DisplayName("the line's tax rate comes from the catalogue, not from the request")
    void taxRateIsTakenFromTheItem() throws Exception {
        mockMvc.perform(post("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerId": %d,
                                  "currencyCode": "ILS",
                                  "exchangeRate": "1.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": [
                                    {"itemId": %d, "quantity": "1.000", "unitPrice": "100.0000",
                                     "taxRate": "0.0000"}
                                  ]
                                }""".formatted(CUSTOMER_ACTIVE, ITEM_LAPTOP)))
                .andExpect(status().isCreated())
                // The item is rated at 16%; the 0% in the request must have no effect.
                .andExpect(jsonPath("$.lines[0].taxRate").value(0.1600))
                .andExpect(jsonPath("$.lines[0].taxAmount").value(16.00))
                .andExpect(jsonPath("$.grandTotal").value(116.00));
    }

    @Test
    @DisplayName("totals sent by the client are ignored and recomputed")
    void clientSuppliedTotalsAreIgnored() throws Exception {
        mockMvc.perform(post("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerId": %d,
                                  "currencyCode": "ILS",
                                  "exchangeRate": "1.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "subtotal": "1.00",
                                  "taxTotal": "0.00",
                                  "grandTotal": "1.00",
                                  "grandTotalBase": "1.00",
                                  "lines": [
                                    {"itemId": %d, "quantity": "1.000", "unitPrice": "100.0000",
                                     "netAmount": "1.00", "taxAmount": "0.00", "grossAmount": "1.00"}
                                  ]
                                }""".formatted(CUSTOMER_ACTIVE, ITEM_LAPTOP)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.subtotal").value(100.00))
                .andExpect(jsonPath("$.taxTotal").value(16.00))
                .andExpect(jsonPath("$.grandTotal").value(116.00))
                .andExpect(jsonPath("$.lines[0].grossAmount").value(116.00));
    }

    @Test
    @DisplayName("a user-supplied exchange rate overrides the maintained one and is snapshotted")
    void userSuppliedExchangeRateIsUsed() throws Exception {
        mockMvc.perform(post("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerId": %d,
                                  "currencyCode": "USD",
                                  "exchangeRate": "4.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": [
                                    {"itemId": %d, "quantity": "1.000", "unitPrice": "100.0000"}
                                  ]
                                }""".formatted(CUSTOMER_ACTIVE, ITEM_ZERO_RATED)))
                .andExpect(status().isCreated())
                // The maintained USD rate is 3.65; the invoice must use the 4.00 the user typed.
                .andExpect(jsonPath("$.exchangeRate").value(4.000000))
                .andExpect(jsonPath("$.grandTotal").value(100.00))
                .andExpect(jsonPath("$.grandTotalBase").value(400.00));
    }

    @Test
    @DisplayName("line snapshots record the item name and barcode as they were")
    void lineSnapshotsAreWritten() throws Exception {
        mockMvc.perform(post("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerId": %d,
                                  "currencyCode": "ILS",
                                  "exchangeRate": "1.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": [
                                    {"itemId": %d, "quantity": "1.000", "unitPrice": "4299.0000"}
                                  ]
                                }""".formatted(CUSTOMER_ACTIVE, ITEM_LAPTOP)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.lines[0].itemId").value((int) ITEM_LAPTOP))
                .andExpect(jsonPath("$.lines[0].itemName").value("Business Laptop 14\""))
                .andExpect(jsonPath("$.lines[0].barcode").value("7290001000014"))
                .andExpect(jsonPath("$.lines[0].lineNo").value(1));
    }
}
