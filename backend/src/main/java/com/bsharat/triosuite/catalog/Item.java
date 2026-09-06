package com.bsharat.triosuite.catalog;

import com.bsharat.triosuite.common.jpa.AuditedEntity;
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
 * A catalogue entry that can be added to an invoice, by search or by scanning its barcode.
 *
 * <p>{@code unitPrice} and {@code taxRate} are <em>defaults</em>. When a line is written they are
 * copied onto {@link com.bsharat.triosuite.invoice.InvoiceLine}, so re-pricing an item never
 * changes an invoice that has already been issued (ADR-0004).
 */
@Entity
@Getter
@Setter
@Table(name = "items")
public class Item extends AuditedEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50, unique = true)
    private String sku;

    /** EAN-13 for the seeded catalogue. Nullable, because not every item is physically labelled. */
    @Column(length = 64, unique = true)
    private String barcode;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(name = "unit_price", nullable = false, precision = 19, scale = 4)
    private BigDecimal unitPrice;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "currency_code", nullable = false)
    private Currency currency;

    @Column(name = "tax_rate", nullable = false, precision = 5, scale = 4)
    private BigDecimal taxRate;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;
}
