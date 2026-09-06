package com.bsharat.triosuite.user;

import com.bsharat.triosuite.common.error.ApiException;
import com.bsharat.triosuite.common.error.RateLimitedException;
import com.bsharat.triosuite.config.AppProperties;
import com.bsharat.triosuite.security.JwtService;
import com.bsharat.triosuite.security.LoginRateLimiter;
import com.bsharat.triosuite.user.dto.LoginRequest;
import com.bsharat.triosuite.user.dto.TokenResponse;
import com.bsharat.triosuite.user.dto.UserResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Authentication: login, refresh-token rotation and logout.
 *
 * <p>Access tokens are stateless JWTs. Refresh tokens are opaque 256-bit random strings stored only
 * as a SHA-256 digest, single-use, and rotated on every exchange, so a stolen one is usable at most
 * once and a leaked database yields nothing replayable (ADR-0007).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    /**
     * A well-formed BCrypt digest of a value nobody knows.
     *
     * <p>Verified against when the username does not exist, so a login for an unknown account costs
     * the same wall-clock time as one for a known account with the wrong password. Without it, the
     * response time alone tells an attacker which usernames are real.
     */
    private static final String DUMMY_HASH =
            "$2a$12$Ot/Y83O6frHJjYObKL.b/eM.4lJxpY7D9Vw5NgncfNeD/fVMAw4yO";

    private static final int REFRESH_TOKEN_BYTES = 32;

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final LoginRateLimiter rateLimiter;
    private final AppProperties properties;
    private final SecureRandom secureRandom = new SecureRandom();

    /**
     * Verifies credentials and issues a token pair.
     *
     * @param request  the submitted username and password
     * @param clientIp the caller's address, counted separately from the username
     * @throws RateLimitedException if either counter is exhausted
     * @throws ApiException         with {@code UNAUTHORIZED} if the credentials do not check out
     */
    @Transactional
    public TokenResponse login(LoginRequest request, String clientIp) {
        Instant now = Instant.now();
        String username = request.username().trim();

        rateLimiter.checkAllowed(username, clientIp, now).ifPresent(retryAfter -> {
            log.warn("Login blocked by rate limit for username '{}'", username);
            throw new RateLimitedException(retryAfter);
        });

        Optional<User> candidate = users.findByUsername(username);
        boolean passwordMatches = passwordEncoder.matches(
                request.password(),
                candidate.map(User::getPasswordHash).orElse(DUMMY_HASH));

        if (candidate.isEmpty() || !passwordMatches || !candidate.get().isActive()) {
            rateLimiter.recordFailure(username, clientIp, now);
            // One message for all three causes: never reveal which part was wrong.
            log.info("Failed login for username '{}'", username);
            throw ApiException.unauthorized("Incorrect username or password");
        }

        User user = candidate.get();
        rateLimiter.recordSuccess(username);
        refreshTokens.deleteExpiredBefore(now);

        log.info("User '{}' signed in", user.getUsername());
        return issueTokenPair(user, now);
    }

    /**
     * Exchanges a refresh token for a new pair and revokes the one presented.
     *
     * @param rawToken the opaque token the client stored
     * @throws ApiException with {@code UNAUTHORIZED} if it is unknown, revoked, expired, or belongs
     *                      to an account that has since been deactivated
     */
    @Transactional
    public TokenResponse refresh(String rawToken) {
        Instant now = Instant.now();

        RefreshToken stored = refreshTokens.findByTokenHash(sha256Hex(rawToken))
                .orElseThrow(() -> ApiException.unauthorized("Session expired. Please sign in again."));

        if (!stored.isUsable(now)) {
            // A revoked token being presented again is worth noticing: it means the value leaked
            // or the client is retrying. Either way the answer is the same.
            log.warn("Refresh token reuse or expiry for user id {}", stored.getUser().getId());
            throw ApiException.unauthorized("Session expired. Please sign in again.");
        }

        User user = stored.getUser();
        if (!user.isActive()) {
            throw ApiException.unauthorized("This account has been deactivated");
        }

        stored.setRevokedAt(now);
        return issueTokenPair(user, now);
    }

    /**
     * Revokes a refresh token.
     *
     * <p>Silent when the token is unknown: logging out is idempotent, and answering differently for
     * a token that exists would turn this endpoint into an oracle.
     */
    @Transactional
    public void logout(String rawToken) {
        refreshTokens.findByTokenHash(sha256Hex(rawToken))
                .filter(token -> token.getRevokedAt() == null)
                .ifPresent(token -> token.setRevokedAt(Instant.now()));
    }

    /** Loads the account behind a verified access token. */
    @Transactional(readOnly = true)
    public UserResponse currentUser(Long userId) {
        return users.findById(userId)
                .filter(User::isActive)
                .map(UserResponse::from)
                .orElseThrow(() -> ApiException.unauthorized("This account is no longer available"));
    }

    private TokenResponse issueTokenPair(User user, Instant now) {
        String accessToken = jwtService.issueAccessToken(user, now);
        String rawRefreshToken = generateRefreshToken();

        Duration refreshTtl = properties.jwt().refreshTokenTtl();
        RefreshToken entity = new RefreshToken();
        entity.setUser(user);
        entity.setTokenHash(sha256Hex(rawRefreshToken));
        entity.setCreatedAt(now);
        entity.setExpiresAt(now.plus(refreshTtl));
        refreshTokens.save(entity);

        return new TokenResponse(
                accessToken,
                rawRefreshToken,
                jwtService.accessTokenTtl().toSeconds(),
                UserResponse.from(user));
    }

    /** 256 bits from {@link SecureRandom}, base64url-encoded without padding. */
    private String generateRefreshToken() {
        byte[] bytes = new byte[REFRESH_TOKEN_BYTES];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    /**
     * SHA-256, lowercase hex.
     *
     * <p>A fast hash is the right choice here, unlike for passwords: the input is 256 bits of full
     * entropy, so there is nothing to guess and the deliberate slowness of BCrypt would only add
     * latency to every refresh.
     */
    private static String sha256Hex(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is required by every JVM", e);
        }
    }
}
