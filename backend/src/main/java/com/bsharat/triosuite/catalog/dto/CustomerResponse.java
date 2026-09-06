package com.bsharat.triosuite.catalog.dto;

import com.bsharat.triosuite.catalog.Customer;
import io.swagger.v3.oas.annotations.media.Schema;

/**
 * A customer, as offered in the picker on the Create Invoice screen.
 *
 * @param id      identifier
 * @param name    company or person billed
 * @param email   billing e-mail, if known
 * @param phone   contact number, if known
 * @param address postal address, if known
 * @param active  inactive customers cannot be put on a new invoice
 */
@Schema(name = "Customer")
public record CustomerResponse(
        Long id,
        @Schema(example = "Al-Quds Trading Co.") String name,
        String email,
        String phone,
        String address,
        boolean active) {

    public static CustomerResponse from(Customer customer) {
        return new CustomerResponse(customer.getId(), customer.getName(), customer.getEmail(),
                customer.getPhone(), customer.getAddress(), customer.isActive());
    }
}
