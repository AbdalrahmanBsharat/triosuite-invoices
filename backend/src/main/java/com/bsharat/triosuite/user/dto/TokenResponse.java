package com.bsharat.triosuite.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * A freshly issued token pair.
 *
 * @param accessToken       short-lived JWT for the {@code Authorization: Bearer} header
 * @param refreshToken      opaque, single-use token that buys the next pair
 * @param expiresInSeconds  lifetime of {@code accessToken}, so the client can refresh pre-emptively
 * @param user              the account the tokens belong to
 */
@Schema(name = "TokenResponse")
public record TokenResponse(
        String accessToken,
        String refreshToken,
        @Schema(example = "1800") long expiresInSeconds,
        UserResponse user) {
}
