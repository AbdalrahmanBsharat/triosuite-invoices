package com.bsharat.triosuite.user;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * A refresh token, stored only as a hash.
 *
 * <p>The token itself is 256 bits of {@code SecureRandom} handed to the client exactly once. What
 * lives here is its SHA-256 digest, so a database leak cannot be replayed as a session. Tokens are
 * single-use: {@code revokedAt} is stamped the moment one is exchanged, and the replacement is a
 * brand-new row (ADR-0007).
 */
@Entity
@Getter
@Setter
@Table(name = "refresh_tokens")
public class RefreshToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "token_hash", nullable = false, length = 64, unique = true)
    private String tokenHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "revoked_at")
    private Instant revokedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** Whether this token may still be exchanged: not yet used, not revoked, not expired. */
    public boolean isUsable(Instant now) {
        return revokedAt == null && expiresAt.isAfter(now);
    }
}
