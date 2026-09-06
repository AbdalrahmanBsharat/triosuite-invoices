package com.bsharat.triosuite.invoice;

import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.List;
import org.springframework.data.jpa.domain.Specification;

/**
 * Filters for the invoice list.
 *
 * <p>Built as Criteria predicates rather than a JPQL string with optional clauses: the filters are
 * genuinely optional and composing them here keeps every value a bound parameter, so nothing a user
 * types is ever concatenated into SQL.
 */
public final class InvoiceSpecifications {

    private InvoiceSpecifications() {
    }

    /**
     * Matches invoices with the given status and search term. Either may be omitted.
     *
     * @param status only invoices in this status; null matches all three
     * @param search matched case-insensitively against the invoice number and the customer name;
     *               null or blank matches everything
     */
    public static Specification<Invoice> matching(InvoiceStatus status, String search) {
        return (root, query, builder) -> {
            List<Predicate> predicates = new ArrayList<>(2);

            if (status != null) {
                predicates.add(builder.equal(root.get("status"), status));
            }

            if (search != null && !search.isBlank()) {
                String pattern = "%" + search.trim().toLowerCase() + "%";
                predicates.add(builder.or(
                        builder.like(builder.lower(root.get("invoiceNumber")), pattern),
                        builder.like(builder.lower(root.get("customer").get("name")), pattern)));
            }

            return predicates.isEmpty()
                    ? builder.conjunction()
                    : builder.and(predicates.toArray(Predicate[]::new));
        };
    }
}
