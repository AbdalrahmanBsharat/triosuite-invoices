package com.bsharat.triosuite.common.error;

import com.bsharat.triosuite.common.web.ValidationError;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import java.net.URI;
import java.util.Comparator;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.data.core.PropertyReferenceException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.validation.FieldError;
import org.springframework.validation.ObjectError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;
import org.springframework.web.servlet.resource.NoResourceFoundException;

/**
 * Turns every exception the API can raise into an RFC 9457 problem document.
 *
 * <p>Two rules govern what comes out. Anything the caller can act on — a rejected field, a stale
 * version, a forbidden transition — is described precisely. Anything else is reported as a bare
 * {@code INTERNAL_ERROR} and the detail goes to the log instead, so a stack trace, a SQL fragment or
 * an internal class name can never reach a client.
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    // ---------------------------------------------------------------------------------
    // Application exceptions
    // ---------------------------------------------------------------------------------

    /** Rate limiting, which additionally advertises when the caller may try again. */
    @ExceptionHandler(RateLimitedException.class)
    public ResponseEntity<ProblemDetail> handleRateLimited(
            RateLimitedException exception, HttpServletRequest request) {

        long retryAfterSeconds = Math.max(1, exception.retryAfter().toSeconds());
        return ResponseEntity.status(exception.code().status())
                .header(HttpHeaders.RETRY_AFTER, String.valueOf(retryAfterSeconds))
                .body(problem(exception.code(), exception.getMessage(), request));
    }

    /** Every deliberate domain failure: not found, not editable, invalid transition, stale version. */
    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ProblemDetail> handleApiException(
            ApiException exception, HttpServletRequest request) {

        return ResponseEntity.status(exception.code().status())
                .body(problem(exception.code(), exception.getMessage(), request));
    }

    // ---------------------------------------------------------------------------------
    // Security
    // ---------------------------------------------------------------------------------

    /**
     * A {@code @PreAuthorize} check that failed.
     *
     * <p>Needed even though {@link com.bsharat.triosuite.security.ProblemAuthenticationHandlers}
     * already renders 403s: method security throws inside the controller, so this advice sees the
     * exception first and would otherwise fold it into the catch-all below as a 500.
     */
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ProblemDetail> handleAccessDenied(
            AccessDeniedException exception, HttpServletRequest request) {

        log.info("Access denied for {} {}", request.getMethod(), request.getRequestURI());
        return ResponseEntity.status(ErrorCode.FORBIDDEN.status())
                .body(problem(ErrorCode.FORBIDDEN,
                        "Your role does not permit this operation", request));
    }

    /** An authentication failure raised from inside a controller rather than the filter chain. */
    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<ProblemDetail> handleAuthentication(
            AuthenticationException exception, HttpServletRequest request) {

        return ResponseEntity.status(ErrorCode.UNAUTHORIZED.status())
                .body(problem(ErrorCode.UNAUTHORIZED, "Authentication is required", request));
    }

    // ---------------------------------------------------------------------------------
    // Validation
    // ---------------------------------------------------------------------------------

    /** Bean Validation on a request body. */
    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException exception, HttpHeaders headers,
            HttpStatusCode status, WebRequest request) {

        List<ValidationError> errors = exception.getBindingResult().getAllErrors().stream()
                .map(GlobalExceptionHandler::toValidationError)
                .sorted(Comparator.comparing(ValidationError::field))
                .toList();

        ProblemDetail problem = ProblemDetails.of(
                ErrorCode.VALIDATION_ERROR, "The request contains " + errors.size()
                        + (errors.size() == 1 ? " invalid field" : " invalid fields"));
        problem.setInstance(instanceOf(request));
        problem.setProperty("errors", errors);

        return ResponseEntity.status(ErrorCode.VALIDATION_ERROR.status()).body(problem);
    }

    /** Bean Validation on path variables and query parameters. */
    @Override
    protected ResponseEntity<Object> handleHandlerMethodValidationException(
            HandlerMethodValidationException exception, HttpHeaders headers,
            HttpStatusCode status, WebRequest request) {

        ProblemDetail problem = ProblemDetails.of(
                ErrorCode.VALIDATION_ERROR, "One or more request parameters are invalid");
        problem.setInstance(instanceOf(request));

        return ResponseEntity.status(ErrorCode.VALIDATION_ERROR.status()).body(problem);
    }

    /** A body that is not parseable JSON, or a value that will not fit its target type. */
    @Override
    protected ResponseEntity<Object> handleHttpMessageNotReadable(
            HttpMessageNotReadableException exception, HttpHeaders headers,
            HttpStatusCode status, WebRequest request) {

        // The parser's message quotes the offending source and names internal types; keep it in the log.
        log.debug("Unreadable request body: {}", exception.getMessage());

        ProblemDetail problem = ProblemDetails.of(
                ErrorCode.VALIDATION_ERROR,
                "The request body could not be read. Check that it is valid JSON and that every "
                        + "field has the expected type.");
        problem.setInstance(instanceOf(request));

        return ResponseEntity.status(ErrorCode.VALIDATION_ERROR.status()).body(problem);
    }

    /** A path variable or query parameter that will not convert, such as a non-numeric id. */
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ProblemDetail> handleTypeMismatch(
            MethodArgumentTypeMismatchException exception, HttpServletRequest request) {

        ProblemDetail problem = problem(ErrorCode.VALIDATION_ERROR,
                "'" + exception.getName() + "' is not in the expected format", request);
        problem.setProperty("errors", List.of(
                new ValidationError(exception.getName(), "is not in the expected format")));

        return ResponseEntity.status(ErrorCode.VALIDATION_ERROR.status()).body(problem);
    }

    /** Bean Validation raised outside the MVC binding path, e.g. from a service method. */
    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ProblemDetail> handleConstraintViolation(
            ConstraintViolationException exception, HttpServletRequest request) {

        List<ValidationError> errors = exception.getConstraintViolations().stream()
                .map(GlobalExceptionHandler::toValidationError)
                .sorted(Comparator.comparing(ValidationError::field))
                .toList();

        ProblemDetail problem = problem(ErrorCode.VALIDATION_ERROR,
                "The request contains invalid values", request);
        problem.setProperty("errors", errors);

        return ResponseEntity.status(ErrorCode.VALIDATION_ERROR.status()).body(problem);
    }

    // ---------------------------------------------------------------------------------
    // Persistence
    // ---------------------------------------------------------------------------------

    /**
     * Hibernate's own optimistic-lock check.
     *
     * <p>The service compares versions explicitly and reports a mismatch before doing any work, so
     * this is the second line of defence: it fires when the row changed between that comparison and
     * the flush.
     */
    @ExceptionHandler(OptimisticLockingFailureException.class)
    public ResponseEntity<ProblemDetail> handleOptimisticLocking(
            OptimisticLockingFailureException exception, HttpServletRequest request) {

        log.debug("Optimistic lock lost at flush time", exception);
        return ResponseEntity.status(ErrorCode.STALE_VERSION.status())
                .body(problem(ErrorCode.STALE_VERSION,
                        "This record was changed by someone else. Reload it and try again.", request));
    }

    /**
     * A constraint the application did not check first — a duplicate unique key, a violated CHECK.
     *
     * <p>The driver's message names tables, columns and constraints, so it is logged and never
     * returned.
     */
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ProblemDetail> handleDataIntegrityViolation(
            DataIntegrityViolationException exception, HttpServletRequest request) {

        log.warn("Database constraint rejected a write", exception);
        return ResponseEntity.status(ErrorCode.VALIDATION_ERROR.status())
                .body(problem(ErrorCode.VALIDATION_ERROR,
                        "The request conflicts with data that already exists", request));
    }

    /**
     * A {@code sort} parameter naming a property the entity does not have.
     *
     * <p>Spring Data raises this while building the query, so without a handler an ordinary typo in
     * a query string would be reported as a server error.
     */
    @ExceptionHandler(PropertyReferenceException.class)
    public ResponseEntity<ProblemDetail> handleUnknownSortProperty(
            PropertyReferenceException exception, HttpServletRequest request) {

        ProblemDetail problem = problem(ErrorCode.VALIDATION_ERROR,
                "'" + exception.getPropertyName() + "' is not a sortable property", request);
        problem.setProperty("errors", List.of(
                new ValidationError("sort", "'" + exception.getPropertyName()
                        + "' is not a sortable property")));

        return ResponseEntity.status(ErrorCode.VALIDATION_ERROR.status()).body(problem);
    }

    // ---------------------------------------------------------------------------------
    // Routing and fallback
    // ---------------------------------------------------------------------------------

    /** An unmapped path. Reported as a plain 404 rather than Spring's default error page. */
    @Override
    protected ResponseEntity<Object> handleNoResourceFoundException(
            NoResourceFoundException exception, HttpHeaders headers,
            HttpStatusCode status, WebRequest request) {

        ProblemDetail problem = ProblemDetails.of(ErrorCode.NOT_FOUND, "No such endpoint");
        problem.setInstance(instanceOf(request));

        return ResponseEntity.status(ErrorCode.NOT_FOUND.status()).body(problem);
    }

    /** Anything unforeseen. Logged in full at ERROR; the caller learns only that it failed. */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ProblemDetail> handleUnexpected(
            Exception exception, HttpServletRequest request) {

        log.error("Unhandled exception for {} {}", request.getMethod(), request.getRequestURI(), exception);
        return ResponseEntity.status(ErrorCode.INTERNAL_ERROR.status())
                .body(problem(ErrorCode.INTERNAL_ERROR,
                        "Something went wrong. Please try again.", request));
    }

    // ---------------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------------

    private static ProblemDetail problem(ErrorCode code, String detail, HttpServletRequest request) {
        ProblemDetail problem = ProblemDetails.of(code, detail);
        problem.setInstance(URI.create(request.getRequestURI()));
        return problem;
    }

    private static URI instanceOf(WebRequest request) {
        return URI.create(request.getDescription(false).replaceFirst("^uri=", ""));
    }

    private static ValidationError toValidationError(ObjectError error) {
        String field = error instanceof FieldError fieldError ? fieldError.getField() : error.getObjectName();
        return new ValidationError(field, error.getDefaultMessage());
    }

    private static ValidationError toValidationError(ConstraintViolation<?> violation) {
        return new ValidationError(violation.getPropertyPath().toString(), violation.getMessage());
    }
}
