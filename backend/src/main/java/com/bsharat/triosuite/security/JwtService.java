package com.bsharat.triosuite.security;

import com.bsharat.triosuite.config.AppProperties;
import com.bsharat.triosuite.user.Role;
import com.bsharat.triosuite.user.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;
import javax.crypto.SecretKey;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Issues and verifies access tokens.
 *
 * <p>Access tokens are HS256 JWTs carrying {@code iss}, {@code sub} (the account id), {@code iat},
 * {@code exp} and a {@code role} claim, and nothing else that is sensitive. They are short-lived and
 * cannot be revoked; revocation is the refresh token's job (ADR-0007).
 *
 * <p>The signing key comes from {@code JWT_SECRET} and is validated at start-up to be at least 256
 * bits, so a deployment cannot silently weaken HS256 below what RFC 7518 requires.
 */
@Slf4j
@Service
public class JwtService {

    private static final String CLAIM_ROLE = "role";
    private static final String CLAIM_USERNAME = "username";

    private final SecretKey signingKey;
    private final String issuer;
    private final Duration accessTokenTtl;

    public JwtService(AppProperties properties) {
        this.signingKey = Keys.hmacShaKeyFor(properties.jwt().secret().getBytes(StandardCharsets.UTF_8));
        this.issuer = properties.jwt().issuer();
        this.accessTokenTtl = properties.jwt().accessTokenTtl();
    }

    /** How long an issued access token remains valid. */
    public Duration accessTokenTtl() {
        return accessTokenTtl;
    }

    /**
     * Mints an access token for an account.
     *
     * @param user the authenticated account
     * @param now  the issuing instant, passed in so tests can control it
     */
    public String issueAccessToken(User user, Instant now) {
        return Jwts.builder()
                .issuer(issuer)
                .subject(String.valueOf(user.getId()))
                .claim(CLAIM_ROLE, user.getRole().name())
                .claim(CLAIM_USERNAME, user.getUsername())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(accessTokenTtl)))
                .signWith(signingKey, Jwts.SIG.HS256)
                .compact();
    }

    /**
     * Verifies a token's signature, issuer and expiry and rebuilds the caller from its claims.
     *
     * @param token the raw compact JWT
     * @return the caller, or empty if the token is malformed, foreign, expired or tampered with
     */
    public Optional<AuthenticatedUser> verify(String token) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(signingKey)
                    .requireIssuer(issuer)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();

            return Optional.of(new AuthenticatedUser(
                    Long.valueOf(claims.getSubject()),
                    claims.get(CLAIM_USERNAME, String.class),
                    Role.valueOf(claims.get(CLAIM_ROLE, String.class))));

        } catch (JwtException | IllegalArgumentException e) {
            // The token itself is never logged: it is a bearer credential until it expires.
            log.debug("Rejected access token: {}", e.getClass().getSimpleName());
            return Optional.empty();
        }
    }
}
