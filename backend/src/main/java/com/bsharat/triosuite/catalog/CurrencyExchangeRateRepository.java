package com.bsharat.triosuite.catalog;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

/** Exchange-rate lookups. */
public interface CurrencyExchangeRateRepository extends JpaRepository<CurrencyExchangeRate, String> {

    /** All maintained rates, alphabetically by currency. */
    List<CurrencyExchangeRate> findAllByOrderByCurrencyCodeAsc();
}
