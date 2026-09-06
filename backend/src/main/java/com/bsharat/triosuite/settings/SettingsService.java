package com.bsharat.triosuite.settings;

import com.bsharat.triosuite.catalog.Currency;
import com.bsharat.triosuite.catalog.CurrencyRepository;
import com.bsharat.triosuite.common.error.ApiException;
import com.bsharat.triosuite.settings.dto.SettingsResponse;
import com.bsharat.triosuite.settings.dto.UpdateSettingsRequest;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Reads and maintains the single application-settings row.
 *
 * <p>Settings are read on nearly every invoice operation — the base currency for reporting totals,
 * the prefix for numbering — so {@link #require()} is the one accessor everything else uses and the
 * absence of the row is treated as a broken deployment rather than a runtime condition to handle.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SettingsService {

    private final AppSettingsRepository settings;
    private final CurrencyRepository currencies;

    /**
     * Loads the settings row.
     *
     * @throws IllegalStateException if it is missing, which can only mean the seed migration did not
     *                               run; there is no sensible default to invent for a base currency
     */
    @Transactional(readOnly = true)
    public AppSettings require() {
        return settings.findSingleton().orElseThrow(() -> new IllegalStateException(
                "Application settings row is missing. Flyway migration V2 has not been applied."));
    }

    /** The current settings, for {@code GET /api/settings}. */
    @Transactional(readOnly = true)
    public SettingsResponse get() {
        return SettingsResponse.from(require());
    }

    /**
     * Replaces the settings, for {@code PUT /api/settings}.
     *
     * <p>Changing the base currency does not rewrite existing invoices: each one keeps the
     * {@code grand_total_base} computed at the rate it was issued with, because that figure is part
     * of the historical record.
     *
     * @throws ApiException with {@code VALIDATION_ERROR} if either currency is unknown or inactive
     */
    @Transactional
    public SettingsResponse update(UpdateSettingsRequest request) {
        AppSettings current = require();

        Currency base = activeCurrency(request.baseCurrencyCode(), "baseCurrencyCode");
        Currency preferred = activeCurrency(request.defaultCurrencyCode(), "defaultCurrencyCode");

        current.setBaseCurrency(base);
        current.setDefaultCurrency(preferred);
        current.setDefaultTaxMode(request.defaultTaxMode());
        current.setDefaultTaxRate(request.defaultTaxRate());
        current.setInvoiceNumberPrefix(request.invoiceNumberPrefix());
        current.setUpdatedAt(Instant.now());

        log.info("Settings updated: base={}, default={}, mode={}, prefix={}",
                base.getCode(), preferred.getCode(), request.defaultTaxMode(),
                request.invoiceNumberPrefix());

        return SettingsResponse.from(current);
    }

    private Currency activeCurrency(String code, String field) {
        Currency currency = currencies.findById(code)
                .orElseThrow(() -> ApiException.invalid(field + " '" + code + "' is not a known currency"));
        if (!currency.isActive()) {
            throw ApiException.invalid(field + " '" + code + "' is not active");
        }
        return currency;
    }
}
