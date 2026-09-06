package com.bsharat.triosuite.common.error;

import java.time.Duration;

/**
 * Raised when a caller exceeds the login attempt allowance.
 *
 * <p>Carries the time until the current window closes so the handler can emit a
 * {@code Retry-After} header, as RFC 9110 requires for {@code 429}.
 */
public class RateLimitedException extends ApiException {

    private final Duration retryAfter;

    public RateLimitedException(Duration retryAfter) {
        super(ErrorCode.RATE_LIMITED, "Too many login attempts. Try again in "
                + Math.max(1, retryAfter.toSeconds()) + " seconds.");
        this.retryAfter = retryAfter;
    }

    public Duration retryAfter() {
        return retryAfter;
    }
}
