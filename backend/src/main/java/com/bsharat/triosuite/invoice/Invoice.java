package com.bsharat.triosuite.invoice;

import com.bsharat.triosuite.catalog.Currency;
import com.bsharat.triosuite.catalog.Customer;
import com.bsharat.triosuite.common.jpa.AuditedEntity;
import com.bsharat.triosuite.user.User;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import lombok.Getter;
import lombok.Setter;

/**
 * A sales invoice — the aggregate root.
 *
 * <p>Invoices are never deleted. {@link InvoiceStatus#CANCELLED} is how one is withdrawn, and the
 * record stays in the list under its status filter for ever.
 *
 * <p>{@code exchangeRate} and all four totals are snapshots written by the server. The client may
 * send its own preview of the totals; they are ignored and recomputed from the lines by
 * {@link InvoiceCalculator} on every write.
 */
@Entity
@Getter
@Setter
@Table(name = "invoices")
public class Invoice extends AuditedEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** {@code INV-YYYY-000001}. Allocated by the server; a client may never supply one. */
    @Column(name = "invoice_number", nullable = false, length = 20, unique = true, updatable = false)
    private String invoiceNumber;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "customer_id", nullable = false)
    private Customer customer;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "currency_code", nullable = false)
    private Currency currency;

    /** Base-currency units per one invoice-currency unit, snapshotted when the invoice is saved. */
    @Column(name = "exchange_rate", nullable = false, precision = 19, scale = 6)
    private BigDecimal exchangeRate;

    @Enumerated(EnumType.STRING)
    @Column(name = "tax_mode", nullable = false, length = 10)
    private TaxMode taxMode;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private InvoiceStatus status = InvoiceStatus.DRAFT;

    @Column(name = "issue_date", nullable = false)
    private LocalDate issueDate;

    @Column(length = 1000)
    private String notes;

    @Column(nullable = false, precision = 19, scale = 4)
    private BigDecimal subtotal;

    @Column(name = "tax_total", nullable = false, precision = 19, scale = 4)
    private BigDecimal taxTotal;

    @Column(name = "grand_total", nullable = false, precision = 19, scale = 4)
    private BigDecimal grandTotal;

    @Column(name = "grand_total_base", nullable = false, precision = 19, scale = 4)
    private BigDecimal grandTotalBase;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "created_by", nullable = false, updatable = false)
    private User createdBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "approved_by")
    private User approvedBy;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cancelled_by")
    private User cancelledBy;

    @Column(name = "cancelled_at")
    private Instant cancelledAt;

    @Column(name = "cancellation_reason", length = 500)
    private String cancellationReason;

    /**
     * Optimistic lock. Returned in every response and required on every mutating call; a mismatch
     * is reported as {@code 409 STALE_VERSION} rather than silently overwriting someone's work.
     */
    @Version
    @Column(nullable = false)
    private Long version;

    @OrderBy("lineNo ASC")
    @OneToMany(mappedBy = "invoice", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<InvoiceLine> lines = new ArrayList<>();

    /** Replaces every line, keeping both sides of the association consistent. */
    public void replaceLines(List<InvoiceLine> newLines) {
        lines.clear();
        int lineNo = 1;
        for (InvoiceLine line : newLines) {
            line.setInvoice(this);
            line.setLineNo(lineNo++);
            lines.add(line);
        }
    }
}
