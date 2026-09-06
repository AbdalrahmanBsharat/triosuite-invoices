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
}
