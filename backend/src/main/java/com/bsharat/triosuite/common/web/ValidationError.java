package com.bsharat.triosuite.common.web;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * One field-level validation failure, listed under the {@code errors} property of a
 * {@code VALIDATION_ERROR} problem document.
 *
 * @param field   the rejected property, in dotted path form (e.g. {@code lines[0].quantity})
 * @param message what is wrong with it, phrased for a human
 */
@Schema(name = "ValidationError")
public record ValidationError(
        @Schema(example = "lines[0].quantity") String field,
        @Schema(example = "must be greater than 0") String message) {
}
