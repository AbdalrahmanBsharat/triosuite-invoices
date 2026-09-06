package com.bsharat.triosuite.invoice;

import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

/** Invoice persistence. */
public interface InvoiceRepository extends JpaRepository<Invoice, Long>, JpaSpecificationExecutor<Invoice> {

    /**
     * Lists invoices matching a specification.
     *
     * <p>Overridden purely to attach the entity graph: without it, rendering a page of summaries
     * would lazily load each row's customer and currency one query at a time. Both are to-one
     * associations, so the fetch join cannot multiply rows and pagination stays in the database.
     */
    @Override
    @EntityGraph(attributePaths = {"customer", "currency"})
    Page<Invoice> findAll(Specification<Invoice> specification, Pageable pageable);

    /**
     * Loads one invoice with everything the detail response needs: lines and their items, the
     * customer, the currency and all three audit accounts.
     */
    @EntityGraph(attributePaths = {
            "customer", "currency", "createdBy", "approvedBy", "cancelledBy", "lines", "lines.item"})
    Optional<Invoice> findDetailById(Long id);

    /** Whether a number has already been used. The unique index is the real guard; this reads it. */
    boolean existsByInvoiceNumber(String invoiceNumber);
}
