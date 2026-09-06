package com.bsharat.triosuite.catalog;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Customer lookups. */
public interface CustomerRepository extends JpaRepository<Customer, Long> {

    /**
     * Active customers whose name, e-mail or phone contains the search term.
     *
     * <p>A null or blank term returns every active customer. The comparison is case-insensitive
     * because the schema uses the utf8mb4_0900_ai_ci collation; LOWER is applied anyway so the
     * behaviour does not depend on it.
     */
    @Query("""
            SELECT c FROM Customer c
            WHERE c.active = true
              AND (:search IS NULL
                   OR LOWER(c.name) LIKE :search
                   OR LOWER(COALESCE(c.email, '')) LIKE :search
                   OR LOWER(COALESCE(c.phone, '')) LIKE :search)
            """)
    Page<Customer> search(@Param("search") String search, Pageable pageable);
}
