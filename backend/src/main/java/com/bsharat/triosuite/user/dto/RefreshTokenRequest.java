package com.bsharat.triosuite.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Body of {@code POST /api/auth/refresh} and {@code POST /api/auth/logout}.
 *
 * @param refreshToken the opaque token issued by a previous login or refresh
 */
@Schema(name = "RefreshTokenRequest")
public record RefreshTokenRequest(
        @NotBlank @Size(max = 200) String refreshToken) {
}
