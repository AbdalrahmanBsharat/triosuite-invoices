package com.bsharat.triosuite.user;

import java.time.Instant;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Refresh-token storage. Tokens are matched by SHA-256 hash; the raw value is never persisted. */
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    /** Looks a token up by its digest, eagerly loading the owning account. */
    @Query("SELECT t FROM RefreshToken t JOIN FETCH t.user WHERE t.tokenHash = :tokenHash")
    Optional<RefreshToken> findByTokenHash(@Param("tokenHash") String tokenHash);

    /**
     * Deletes tokens that expired before the given instant.
     *
     * <p>Called opportunistically on login so the table cannot grow without bound. Revoked tokens
     * are kept until they expire, so a replayed one is still recognisable as revoked rather than
     * merely unknown.
     */
    @Modifying
    @Query("DELETE FROM RefreshToken t WHERE t.expiresAt < :cutoff")
    int deleteExpiredBefore(@Param("cutoff") Instant cutoff);
}
