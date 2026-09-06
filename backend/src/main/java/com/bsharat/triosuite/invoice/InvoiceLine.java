package com.bsharat.triosuite.invoice;

import com.bsharat.triosuite.catalog.Item;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import lombok.Getter;
import lombok.Setter;

/**
 * One priced line of an invoice.
 *
 * <p>{@code itemNameSnapshot}, {@code barcodeSnapshot}, {@code unitPrice} and {@code taxRate} are
 * copies taken from the catalogue at write time. The {@code item} association is kept for
 * traceability, but nothing on this row is ever re-read through it: an approved invoice must render
 * identically in five years, whatever has happened to the catalogue since (ADR-0004).
 *
 * <p>Lines are replaced wholesale when a draft is updated, so they carry no audit columns of their
 * own — the parent invoice's {@code updated_at} covers them.
 */
@Entity
@Getter
@Setter
@Table(name = "invoice_lines")
public class InvoiceLine {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "invoice_id", nullable = false)
    private Invoice invoice;

    /** Position on the invoice, 1-based and unique within it. Assigned by the server. */
    @Column(name = "line_no", nullable = false)
    private int lineNo;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "item_id", nullable = false)
    private Item item;

    @Column(name = "item_name_snapshot", nullable = false, length = 200)
    private String itemNameSnapshot;

    @Column(name = "barcode_snapshot", length = 64)
    private String barcodeSnapshot;

    @Column(nullable = false, precision = 12, scale = 3)
    private BigDecimal quantity;

    @Column(name = "unit_price", nullable = false, precision = 19, scale = 4)
    private BigDecimal unitPrice;

    @Column(name = "tax_rate", nullable = false, precision = 5, scale = 4)
    private BigDecimal taxRate;

    @Column(name = "net_amount", nullable = false, precision = 19, scale = 4)
    private BigDecimal netAmount;

    @Column(name = "tax_amount", nullable = false, precision = 19, scale = 4)
    private BigDecimal taxAmount;

    @Column(name = "gross_amount", nullable = false, precision = 19, scale = 4)
    private BigDecimal grossAmount;

    /**
     * Copies every value except the identity and the parent link.
     *
     * <p>Used by {@link Invoice#replaceLines(java.util.List)} to rewrite a line in place. The line
     * number is deliberately not copied: it is assigned by position there.
     */
    void copyValuesFrom(InvoiceLine source) {
        this.item = source.item;
        this.itemNameSnapshot = source.itemNameSnapshot;
        this.barcodeSnapshot = source.barcodeSnapshot;
        this.quantity = source.quantity;
        this.unitPrice = source.unitPrice;
        this.taxRate = source.taxRate;
        this.netAmount = source.netAmount;
        this.taxAmount = source.taxAmount;
        this.grossAmount = source.grossAmount;
    }
}
