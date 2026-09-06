package com.bsharat.triosuite.common.jpa;

import jakarta.persistence.Column;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.MappedSuperclass;
import java.time.Instant;
import lombok.Getter;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

/**
 * Adds the {@code created_at} / {@code updated_at} pair that every mutable table carries.
 *
 * <p>Both are {@link Instant}s written in UTC. {@code hibernate.jdbc.time_zone=UTC} makes the JDBC
 * driver store them without applying the server's local offset, so the values in the database are
 * directly comparable regardless of where the application runs.
 */
@Getter
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class AuditedEntity {

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
}
