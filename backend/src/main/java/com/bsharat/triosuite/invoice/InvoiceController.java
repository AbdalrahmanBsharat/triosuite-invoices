package com.bsharat.triosuite.invoice;

import com.bsharat.triosuite.common.web.PageResponse;
import com.bsharat.triosuite.invoice.dto.ApproveInvoiceRequest;
import com.bsharat.triosuite.invoice.dto.CancelInvoiceRequest;
import com.bsharat.triosuite.invoice.dto.CreateInvoiceRequest;
import com.bsharat.triosuite.invoice.dto.InvoiceResponse;
import com.bsharat.triosuite.invoice.dto.InvoiceSummaryResponse;
import com.bsharat.triosuite.invoice.dto.UpdateInvoiceRequest;
import com.bsharat.triosuite.security.AuthenticatedUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.net.URI;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Sales invoices.
 *
 * <p>There is deliberately no delete endpoint. An invoice that should not stand is cancelled, which
 * keeps the record and its audit trail intact.
 */
@RestController
@RequestMapping("/api/invoices")
@RequiredArgsConstructor
@Tag(name = "Invoices", description = "Create, edit, approve and cancel sales invoices")
public class InvoiceController {

    private final InvoiceService invoiceService;

    @GetMapping
    @Operation(
            summary = "List invoices",
            description = """
                    Paginated summaries, newest first by default. Cancelled invoices are included and
                    can be isolated with the status filter — nothing is ever hidden from the list.

                    Sortable on issueDate, invoiceNumber, grandTotal and status.""")
    public PageResponse<InvoiceSummaryResponse> list(
            @Parameter(description = "Only invoices in this status; omit for all three")
            @RequestParam(required = false) InvoiceStatus status,

            @Parameter(description = "Free-text term matched against the invoice number and the customer name")
            @RequestParam(required = false) String search,

            @PageableDefault(size = 20, sort = "issueDate", direction = Sort.Direction.DESC)
            Pageable pageable) {

        return invoiceService.list(status, search, pageable);
    }

    @GetMapping("/{id}")
    @Operation(
            summary = "Read one invoice",
            description = "The full document: header, lines, server-computed totals and audit trail.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "The invoice"),
            @ApiResponse(responseCode = "404", description = "No such invoice", content = @Content)
    })
    public InvoiceResponse get(@PathVariable Long id) {
        return invoiceService.get(id);
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'SALES')")
    @Operation(
            summary = "Create a draft invoice",
            description = """
                    Creates a DRAFT and allocates its number. The client never sends a number: it is
                    reserved server-side inside this transaction under a row lock, so concurrent
                    creates receive distinct, sequential numbers.

                    Totals are computed from the lines and cannot be supplied. Each line's tax rate is
                    taken from its catalogue item.""")
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Draft created; Location points at it"),
            @ApiResponse(responseCode = "400", description = "Invalid body, or an inactive customer, currency or item", content = @Content),
            @ApiResponse(responseCode = "401", description = "Missing or invalid access token", content = @Content)
    })
    public ResponseEntity<InvoiceResponse> create(
            @Valid @RequestBody CreateInvoiceRequest request,
            @AuthenticationPrincipal AuthenticatedUser caller) {

        InvoiceResponse created = invoiceService.create(request, caller);
        return ResponseEntity
                .created(URI.create("/api/invoices/" + created.id()))
                .body(created);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SALES')")
    @Operation(
            summary = "Replace a draft invoice",
            description = """
                    Rewrites the header and every line of a DRAFT. The number and status are not part
                    of this contract.

                    Send back the version last read. A mismatch is 409 STALE_VERSION; an invoice that
                    is no longer a draft is 409 INVOICE_NOT_EDITABLE.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Draft replaced"),
            @ApiResponse(responseCode = "400", description = "Invalid body, or an inactive customer, currency or item", content = @Content),
            @ApiResponse(responseCode = "404", description = "No such invoice", content = @Content),
            @ApiResponse(responseCode = "409", description = "STALE_VERSION or INVOICE_NOT_EDITABLE", content = @Content)
    })
    public InvoiceResponse update(
            @PathVariable Long id,
            @Valid @RequestBody UpdateInvoiceRequest request,
            @AuthenticationPrincipal AuthenticatedUser caller) {

        return invoiceService.update(id, request, caller);
    }

    @PostMapping("/{id}/approve")
    @PreAuthorize("hasAnyRole('ADMIN', 'SALES')")
    @Operation(
            summary = "Approve an invoice",
            description = """
                    DRAFT to APPROVED, stamping who approved it and when. The invoice becomes
                    read-only: every later write returns 409 INVOICE_NOT_EDITABLE.

                    An invoice with no lines cannot be approved.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Approved"),
            @ApiResponse(responseCode = "400", description = "The invoice has no lines", content = @Content),
            @ApiResponse(responseCode = "404", description = "No such invoice", content = @Content),
            @ApiResponse(responseCode = "409", description = "STALE_VERSION or INVALID_TRANSITION", content = @Content)
    })
    public InvoiceResponse approve(
            @PathVariable Long id,
            @Valid @RequestBody ApproveInvoiceRequest request,
            @AuthenticationPrincipal AuthenticatedUser caller) {

        return invoiceService.approve(id, request.version(), caller);
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(
            summary = "Cancel an invoice",
            description = """
                    DRAFT or APPROVED to CANCELLED, stamping who cancelled it, when and optionally
                    why. The record is kept and stays in the list under the Cancelled filter.

                    Administrators only.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Cancelled"),
            @ApiResponse(responseCode = "403", description = "Caller is not an administrator", content = @Content),
            @ApiResponse(responseCode = "404", description = "No such invoice", content = @Content),
            @ApiResponse(responseCode = "409", description = "STALE_VERSION or INVALID_TRANSITION", content = @Content)
    })
    public InvoiceResponse cancel(
            @PathVariable Long id,
            @Valid @RequestBody CancelInvoiceRequest request,
            @AuthenticationPrincipal AuthenticatedUser caller) {

        return invoiceService.cancel(id, request.version(), request.reason(), caller);
    }
}
