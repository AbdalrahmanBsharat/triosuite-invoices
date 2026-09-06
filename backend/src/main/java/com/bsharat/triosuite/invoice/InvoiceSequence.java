package com.bsharat.triosuite.invoice;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.io.Serializable;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * The counter behind {@code INV-YYYY-000001}, one row per prefix and year.
 *
 * <p>Allocation takes a {@code PESSIMISTIC_WRITE} lock on the row — a plain
 * {@code SELECT … FOR UPDATE} — inside the same transaction that inserts the invoice, so two
 * concurrent creates queue behind each other for the microsecond it takes to read and bump the
 * counter and can never be handed the same number (ADR-0005).
 */
@Entity
@Getter
@Setter
@NoArgsConstructor
@Table(name = "invoice_sequences")
public class InvoiceSequence {

    @EmbeddedId
    private Key id;

    @Column(name = "next_value", nullable = false)
    private long nextValue;

    public InvoiceSequence(String prefix, int year, long nextValue) {
        this.id = new Key(prefix, year);
        this.nextValue = nextValue;
    }

    /**
     * Composite primary key.
     *
     * @param prefix invoice-number prefix taken from application settings, e.g. {@code INV}
     * @param year   calendar year of the invoice's issue date; the counter restarts each year
     */
    @Embeddable
    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @EqualsAndHashCode
    public static class Key implements Serializable {

        @Column(name = "prefix", nullable = false, length = 10)
        private String prefix;

        @Column(name = "year", nullable = false)
        private int year;
    }
}
