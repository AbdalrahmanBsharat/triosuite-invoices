package com.bsharat.triosuite.settings;

import com.bsharat.triosuite.catalog.Currency;
import com.bsharat.triosuite.invoice.TaxMode;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * Company-wide configuration. Exactly one row exists, pinned to {@code id = 1} by a database CHECK
 * constraint so no code path can ever create a second.
 *
 * <p>{@code baseCurrency} is the reporting currency: every invoice also stores its grand total
 * converted into it, which is what makes a mixed-currency list comparable.
 */
@Entity
@Getter
@Setter
@Table(name = "app_settings")
public class AppSettings {

    /** The only legal value. */
    public static final byte SINGLETON_ID = 1;

    @Id
    private Byte id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "base_currency_code", nullable = false)
    private Currency baseCurrency;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "default_currency_code", nullable = false)
    private Currency defaultCurrency;

    @Enumerated(EnumType.STRING)
    @Column(name = "default_tax_mode", nullable = false, length = 10)
    private TaxMode defaultTaxMode;

    @Column(name = "default_tax_rate", nullable = false, precision = 5, scale = 4)
    private BigDecimal defaultTaxRate;

    @Column(name = "invoice_number_prefix", nullable = false, length = 10)
    private String invoiceNumberPrefix;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
}
