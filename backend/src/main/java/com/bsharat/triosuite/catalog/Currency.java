package com.bsharat.triosuite.catalog;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * An ISO 4217 currency.
 *
 * <p>{@code minorUnits} is the number of decimal places the currency is quoted in and drives every
 * rounding decision in {@link com.bsharat.triosuite.invoice.InvoiceCalculator}: 2 for ILS, USD, EUR
 * and GBP, 3 for JOD.
 */
@Entity
@Getter
@Setter
@Table(name = "currencies")
public class Currency {

    @Id
    @Column(length = 3, nullable = false)
    private String code;

    @Column(nullable = false, length = 60)
    private String name;

    @Column(nullable = false, length = 8)
    private String symbol;

    @Column(name = "minor_units", nullable = false)
    private int minorUnits;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;
}
