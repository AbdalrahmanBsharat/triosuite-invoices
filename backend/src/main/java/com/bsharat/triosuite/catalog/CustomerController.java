package com.bsharat.triosuite.catalog;

import com.bsharat.triosuite.catalog.dto.CustomerResponse;
import com.bsharat.triosuite.common.web.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Customer lookup for the picker on the Create Invoice screen. */
@RestController
@RequestMapping("/api/customers")
@RequiredArgsConstructor
@Tag(name = "Customers", description = "Customers available for invoicing")
public class CustomerController {

    private final CatalogService catalog;

    @GetMapping
    @Operation(
            summary = "Search customers",
            description = """
                    Active customers only, matched case-insensitively on name, e-mail or phone.
                    Omit the search term to list them all.""")
    public PageResponse<CustomerResponse> search(
            @Parameter(description = "Free-text term matched against name, e-mail and phone")
            @RequestParam(required = false) String search,
            @PageableDefault(size = 20, sort = "name", direction = Sort.Direction.ASC) Pageable pageable) {

        return catalog.searchCustomers(search, pageable);
    }
}
