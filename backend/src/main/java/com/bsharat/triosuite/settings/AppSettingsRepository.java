package com.bsharat.triosuite.settings;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

/** Access to the single application-settings row. */
public interface AppSettingsRepository extends JpaRepository<AppSettings, Byte> {

    /** Loads the settings row with both currency associations already resolved. */
    @Query("SELECT s FROM AppSettings s JOIN FETCH s.baseCurrency JOIN FETCH s.defaultCurrency")
    Optional<AppSettings> findSingleton();
}
