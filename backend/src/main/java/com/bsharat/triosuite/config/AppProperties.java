package com.bsharat.triosuite.config;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.time.Duration;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Strongly typed application configuration.
 *
 * <p>Every field is populated from an environment variable (see {@code .env.example}). Bean
 * Validation runs at startup, so a deployment that forgets {@code JWT_SECRET} — or supplies one that
 * is too short to be a safe HS256 key — fails immediately rather than at the first login.
 *
 * @param jwt            access-token signing and lifetime settings
 * @param cors           browser origins allowed to call the API
 * @param loginRateLimit brute-force protection for {@code POST /api/auth/login}
 */
@Validated
@ConfigurationProperties(prefix = "app")
public record AppProperties(

        @Valid @NotNull Jwt jwt,
        @Valid @NotNull Cors cors,
        @Valid @NotNull LoginRateLimit loginRateLimit) {

    /**
     * @param secret          HS256 signing key; at least 32 bytes (256 bits) as required by RFC 7518
     * @param issuer          value placed in the {@code iss} claim
     * @param accessTokenTtl  lifetime of an access token
     * @param refreshTokenTtl lifetime of a refresh token
     */
    public record Jwt(
            @NotBlank @Size(min = 32, message = "must be at least 32 bytes to be a safe HS256 key")
            String secret,

            @NotBlank String issuer,

            @NotNull Duration accessTokenTtl,

            @NotNull Duration refreshTokenTtl) {
    }

    /**
     * @param allowedOrigins exact origins permitted by CORS; empty disables cross-origin browser access
     */
    public record Cors(@NotNull List<String> allowedOrigins) {
    }

    /**
     * @param maxAttempts failed logins tolerated per key within {@code window}
     * @param window      length of the fixed counting window
     */
    public record LoginRateLimit(@Positive int maxAttempts, @NotNull Duration window) {
    }
}
