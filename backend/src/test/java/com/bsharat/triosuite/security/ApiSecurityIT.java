package com.bsharat.triosuite.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.bsharat.triosuite.support.AbstractIntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

/** Default-deny authentication and the role split between SALES and ADMIN. */
class ApiSecurityIT extends AbstractIntegrationTest {

    // =================================================================================
    // Authentication
    // =================================================================================

    @ParameterizedTest(name = "GET {0} without a token is 401")
    @ValueSource(strings = {
            "/api/invoices",
            "/api/invoices/1",
            "/api/customers",
            "/api/items",
            "/api/items/by-barcode/7290001000014",
            "/api/currencies",
            "/api/exchange-rates",
            "/api/settings",
            "/api/auth/me"
    })
    @DisplayName("every protected endpoint refuses an anonymous caller")
    void protectedEndpointsRequireAToken(String path) throws Exception {
        mockMvc.perform(get(path))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("a forged or tampered token is refused")
    void tamperedTokenIsRefused() throws Exception {
        String token = adminToken();
        // Flip the last character of the signature.
        char last = token.charAt(token.length() - 1);
        String tampered = token.substring(0, token.length() - 1) + (last == 'A' ? 'B' : 'A');

        mockMvc.perform(get("/api/invoices").header(HttpHeaders.AUTHORIZATION, tampered))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("a header that is not a bearer token is refused")
    void nonBearerAuthorizationIsRefused() throws Exception {
        mockMvc.perform(get("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, "Basic YWRtaW46QWRtaW4jMjAyNg=="))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("the health probe and the API documentation stay anonymous")
    void publicEndpointsStayPublic() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));

        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("the health probe does not disclose component details to an anonymous caller")
    void healthHidesDetails() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.components").doesNotExist())
                .andExpect(jsonPath("$.details").doesNotExist());
    }

    @Test
    @DisplayName("actuator exposes nothing beyond health and info, to anyone")
    void actuatorSurfaceIsMinimal() throws Exception {
        String token = adminToken();

        for (String endpoint : new String[] {"env", "beans", "metrics", "loggers", "mappings",
                "configprops", "threaddump", "heapdump"}) {
            // Anonymously the security layer answers first, and deliberately does not disclose
            // whether the endpoint exists at all.
            mockMvc.perform(get("/actuator/" + endpoint))
                    .andExpect(status().isUnauthorized());

            // With a valid administrator token it is a plain 404: the endpoint is not exposed,
            // so no role can reach it.
            mockMvc.perform(get("/actuator/" + endpoint).header(HttpHeaders.AUTHORIZATION, token))
                    .andExpect(status().isNotFound());
        }
    }

    @Test
    @DisplayName("responses carry the default security headers")
    void securityHeadersArePresent() throws Exception {
        mockMvc.perform(get("/api/currencies").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andExpect(header().string("X-Content-Type-Options", "nosniff"))
                .andExpect(header().string("X-Frame-Options", "DENY"))
                .andExpect(header().string("Cache-Control",
                        containsString("no-store")));
    }

    // =================================================================================
    // Authorization
    // =================================================================================

    @Test
    @DisplayName("SALES may read everything")
    void salesMayRead() throws Exception {
        String token = salesToken();

        mockMvc.perform(get("/api/invoices").header(HttpHeaders.AUTHORIZATION, token))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/settings").header(HttpHeaders.AUTHORIZATION, token))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/exchange-rates").header(HttpHeaders.AUTHORIZATION, token))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("SALES may not cancel an invoice")
    void salesMayNotCancel() throws Exception {
        mockMvc.perform(post("/api/invoices/" + INVOICE_DRAFT + "/cancel")
                        .header(HttpHeaders.AUTHORIZATION, salesToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"version": 0}"""))
                .andExpect(status().isForbidden())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test
    @DisplayName("SALES may not change settings")
    void salesMayNotChangeSettings() throws Exception {
        mockMvc.perform(put("/api/settings")
                        .header(HttpHeaders.AUTHORIZATION, salesToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "baseCurrencyCode": "USD",
                                  "defaultCurrencyCode": "USD",
                                  "defaultTaxMode": "INCLUSIVE",
                                  "defaultTaxRate": "0.0000",
                                  "invoiceNumberPrefix": "HACK"
                                }"""))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test
    @DisplayName("SALES may not change an exchange rate")
    void salesMayNotChangeExchangeRates() throws Exception {
        mockMvc.perform(put("/api/exchange-rates/USD")
                        .header(HttpHeaders.AUTHORIZATION, salesToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"rateToBase": "1.000000"}"""))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test
    @DisplayName("ADMIN may do all three")
    void adminMayDoEverything() throws Exception {
        String token = adminToken();

        mockMvc.perform(put("/api/exchange-rates/USD")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"rateToBase": "3.700000"}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rateToBase").value(3.700000));

        mockMvc.perform(put("/api/settings")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "baseCurrencyCode": "ILS",
                                  "defaultCurrencyCode": "USD",
                                  "defaultTaxMode": "INCLUSIVE",
                                  "defaultTaxRate": "0.1700",
                                  "invoiceNumberPrefix": "SI"
                                }"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.defaultCurrencyCode").value("USD"))
                .andExpect(jsonPath("$.invoiceNumberPrefix").value("SI"));

        mockMvc.perform(post("/api/invoices/" + INVOICE_DRAFT + "/cancel")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"version": 0}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));
    }

    @Test
    @DisplayName("an error document never leaks a stack trace or an internal class name")
    void errorsDoNotLeakInternals() throws Exception {
        String body = mockMvc.perform(get("/api/invoices/999999")
                        .header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isNotFound())
                .andReturn().getResponse().getContentAsString();

        assertThat(body)
                .doesNotContain("com.bsharat", "org.springframework", "Exception", "at ", "SELECT");
    }
}
