package com.bsharat.triosuite.catalog;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

/** Currency lookups. */
public interface CurrencyRepository extends JpaRepository<Currency, String> {

    /** All currencies that may be used on a new invoice, alphabetically. */
    List<Currency> findByActiveTrueOrderByCodeAsc();
}
