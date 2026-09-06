package com.bsharat.triosuite.invoice;

/**
 * How a line's unit price relates to tax. Chosen per invoice and applied to every line on it.
 */
public enum TaxMode {

    /** The unit price is net; tax is added on top. */
    EXCLUSIVE,

    /** The unit price already contains the tax; the net amount is extracted from it. */
    INCLUSIVE
}
