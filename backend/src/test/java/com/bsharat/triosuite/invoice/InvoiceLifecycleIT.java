package com.bsharat.triosuite.invoice;

import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.bsharat.triosuite.support.AbstractIntegrationTest;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

/**
 * The invoice state machine end to end: create, edit, approve, refuse to edit, cancel, and confirm
 * the record survives cancellation.
 */
class InvoiceLifecycleIT extends AbstractIntegrationTest {

    private static final String DRAFT_BODY = """
            {
              "customerId": %d,
              "currencyCode": "ILS",
              "exchangeRate": "1.000000",
              "taxMode": "EXCLUSIVE",
              "issueDate": "2026-09-06",
              "notes": "Created by the lifecycle test",
              "lines": [ {"itemId": %d, "quantity": "2.000", "unitPrice": "100.0000"} ]
            }""".formatted(CUSTOMER_ACTIVE, ITEM_LAPTOP);

    // =================================================================================
    // Create
    // =================================================================================

    @Test
    @DisplayName("creating returns 201 with a Location header, a DRAFT status and version 0")
    void createReturnsCreatedDraft() throws Exception {
        createDraft(adminToken())
                .andExpect(status().isCreated())
                .andExpect(header().exists(HttpHeaders.LOCATION))
                .andExpect(jsonPath("$.status").value("DRAFT"))
                .andExpect(jsonPath("$.version").value(0))
                .andExpect(jsonPath("$.invoiceNumber").value("INV-2026-000007"))
                .andExpect(jsonPath("$.createdBy").value("System Administrator"))
                .andExpect(jsonPath("$.approvedAt").doesNotExist())
                .andExpect(jsonPath("$.cancelledAt").doesNotExist());
    }

    @Test
    @DisplayName("the number continues the seeded sequence and increments per invoice")
    void numbersAreSequential() throws Exception {
        String token = adminToken();

        createDraft(token).andExpect(jsonPath("$.invoiceNumber").value("INV-2026-000007"));
        createDraft(token).andExpect(jsonPath("$.invoiceNumber").value("INV-2026-000008"));
        createDraft(token).andExpect(jsonPath("$.invoiceNumber").value("INV-2026-000009"));
    }

    @Test
    @DisplayName("a number sent by the client is ignored; the server allocates its own")
    void clientSuppliedNumberIsIgnored() throws Exception {
        mockMvc.perform(post("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "invoiceNumber": "INV-1999-000001",
                                  "customerId": %d,
                                  "currencyCode": "ILS",
                                  "exchangeRate": "1.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": []
                                }""".formatted(CUSTOMER_ACTIVE)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.invoiceNumber").value("INV-2026-000007"));
    }

    @Test
    @DisplayName("a new year starts its own sequence at 000001")
    void sequenceRestartsPerYear() throws Exception {
        mockMvc.perform(post("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerId": %d,
                                  "currencyCode": "ILS",
                                  "exchangeRate": "1.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2027-01-04",
                                  "lines": []
                                }""".formatted(CUSTOMER_ACTIVE)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.invoiceNumber").value("INV-2027-000001"));
    }

    @Test
    @DisplayName("an inactive customer is rejected")
    void inactiveCustomerIsRejected() throws Exception {
        mockMvc.perform(post("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerId": %d,
                                  "currencyCode": "ILS",
                                  "exchangeRate": "1.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": []
                                }""".formatted(CUSTOMER_INACTIVE)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.detail").value(
                        "Customer 'Sahara Logistics' is inactive and cannot be invoiced"));
    }

    @Test
    @DisplayName("an unknown currency is rejected")
    void unknownCurrencyIsRejected() throws Exception {
        mockMvc.perform(post("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerId": %d,
                                  "currencyCode": "XYZ",
                                  "exchangeRate": "1.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": []
                                }""".formatted(CUSTOMER_ACTIVE)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    @DisplayName("an invoice in the base currency is pinned to a rate of exactly 1")
    void baseCurrencyRateIsForcedToOne() throws Exception {
        mockMvc.perform(post("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerId": %d,
                                  "currencyCode": "JOD",
                                  "exchangeRate": "99.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": [ {"itemId": %d, "quantity": "1.000", "unitPrice": "100.0000"} ]
                                }""".formatted(CUSTOMER_ACTIVE, ITEM_LAPTOP)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.exchangeRate").value(1.000000))
                .andExpect(jsonPath("$.grandTotal").value(116.000))
                .andExpect(jsonPath("$.grandTotalBase").value(116.000));
    }

    // =================================================================================
    // Update
    // =================================================================================

    @Test
    @DisplayName("a draft can be replaced, which bumps its version")
    void draftCanBeUpdated() throws Exception {
        String token = adminToken();
        String created = createDraft(token).andReturn().getResponse().getContentAsString();
        int id = JsonPath.read(created, "$.id");

        mockMvc.perform(put("/api/invoices/" + id)
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "version": 0,
                                  "customerId": %d,
                                  "currencyCode": "ILS",
                                  "exchangeRate": "1.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "notes": "Revised",
                                  "lines": [ {"itemId": %d, "quantity": "5.000", "unitPrice": "10.0000"} ]
                                }""".formatted(CUSTOMER_ACTIVE, ITEM_PAPER)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.version").value(1))
                .andExpect(jsonPath("$.notes").value("Revised"))
                .andExpect(jsonPath("$.lines.length()").value(1))
                .andExpect(jsonPath("$.lines[0].quantity").value(5.000))
                .andExpect(jsonPath("$.subtotal").value(50.00))
                .andExpect(jsonPath("$.grandTotal").value(58.00));
    }

    @Test
    @DisplayName("updating with a stale version is 409 STALE_VERSION")
    void staleVersionOnUpdateIsRejected() throws Exception {
        String token = adminToken();
        String created = createDraft(token).andReturn().getResponse().getContentAsString();
        int id = JsonPath.read(created, "$.id");

        mockMvc.perform(put("/api/invoices/" + id)
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "version": 99,
                                  "customerId": %d,
                                  "currencyCode": "ILS",
                                  "exchangeRate": "1.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": []
                                }""".formatted(CUSTOMER_ACTIVE)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("STALE_VERSION"));
    }

    @Test
    @DisplayName("updating an unknown invoice is 404")
    void updatingUnknownInvoiceIsNotFound() throws Exception {
        mockMvc.perform(put("/api/invoices/999999")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "version": 0,
                                  "customerId": %d,
                                  "currencyCode": "ILS",
                                  "exchangeRate": "1.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": []
                                }""".formatted(CUSTOMER_ACTIVE)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_FOUND"));
    }

    // =================================================================================
    // Approve
    // =================================================================================

    @Test
    @DisplayName("approving a draft stamps who approved it and when")
    void approveStampsTheAudit() throws Exception {
        String token = adminToken();
        String created = createDraft(token).andReturn().getResponse().getContentAsString();
        int id = JsonPath.read(created, "$.id");

        mockMvc.perform(post("/api/invoices/" + id + "/approve")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"version": 0}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"))
                .andExpect(jsonPath("$.version").value(1))
                .andExpect(jsonPath("$.approvedBy").value("System Administrator"))
                .andExpect(jsonPath("$.approvedAt").isNotEmpty());
    }

    @Test
    @DisplayName("SALES may approve, which is the one write beyond drafts that role has")
    void salesMayApprove() throws Exception {
        String token = salesToken();
        String created = createDraft(token).andReturn().getResponse().getContentAsString();
        int id = JsonPath.read(created, "$.id");

        mockMvc.perform(post("/api/invoices/" + id + "/approve")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"version": 0}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.approvedBy").value("Sales Representative"));
    }

    @Test
    @DisplayName("an invoice with no lines cannot be approved")
    void approvingAnEmptyInvoiceIsRejected() throws Exception {
        String token = adminToken();
        String created = mockMvc.perform(post("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "customerId": %d,
                                  "currencyCode": "ILS",
                                  "exchangeRate": "1.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": []
                                }""".formatted(CUSTOMER_ACTIVE)))
                .andReturn().getResponse().getContentAsString();
        int id = JsonPath.read(created, "$.id");

        mockMvc.perform(post("/api/invoices/" + id + "/approve")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"version": 0}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.detail").value(
                        "An invoice must have at least one line before it can be approved"));
    }

    @Test
    @DisplayName("approving with a stale version is 409 STALE_VERSION")
    void staleVersionOnApproveIsRejected() throws Exception {
        mockMvc.perform(post("/api/invoices/" + INVOICE_DRAFT + "/approve")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"version": 42}"""))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("STALE_VERSION"));
    }

    @Test
    @DisplayName("approving something already approved is 409 INVALID_TRANSITION")
    void approvingAnApprovedInvoiceIsRejected() throws Exception {
        mockMvc.perform(post("/api/invoices/" + INVOICE_APPROVED + "/approve")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"version": 0}"""))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVALID_TRANSITION"))
                .andExpect(jsonPath("$.detail").value(
                        "Invoice INV-2026-000001 is APPROVED and cannot be approved"));
    }

    // =================================================================================
    // Approved invoices are locked
    // =================================================================================

    @Test
    @DisplayName("editing an approved invoice is 409 INVOICE_NOT_EDITABLE")
    void approvedInvoiceCannotBeEdited() throws Exception {
        mockMvc.perform(put("/api/invoices/" + INVOICE_APPROVED)
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "version": 0,
                                  "customerId": %d,
                                  "currencyCode": "ILS",
                                  "exchangeRate": "1.000000",
                                  "taxMode": "EXCLUSIVE",
                                  "issueDate": "2026-09-06",
                                  "lines": []
                                }""".formatted(CUSTOMER_ACTIVE)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVOICE_NOT_EDITABLE"))
                .andExpect(jsonPath("$.detail").value(
                        "Invoice INV-2026-000001 is APPROVED and can no longer be edited"));
    }

    @Test
    @DisplayName("editing a cancelled invoice is 409 INVOICE_NOT_EDITABLE")
    void cancelledInvoiceCannotBeEdited() throws Exception {
        mockMvc.perform(put("/api/invoices/" + INVOICE_CANCELLED)
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "version": 0,
                                  "customerId": %d,
                                  "currencyCode": "EUR",
                                  "exchangeRate": "3.940000",
                                  "taxMode": "INCLUSIVE",
                                  "issueDate": "2026-06-22",
                                  "lines": []
                                }""".formatted(CUSTOMER_ACTIVE)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVOICE_NOT_EDITABLE"));
    }

    // =================================================================================
    // Cancel
    // =================================================================================

    @Test
    @DisplayName("an approved invoice can be cancelled, with a reason, and is still readable")
    void approvedInvoiceCanBeCancelled() throws Exception {
        String token = adminToken();

        mockMvc.perform(post("/api/invoices/" + INVOICE_APPROVED + "/cancel")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"version": 0, "reason": "Customer withdrew the order"}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"))
                .andExpect(jsonPath("$.cancelledBy").value("System Administrator"))
                .andExpect(jsonPath("$.cancelledAt").isNotEmpty())
                .andExpect(jsonPath("$.cancellationReason").value("Customer withdrew the order"))
                // The approval stamp survives: the document was approved, then withdrawn.
                .andExpect(jsonPath("$.approvedAt").isNotEmpty());

        mockMvc.perform(get("/api/invoices/" + INVOICE_APPROVED)
                        .header(HttpHeaders.AUTHORIZATION, token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.invoiceNumber").value("INV-2026-000001"))
                .andExpect(jsonPath("$.status").value("CANCELLED"))
                .andExpect(jsonPath("$.grandTotal").value(10443.25))
                .andExpect(jsonPath("$.lines.length()").value(3));
    }

    @Test
    @DisplayName("a draft can be cancelled without ever being approved")
    void draftCanBeCancelled() throws Exception {
        mockMvc.perform(post("/api/invoices/" + INVOICE_DRAFT + "/cancel")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"version": 0}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"))
                .andExpect(jsonPath("$.approvedAt").doesNotExist())
                .andExpect(jsonPath("$.cancellationReason").doesNotExist());
    }

    @Test
    @DisplayName("cancelling something already cancelled is 409 INVALID_TRANSITION")
    void cancellingACancelledInvoiceIsRejected() throws Exception {
        mockMvc.perform(post("/api/invoices/" + INVOICE_CANCELLED + "/cancel")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"version": 0}"""))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVALID_TRANSITION"))
                .andExpect(jsonPath("$.detail").value(
                        "Invoice INV-2026-000004 is CANCELLED and cannot be cancelled"));
    }

    @Test
    @DisplayName("cancelled invoices stay in the list under their status filter")
    void cancelledInvoicesRemainListed() throws Exception {
        mockMvc.perform(get("/api/invoices")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .param("status", "CANCELLED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(2))
                .andExpect(jsonPath("$.content[*].status").value(
                        everyItem(is("CANCELLED"))));
    }

    @Test
    @DisplayName("there is no endpoint that deletes an invoice")
    void thereIsNoDeleteEndpoint() throws Exception {
        mockMvc.perform(delete("/api/invoices/" + INVOICE_DRAFT)
                        .header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isMethodNotAllowed());
    }

    // =================================================================================
    // Helpers
    // =================================================================================

    private ResultActions createDraft(String token) throws Exception {
        return mockMvc.perform(post("/api/invoices")
                .header(HttpHeaders.AUTHORIZATION, token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(DRAFT_BODY));
    }
}
