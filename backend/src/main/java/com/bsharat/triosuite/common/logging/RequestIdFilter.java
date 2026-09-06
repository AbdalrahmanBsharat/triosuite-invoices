package com.bsharat.triosuite.common.logging;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Puts a request id on every log line and echoes it back to the caller.
 *
 * <p>An inbound {@code X-Request-Id} is honoured so a trace can be followed across a proxy; anything
 * else gets a fresh one. The value lands in the SLF4J MDC under {@code requestId}, which the console
 * pattern in application.yml prints, so all the lines belonging to one request can be pulled out of
 * an interleaved log by a single grep.
 *
 * <p>Runs first in the chain, before security, so even a rejected request is traceable. The MDC is
 * always cleared in a finally block: the thread goes back to a pool and must not inherit the id.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestIdFilter extends OncePerRequestFilter {

    /** Header carrying the id, both inbound and outbound. */
    public static final String HEADER = "X-Request-Id";

    /** MDC key referenced by the logging pattern. */
    public static final String MDC_KEY = "requestId";

    private static final int MAX_LENGTH = 64;

    @Override
    protected void doFilterInternal(
            @NonNull HttpServletRequest request,
            @NonNull HttpServletResponse response,
            @NonNull FilterChain filterChain) throws ServletException, IOException {

        String requestId = sanitise(request.getHeader(HEADER));
        MDC.put(MDC_KEY, requestId);
        response.setHeader(HEADER, requestId);
        try {
            filterChain.doFilter(request, response);
        } finally {
            MDC.remove(MDC_KEY);
        }
    }

    /**
     * Accepts a caller-supplied id only if it is short and alphanumeric.
     *
     * <p>The value is written into log lines, so letting an arbitrary string through would allow a
     * caller to forge log entries by embedding newlines.
     */
    private String sanitise(String candidate) {
        if (candidate == null || candidate.isBlank() || candidate.length() > MAX_LENGTH
                || !candidate.matches("[A-Za-z0-9._-]+")) {
            return UUID.randomUUID().toString().substring(0, 8);
        }
        return candidate;
    }
}
