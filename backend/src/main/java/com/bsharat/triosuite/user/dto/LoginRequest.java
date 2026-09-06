package com.bsharat.triosuite.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Credentials for {@code POST /api/auth/login}.
 *
 * @param username the account name
 * @param password the plaintext password, checked against a BCrypt digest and never logged
 */
@Schema(name = "LoginRequest")
public record LoginRequest(
        @NotBlank @Size(max = 50) @Schema(example = "admin") String username,
        @NotBlank @Size(max = 200) @Schema(example = "Admin#2026") String password) {
}
