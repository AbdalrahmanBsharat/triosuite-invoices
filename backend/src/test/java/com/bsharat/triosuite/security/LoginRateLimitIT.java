package com.bsharat.triosuite.security;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.bsharat.triosuite.support.AbstractIntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

/**
 * Brute-force protection on the login endpoint.
 *
 * <p>The limiter keeps two counters — one per username, one per client IP — in a singleton that
 * lives as long as the Spring context, with a one-minute wall-clock window. That makes a naive test
 * of it quietly order-dependent: any earlier failed login from the same address eats into the
 * allowance, and the test then trips a request early. It passed locally and failed in CI for
 * exactly that reason.
 *
 * <p>So each test here isolates both counters rather than assuming they start empty:
 * <ul>
 *   <li>a **client IP unique to the test**, supplied by a request post-processor, so no other test
 *       can have touched that counter;</li>
 *   <li>a **username nobody else uses** — or, where a real account is required, one deliberate
 *       successful login first, which resets that username's counter by design.</li>
 * </ul>
 * That makes them independent of ordering, of what ran before, and of the wall clock.
 */
class LoginRateLimitIT extends AbstractIntegrationTest {

    /** The configured allowance: five failures per minute, per key. */
    private static final int MAX_ATTEMPTS = 5;

    @Test
    @DisplayName("the sixth failed attempt in a minute is 429 with a Retry-After header")
    void sixthFailureIsRateLimited() throws Exception {
        // A username no other test touches, so only this test's failures are counted against it.
        String username = "rate-limit-probe";
        RequestPostProcessor client = from("198.51.100.10");

        for (int attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            mockMvc.perform(login(username, "wrong-password").with(client))
                    .andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
        }

        mockMvc.perform(login(username, "wrong-password").with(client))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("RATE_LIMITED"))
                .andExpect(header().exists("Retry-After"));
    }

    @Test
    @DisplayName("the correct password is refused too once the allowance is spent")
    void rateLimitAppliesEvenToValidCredentials() throws Exception {
        RequestPostProcessor client = from("198.51.100.20");

        // A real account is needed to prove the point, so start by signing in successfully. That
        // clears this username's counter — which is the documented behaviour, not a workaround —
        // and leaves the test independent of any earlier failed login for 'sales'.
        mockMvc.perform(login("sales", "Sales#2026").with(client))
                .andExpect(status().isOk());

        for (int attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            mockMvc.perform(login("sales", "wrong-password").with(client))
                    .andExpect(status().isUnauthorized());
        }

        // The whole point: an attacker who finds the password on attempt six still cannot use it.
        mockMvc.perform(login("sales", "Sales#2026").with(client))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("RATE_LIMITED"));
    }

    @Test
    @DisplayName("one address being blocked does not lock out a different one")
    void theLimitIsScopedToItsKeys() throws Exception {
        String username = "rate-limit-scope-probe";

        for (int attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            mockMvc.perform(login(username, "wrong-password").with(from("198.51.100.30")))
                    .andExpect(status().isUnauthorized());
        }
        mockMvc.perform(login(username, "wrong-password").with(from("198.51.100.30")))
                .andExpect(status().isTooManyRequests());

        // A different account from a different address is unaffected — the counters are per key,
        // not global, so one attacker cannot deny the service to everyone else.
        mockMvc.perform(login("admin", "Admin#2026").with(from("198.51.100.31")))
                .andExpect(status().isOk());
    }

    private static MockHttpServletRequestBuilder login(String username, String password) {
        return post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"username": "%s", "password": "%s"}""".formatted(username, password));
    }

    /** Presents a specific client address, so each test gets a counter of its own. */
    private static RequestPostProcessor from(String clientIp) {
        return request -> {
            request.setRemoteAddr(clientIp);
            return request;
        };
    }
}
