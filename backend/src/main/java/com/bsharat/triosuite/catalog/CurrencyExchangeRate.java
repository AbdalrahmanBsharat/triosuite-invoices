package com.bsharat.triosuite.catalog;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.MapsId;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * The current rate suggested for a currency when a new invoice is created.
 *
 * <p>{@code rateToBase} is how many base-currency units one unit of {@code currencyCode} is worth —
 * with ILS as the base, USD sits at {@code 3.650000}. This value is only ever a <em>suggestion</em>:
 * the rate an invoice actually uses is copied onto the invoice at save time and never re-read from
 * here, so editing a rate cannot retroactively change a document (ADR-0003).
 */
@Entity
@Getter
@Setter
@Table(name = "currency_exchange_rates")
public class CurrencyExchangeRate {

    @Id
    @Column(name = "currency_code", length = 3, nullable = false)
    private String currencyCode;

    @MapsId
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "currency_code", nullable = false)
    private Currency currency;

    @Column(name = "rate_to_base", nullable = false, precision = 19, scale = 6)
    private BigDecimal rateToBase;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
}
