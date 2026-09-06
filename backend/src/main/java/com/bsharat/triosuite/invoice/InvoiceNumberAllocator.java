package com.bsharat.triosuite.invoice;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Allocates {@code INV-YYYY-000001} style invoice numbers.
 *
 * <p>The counter lives in {@code invoice_sequences}, one row per prefix and year. Allocation takes a
 * {@code PESSIMISTIC_WRITE} lock on that row — a plain {@code SELECT ... FOR UPDATE} — reads the
 * counter, bumps it and formats the number, all inside the caller's transaction. Two concurrent
 * creates therefore queue behind each other for the microsecond that takes and cannot be handed the
 * same value. If the transaction later rolls back, the increment rolls back with it.
 *
 * <p>{@link Propagation#MANDATORY} enforces the part that matters: this must never run in a
 * transaction of its own, or the lock would be released before the invoice row was written and the
 * same number could be handed out twice.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class InvoiceNumberAllocator {

    private final InvoiceSequenceRepository sequences;
    private final SequenceInitializer initializer;

    /**
     * Reserves the next number for a prefix and year.
     *
     * @param prefix the prefix from application settings, e.g. {@code INV}
     * @param year   the calendar year of the invoice's issue date; counters restart each year
     * @return the formatted number, e.g. {@code INV-2026-000007}
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public String allocate(String prefix, int year) {
        // Check for existence without taking a lock, on purpose. Asking for the lock on a row that
        // does not exist would make InnoDB take a gap lock, and the insert that has to follow —
        // necessarily in another transaction, so a duplicate does not doom this one — would then
        // block against a lock this very transaction holds, until the lock wait times out.
        if (sequences.countFor(prefix, year) == 0) {
            initializer.createIfAbsent(prefix, year);
        }

        // A locking read always sees the latest committed row rather than this transaction's
        // snapshot, so the row just created in another transaction is visible here.
        InvoiceSequence sequence = sequences.findForUpdate(prefix, year)
                .orElseThrow(() -> new IllegalStateException(
                        "Invoice sequence " + prefix + "/" + year + " could not be created"));

        long allocated = sequence.getNextValue();
        sequence.setNextValue(allocated + 1);

        return "%s-%04d-%06d".formatted(prefix, year, allocated);
    }

    /**
     * Creates a missing sequence row in a transaction of its own.
     *
     * <p>Separate so that losing the race to a concurrent request costs only this rolled-back
     * insert. Rolling a duplicate-key violation back inside the caller's transaction would doom the
     * whole invoice creation.
     */
    @Slf4j
    @Service
    @RequiredArgsConstructor
    public static class SequenceInitializer {

        private final InvoiceSequenceRepository sequences;

        /** Inserts the row, treating a concurrent insert of the same row as success. */
        @Transactional(propagation = Propagation.REQUIRES_NEW)
        public void createIfAbsent(String prefix, int year) {
            try {
                sequences.saveAndFlush(new InvoiceSequence(prefix, year, 1L));
                log.info("Started invoice number sequence {}/{}", prefix, year);
            } catch (DataIntegrityViolationException e) {
                // Another request created it first, which is exactly the outcome wanted.
                log.debug("Invoice sequence {}/{} already existed", prefix, year);
            }
        }
    }
}
