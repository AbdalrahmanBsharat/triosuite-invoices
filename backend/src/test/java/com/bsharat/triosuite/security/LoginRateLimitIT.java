package com.bsharat.triosuite.security;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.bsharat.triosuite.support.AbstractIntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;

/**
 * Brute-force protection on the login endpoint.
 *
 * <p>{@link DirtiesContext} is deliberate. The limiter is a singleton and its second counter is
 * keyed by client IP, which MockMvc always reports as the same address — so a test that spends the
 * allowance would lock out every login that ran after it, in this class and in any other. Discarding
 * the context after each method gives each one a limiter that starts empty.
 */
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
class LoginRateLimitIT extends AbstractIntegrationTest {

    @Test
    @DisplayName("the sixth failed attempt in a minute is 429 with a Retry-After header")
    void sixthFailureIsRateLimited() throws Exception {
        for (int attempt = 1; attempt <= 5; attempt++) {
            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"username": "admin", "password": "wrong-password"}"""))
                    .andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
        }

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username": "admin", "password": "wrong-password"}"""))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("RATE_LIMITED"))
                .andExpect(header().exists("Retry-After"));
    }

    @Test
    @DisplayName("the correct password is refused too once the allowance is spent")
    void rateLimitAppliesEvenToValidCredentials() throws Exception {
        for (int attempt = 1; attempt <= 5; attempt++) {
            mockMvc.perform(post("/api/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"username": "sales", "password": "wrong-password"}"""))
                    .andExpect(status().isUnauthorized());
        }

        // The whole point: an attacker who finds the password on attempt six still cannot use it.
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username": "sales", "password": "Sales#2026"}"""))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("RATE_LIMITED"));
    }
}
