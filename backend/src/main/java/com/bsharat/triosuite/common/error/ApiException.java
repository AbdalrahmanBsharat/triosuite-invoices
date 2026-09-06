package com.bsharat.triosuite.common.error;

/**
 * Base class for every exception that maps onto a documented {@link ErrorCode}.
 *
 * <p>The message is safe to return to the caller: it is written for a human user of the mobile
 * app, and never contains SQL, class names or stack traces.
 */
public class ApiException extends RuntimeException {

    private final ErrorCode code;

    public ApiException(ErrorCode code, String detail) {
        super(detail);
        this.code = code;
    }

    public ErrorCode code() {
        return code;
    }

    /** The addressed resource does not exist. */
    public static ApiException notFound(String resource, Object id) {
        return new ApiException(ErrorCode.NOT_FOUND, resource + " " + id + " was not found");
    }

    /** A write was attempted against an invoice that is no longer a DRAFT. */
    public static ApiException invoiceNotEditable(String invoiceNumber, Object status) {
        return new ApiException(
                ErrorCode.INVOICE_NOT_EDITABLE,
                "Invoice " + invoiceNumber + " is " + status + " and can no longer be edited");
    }

    /** The requested status change is not allowed from the current status. */
    public static ApiException invalidTransition(String invoiceNumber, Object from, String action) {
        return new ApiException(
                ErrorCode.INVALID_TRANSITION,
                "Invoice " + invoiceNumber + " is " + from + " and cannot be " + action);
    }

    /** Someone else changed the record since it was read. */
    public static ApiException staleVersion(String invoiceNumber) {
        return new ApiException(
                ErrorCode.STALE_VERSION,
                "Invoice " + invoiceNumber + " was changed by someone else. Reload it and try again.");
    }

    /** Credentials are missing, wrong, expired or revoked. */
    public static ApiException unauthorized(String detail) {
        return new ApiException(ErrorCode.UNAUTHORIZED, detail);
    }

    /** A business rule rejected the request; surfaced as a validation problem. */
    public static ApiException invalid(String detail) {
        return new ApiException(ErrorCode.VALIDATION_ERROR, detail);
    }
}
