package com.bsharat.triosuite.invoice;

/**
 * Lifecycle of an invoice. The server is the only authority on these transitions.
 *
 * <pre>
 *   DRAFT ──approve──▶ APPROVED ──cancel──▶ CANCELLED
 *     │                                         ▲
 *     └──────────────────cancel──────────────────┘
 * </pre>
 *
 * <p>There is no transition out of {@link #CANCELLED} and no deletion at all: a cancelled invoice
 * stays in the list, visible under its status filter, because it is a financial record.
 */
public enum InvoiceStatus {

    /** Header and lines may still be changed. */
    DRAFT,

    /** Locked. Only cancellation remains possible. */
    APPROVED,

    /** Terminal. Read-only for ever. */
    CANCELLED;

    /** Whether the header and lines of an invoice in this status may still be rewritten. */
    public boolean isEditable() {
        return this == DRAFT;
    }

    /** Whether {@code approve} is a legal transition from this status. */
    public boolean canApprove() {
        return this == DRAFT;
    }

    /** Whether {@code cancel} is a legal transition from this status. */
    public boolean canCancel() {
        return this == DRAFT || this == APPROVED;
    }
}
