package com.bsharat.triosuite.security;

import com.bsharat.triosuite.config.AppProperties;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.stereotype.Component;

/**
 * Fixed-window brute-force protection for the login endpoint.
 *
 * <p>Two independent counters are kept per attempt — one keyed by username, one by client IP — so
 * neither spraying many passwords at one account nor spraying one password across many accounts
 * stays under the limit. Both default to five failures per minute.
 *
 * <p>Only <em>failed</em> attempts count. A successful login clears the username's counter so a
 * legitimate user who mistypes twice is not punished for the rest of the window.
 *
 * <p>State is in memory, which is correct for the single-instance deployment this project targets
 * and is documented as a known limitation: it resets on restart and is not shared between replicas.
 * Moving it to Redis is the only change horizontal scaling would need (ADR-0008).
 */
@Component
public class LoginRateLimiter {

    /** Stop the map growing without bound if the process is scanned for a long time. */
    private static final int EVICTION_THRESHOLD = 10_000;

    private final Map<String, Window> windows = new ConcurrentHashMap<>();
    private final int maxAttempts;
    private final Duration window;

    public LoginRateLimiter(AppProperties properties) {
        this.maxAttempts = properties.loginRateLimit().maxAttempts();
        this.window = properties.loginRateLimit().window();
    }

    /**
     * Checks both counters before a password is verified.
     *
     * @param username the account being attempted, case-normalised by the caller
     * @param clientIp the remote address the attempt came from
     * @return how long until the offending window closes, or empty if the attempt may proceed
     */
    public Optional<Duration> checkAllowed(String username, String clientIp, Instant now) {
        evictIfCrowded(now);

        Optional<Duration> byUser = remainingIfBlocked("user:" + username, now);
        if (byUser.isPresent()) {
            return byUser;
        }
        return remainingIfBlocked("ip:" + clientIp, now);
    }

    /** Records a failed attempt against both the username and the client IP. */
    public void recordFailure(String username, String clientIp, Instant now) {
        increment("user:" + username, now);
        increment("ip:" + clientIp, now);
    }

    /**
     * Clears the username's counter after a successful login.
     *
     * <p>The IP counter is deliberately left alone: one valid credential should not reset the
     * allowance for every other account being tried from the same address.
     */
    public void recordSuccess(String username) {
        windows.remove("user:" + username);
    }

    private Optional<Duration> remainingIfBlocked(String key, Instant now) {
        Window current = windows.get(key);
        if (current == null || !current.covers(now) || current.attempts.get() < maxAttempts) {
            return Optional.empty();
        }
        return Optional.of(Duration.between(now, current.expiresAt));
    }

    private void increment(String key, Instant now) {
        windows.compute(key, (ignored, existing) -> {
            if (existing == null || !existing.covers(now)) {
                return new Window(now.plus(window));
            }
            existing.attempts.incrementAndGet();
            return existing;
        });
    }

    private void evictIfCrowded(Instant now) {
        if (windows.size() > EVICTION_THRESHOLD) {
            windows.values().removeIf(existing -> !existing.covers(now));
        }
    }

    /** A counting window that expires at a fixed instant. */
    private static final class Window {

        private final Instant expiresAt;
        private final AtomicInteger attempts = new AtomicInteger(1);

        private Window(Instant expiresAt) {
            this.expiresAt = expiresAt;
        }

        private boolean covers(Instant now) {
            return now.isBefore(expiresAt);
        }
    }
}
