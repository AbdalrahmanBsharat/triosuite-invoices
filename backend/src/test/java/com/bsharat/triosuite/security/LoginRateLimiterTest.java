package com.bsharat.triosuite.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.bsharat.triosuite.config.AppProperties;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** The rate limiter on its own, with time supplied by the test rather than the clock. */
class LoginRateLimiterTest {

    private static final Duration WINDOW = Duration.ofMinutes(1);
    private static final String IP = "203.0.113.7";

    private final Instant now = Instant.parse("2026-09-06T10:00:00Z");

    private LoginRateLimiter limiter;

    @BeforeEach
    void setUp() {
        limiter = new LoginRateLimiter(new AppProperties(
                new AppProperties.Jwt("a-key-that-is-long-enough-for-hs256!!", "test",
                        Duration.ofMinutes(30), Duration.ofDays(30)),
                new AppProperties.Cors(List.of()),
                new AppProperties.LoginRateLimit(5, WINDOW)));
    }

    @Test
    @DisplayName("the allowance is not spent until the fifth failure")
    void allowsUpToTheLimit() {
        for (int attempt = 0; attempt < 5; attempt++) {
            assertThat(limiter.checkAllowed("admin", IP, now))
                    .as("attempt %d", attempt + 1).isEmpty();
            limiter.recordFailure("admin", IP, now);
        }

        assertThat(limiter.checkAllowed("admin", IP, now)).isPresent();
    }

    @Test
    @DisplayName("the window expires and the allowance returns")
    void windowExpires() {
        for (int attempt = 0; attempt < 5; attempt++) {
            limiter.recordFailure("admin", IP, now);
        }
        assertThat(limiter.checkAllowed("admin", IP, now)).isPresent();

        Instant afterWindow = now.plus(WINDOW).plusSeconds(1);
        assertThat(limiter.checkAllowed("admin", IP, afterWindow)).isEmpty();
    }

    @Test
    @DisplayName("the reported retry delay never exceeds the window")
    void retryDelayIsWithinTheWindow() {
        for (int attempt = 0; attempt < 5; attempt++) {
            limiter.recordFailure("admin", IP, now);
        }

        Duration retryAfter = limiter.checkAllowed("admin", IP, now).orElseThrow();
        assertThat(retryAfter).isPositive().isLessThanOrEqualTo(WINDOW);
    }

    @Test
    @DisplayName("a successful login clears that username's counter")
    void successClearsTheUsernameCounter() {
        // Each attempt comes from a different address so only the username counter is in play;
        // the address counter is asserted separately below.
        for (int attempt = 0; attempt < 4; attempt++) {
            limiter.recordFailure("admin", "192.0.2." + attempt, now);
        }
        limiter.recordSuccess("admin");

        // A full fresh allowance of five must be tolerated, because the counter restarted at zero.
        for (int attempt = 4; attempt < 9; attempt++) {
            assertThat(limiter.checkAllowed("admin", "192.0.2." + attempt, now))
                    .as("attempt %d after a successful login", attempt - 3).isEmpty();
            limiter.recordFailure("admin", "192.0.2." + attempt, now);
        }

        // ...and the sixth is refused again, so the counter really restarted rather than vanished.
        assertThat(limiter.checkAllowed("admin", "192.0.2.99", now)).isPresent();
    }

    @Test
    @DisplayName("spraying one password across many accounts still trips the IP counter")
    void ipCounterCatchesUsernameSpraying() {
        for (int attempt = 0; attempt < 5; attempt++) {
            String differentUsernameEachTime = "victim-" + attempt;
            assertThat(limiter.checkAllowed(differentUsernameEachTime, IP, now)).isEmpty();
            limiter.recordFailure(differentUsernameEachTime, IP, now);
        }

        assertThat(limiter.checkAllowed("victim-99", IP, now))
                .as("no username has five failures, but this address has")
                .isPresent();
    }

    @Test
    @DisplayName("attacking one account from many addresses still trips the username counter")
    void usernameCounterCatchesDistributedAttempts() {
        for (int attempt = 0; attempt < 5; attempt++) {
            String differentAddressEachTime = "198.51.100." + attempt;
            assertThat(limiter.checkAllowed("admin", differentAddressEachTime, now)).isEmpty();
            limiter.recordFailure("admin", differentAddressEachTime, now);
        }

        assertThat(limiter.checkAllowed("admin", "198.51.100.99", now))
                .as("no address has five failures, but this account has")
                .isPresent();
    }

    @Test
    @DisplayName("one account being attacked does not lock out an unrelated one")
    void limitsAreScopedToTheirKey() {
        for (int attempt = 0; attempt < 5; attempt++) {
            limiter.recordFailure("admin", IP, now);
        }

        assertThat(limiter.checkAllowed("sales", "198.51.100.4", now)).isEmpty();
    }

    @Test
    @DisplayName("a successful login does not reset the address counter")
    void successDoesNotClearTheIpCounter() {
        for (int attempt = 0; attempt < 5; attempt++) {
            limiter.recordFailure("victim-" + attempt, IP, now);
        }
        limiter.recordSuccess("victim-0");

        assertThat(limiter.checkAllowed("victim-1", IP, now))
                .as("holding one valid credential must not restore the allowance for the rest")
                .isPresent();
    }
}
