package com.bsharat.triosuite.user;

/**
 * Application roles.
 *
 * <p>Spring Security sees these as the authorities {@code ROLE_ADMIN} and {@code ROLE_SALES}.
 *
 * <ul>
 *   <li>{@link #SALES} — reads everything; creates and edits drafts; approves.</li>
 *   <li>{@link #ADMIN} — everything SALES can do, plus cancelling invoices and maintaining
 *       settings and exchange rates.</li>
 * </ul>
 */
public enum Role {

    ADMIN,
    SALES;

    /** The Spring Security authority name for this role. */
    public String authority() {
        return "ROLE_" + name();
    }
}
