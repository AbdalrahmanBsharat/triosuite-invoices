package com.bsharat.triosuite.invoice;

import jakarta.persistence.LockModeType;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** The per-year invoice-number counters. */
public interface InvoiceSequenceRepository extends JpaRepository<InvoiceSequence, InvoiceSequence.Key> {

    /**
     * Loads the counter for a prefix and year under a write lock.
     *
     * <p>Issues {@code SELECT ... FOR UPDATE}. Callers must already be inside the transaction that
     * inserts the invoice, so the lock is held for exactly as long as the allocation takes and two
     * concurrent creates cannot read the same {@code next_value} (ADR-0005).
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT s FROM InvoiceSequence s WHERE s.id.prefix = :prefix AND s.id.year = :year")
    Optional<InvoiceSequence> findForUpdate(@Param("prefix") String prefix, @Param("year") int year);

    /**
     * Whether a counter exists for this prefix and year.
     *
     * <p>Deliberately a scalar count rather than a {@code findById}. Loading the entity here would
     * put it in the persistence context, and the {@code FOR UPDATE} read that follows would then
     * return that already-loaded instance with its stale {@code next_value} instead of the row the
     * lock just protected — which is precisely how two concurrent creates end up with the same
     * invoice number.
     */
    @Query("SELECT COUNT(s) FROM InvoiceSequence s WHERE s.id.prefix = :prefix AND s.id.year = :year")
    long countFor(@Param("prefix") String prefix, @Param("year") int year);
}
