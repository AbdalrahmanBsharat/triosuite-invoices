package com.bsharat.triosuite.catalog;

import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Catalogue lookups, by search and by barcode. */
public interface ItemRepository extends JpaRepository<Item, Long> {

    /**
     * Active items whose name, SKU or barcode contains the search term.
     *
     * <p>A null or blank term returns the whole active catalogue. The currency association is
     * fetched with the row so building a page of responses costs one query, not one per item.
     */
    @EntityGraph(attributePaths = "currency")
    @Query("""
            SELECT i FROM Item i
            WHERE i.active = true
              AND (:search IS NULL
                   OR LOWER(i.name) LIKE :search
                   OR LOWER(i.sku) LIKE :search
                   OR LOWER(COALESCE(i.barcode, '')) LIKE :search)
            """)
    Page<Item> search(@Param("search") String search, Pageable pageable);

    /** The item carrying this exact barcode, active or not. */
    @EntityGraph(attributePaths = "currency")
    Optional<Item> findByBarcode(String barcode);

    /** Loads an item for use on an invoice line, with its currency resolved. */
    @EntityGraph(attributePaths = "currency")
    Optional<Item> findWithCurrencyById(Long id);
}
