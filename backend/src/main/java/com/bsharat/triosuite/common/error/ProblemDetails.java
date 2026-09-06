package com.bsharat.triosuite.common.error;

import java.net.URI;
import org.springframework.http.ProblemDetail;

/**
 * Builds the RFC 9457 problem documents this API returns for every error.
 *
 * <p>Two properties are added to the standard fields: {@code code}, the stable identifier clients
 * branch on, and — for validation failures — {@code errors}, the per-field list. The {@code type}
 * URI points at the section of the API documentation describing the code.
 */
public final class ProblemDetails {

    private static final String TYPE_BASE = "https://github.com/AbdalrahmanBsharat/triosuite-invoices/blob/main/docs/API.md#";

    private ProblemDetails() {
    }

    /**
     * Creates a problem document for an error code.
     *
     * @param code   the error identifier, which also fixes the HTTP status
     * @param detail a human-readable explanation, safe to show a user
     */
    public static ProblemDetail of(ErrorCode code, String detail) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(code.status(), detail);
        problem.setTitle(code.title());
        problem.setType(URI.create(TYPE_BASE + code.name().toLowerCase()));
        problem.setProperty("code", code.name());
        return problem;
    }
}
