package com.bsharat.triosuite.catalog.dto;

import com.bsharat.triosuite.catalog.Item;
import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;

/**
 * A catalogue item, as returned by search and by barcode lookup.
 *
 * @param id           identifier
 * @param sku          stock-keeping unit
 * @param barcode      EAN-13, when the item is labelled
 * @param name         display name, snapshotted onto the invoice line
 * @param unitPrice    catalogue price in currencyCode
 * @param currencyCode the currency unitPrice is quoted in
 * @param taxRate      default tax rate as a decimal fraction, e.g. 0.1600
 * @param active       inactive items cannot be added to a new invoice
 */
@Schema(name = "Item")
public record ItemResponse(
        Long id,
        @Schema(example = "LAP-1401") String sku,
        @Schema(example = "7290001000014") String barcode,
        @Schema(example = "Ergonomic Office Chair") String name,
        @Schema(example = "4299.0000") BigDecimal unitPrice,
        @Schema(example = "ILS") String currencyCode,
        @Schema(example = "0.1600") BigDecimal taxRate,
        boolean active) {

    public static ItemResponse from(Item item) {
        return new ItemResponse(item.getId(), item.getSku(), item.getBarcode(), item.getName(),
                item.getUnitPrice(), item.getCurrency().getCode(), item.getTaxRate(), item.isActive());
    }
}
