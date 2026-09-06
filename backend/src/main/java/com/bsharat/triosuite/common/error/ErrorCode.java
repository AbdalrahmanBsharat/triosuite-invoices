package com.bsharat.triosuite.common.error;

import org.springframework.http.HttpStatus;

/**
 * Stable, machine-readable error identifiers.
 *
 * <p>Every error response carries one of these as the {@code code} property of its RFC 9457
 * problem document. Clients branch on this value, never on the human-readable {@code detail}
 * string, so these names are part of the API contract and must not change.
 */
public enum ErrorCode {

    /** Request body or parameters failed Bean Validation. Carries a {@code errors} array. */
    VALIDATION_ERROR(HttpStatus.BAD_REQUEST, "Validation failed"),

    /** The addressed resource does not exist, or the caller may not know that it does. */
    NOT_FOUND(HttpStatus.NOT_FOUND, "Not found"),

    /** No credentials, or credentials that are expired, revoked or wrong. */
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "Authentication required"),

    /** Authenticated, but the role does not permit this operation. */
    FORBIDDEN(HttpStatus.FORBIDDEN, "Access denied"),

    /** A write was attempted against an invoice that is no longer a DRAFT. */
    INVOICE_NOT_EDITABLE(HttpStatus.CONFLICT, "Invoice is not editable"),

    /** The requested status change is not allowed from the invoice's current status. */
    INVALID_TRANSITION(HttpStatus.CONFLICT, "Invalid status transition"),

    /** The supplied {@code version} does not match the stored one; someone else changed the record. */
    STALE_VERSION(HttpStatus.CONFLICT, "Stale version"),

    /** Too many attempts in the current window. Accompanied by a {@code Retry-After} header. */
    RATE_LIMITED(HttpStatus.TOO_MANY_REQUESTS, "Too many requests"),

    /** Anything unexpected. Details are logged, never returned. */
    INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "Internal server error");

    private final HttpStatus status;
    private final String title;

    ErrorCode(HttpStatus status, String title) {
        this.status = status;
        this.title = title;
    }

    public HttpStatus status() {
        return status;
    }

    /** Short, generic summary used as the problem document's {@code title}. */
    public String title() {
        return title;
    }
}
