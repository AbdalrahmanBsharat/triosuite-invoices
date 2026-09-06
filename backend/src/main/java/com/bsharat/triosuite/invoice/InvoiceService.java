package com.bsharat.triosuite.invoice;

import com.bsharat.triosuite.catalog.CatalogService;
import com.bsharat.triosuite.catalog.Currency;
import com.bsharat.triosuite.catalog.CurrencyRepository;
import com.bsharat.triosuite.catalog.Customer;
import com.bsharat.triosuite.catalog.Item;
import com.bsharat.triosuite.common.error.ApiException;
import com.bsharat.triosuite.common.web.PageResponse;
import com.bsharat.triosuite.invoice.InvoiceCalculator.CalculatedInvoice;
import com.bsharat.triosuite.invoice.InvoiceCalculator.CalculatedLine;
import com.bsharat.triosuite.invoice.InvoiceCalculator.LineInput;
import com.bsharat.triosuite.invoice.dto.CreateInvoiceRequest;
import com.bsharat.triosuite.invoice.dto.InvoiceLineRequest;
import com.bsharat.triosuite.invoice.dto.InvoiceResponse;
import com.bsharat.triosuite.invoice.dto.InvoiceSummaryResponse;
import com.bsharat.triosuite.invoice.dto.UpdateInvoiceRequest;
import com.bsharat.triosuite.security.AuthenticatedUser;
import com.bsharat.triosuite.settings.AppSettings;
import com.bsharat.triosuite.settings.SettingsService;
import com.bsharat.triosuite.user.User;
import com.bsharat.triosuite.user.UserRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The invoice lifecycle: create, edit, approve, cancel and read.
 *
 * <p>This class is the only authority on what an invoice may become. The mobile app hides buttons a
 * role cannot use and greys out an approved invoice, but that is convenience — every rule below is
 * checked again here, on data loaded from the database rather than sent by the client.
 *
 * <p>Three principles run through it:
 * <ul>
 *   <li><b>Totals are never trusted.</b> Whatever a client computes, the server recomputes from the
 *       lines with {@link InvoiceCalculator} and stores its own answer.</li>
 *   <li><b>Version before rules.</b> The optimistic-lock check runs before the state machine, so a
 *       caller working from a stale copy is told to reload rather than being given an explanation of
 *       a state they have not seen yet.</li>
 *   <li><b>Nothing is deleted.</b> Cancellation is a status change with an audit stamp.</li>
 * </ul>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class InvoiceService {

    /** The sequence table constrains the year; reject anything outside it with a clear message. */
    private static final int MIN_YEAR = 2000;
    private static final int MAX_YEAR = 9999;

    private static final int EXCHANGE_RATE_SCALE = 6;

    private final InvoiceRepository invoices;
    private final CurrencyRepository currencies;
    private final UserRepository users;
    private final CatalogService catalog;
    private final SettingsService settingsService;
    private final InvoiceCalculator calculator;
    private final InvoiceNumberAllocator numberAllocator;

    // =================================================================================
    // Reads
    // =================================================================================

    /**
     * One page of the invoice list.
     *
     * @param status optional status filter
     * @param search optional term matched against the invoice number and the customer name
     */
    @Transactional(readOnly = true)
    public PageResponse<InvoiceSummaryResponse> list(InvoiceStatus status, String search, Pageable pageable) {
        Page<Invoice> page = invoices.findAll(InvoiceSpecifications.matching(status, search), pageable);
        return PageResponse.of(page, InvoiceService::toSummary);
    }

    /**
     * One invoice in full, with its lines and audit trail.
     *
     * @throws ApiException with {@code NOT_FOUND} if it does not exist
     */
    @Transactional(readOnly = true)
    public InvoiceResponse get(Long id) {
        Invoice invoice = requireInvoice(id);
        return InvoiceResponse.from(invoice, settingsService.require().getBaseCurrency().getCode());
    }

    // =================================================================================
    // Writes
    // =================================================================================

    /**
     * Creates a DRAFT and allocates its number.
     *
     * <p>The number is reserved inside this transaction, so a failure anywhere below — an inactive
     * item, a constraint violation — releases it again rather than leaving a gap.
     *
     * @param request the header and lines; any totals it carries are ignored
     * @param actor   the signed-in user, recorded as {@code created_by}
     */
    @Transactional
    public InvoiceResponse create(CreateInvoiceRequest request, AuthenticatedUser actor) {
        AppSettings settings = settingsService.require();
        validateIssueYear(request.issueDate());

        Invoice invoice = new Invoice();
        invoice.setStatus(InvoiceStatus.DRAFT);
        invoice.setCreatedBy(requireUser(actor));

        applyHeaderAndLines(invoice, settings, request.customerId(), request.currencyCode(),
                request.exchangeRate(), request.taxMode(), request.issueDate(), request.notes(),
                request.lines());

        invoice.setInvoiceNumber(numberAllocator.allocate(
                settings.getInvoiceNumberPrefix(), request.issueDate().getYear()));

        Invoice saved = invoices.saveAndFlush(invoice);
        log.info("Invoice {} created by '{}' with {} line(s), total {} {}",
                saved.getInvoiceNumber(), actor.username(), saved.getLines().size(),
                saved.getGrandTotal(), saved.getCurrency().getCode());

        return InvoiceResponse.from(saved, settings.getBaseCurrency().getCode());
    }

    /**
     * Replaces the header and every line of a DRAFT.
     *
     * @throws ApiException {@code STALE_VERSION} if the version does not match,
     *                      {@code INVOICE_NOT_EDITABLE} if the invoice is no longer a draft
     */
    @Transactional
    public InvoiceResponse update(Long id, UpdateInvoiceRequest request, AuthenticatedUser actor) {
        AppSettings settings = settingsService.require();
        Invoice invoice = requireInvoice(id);

        requireVersion(invoice, request.version());
        if (!invoice.getStatus().isEditable()) {
            throw ApiException.invoiceNotEditable(invoice.getInvoiceNumber(), invoice.getStatus());
        }
        validateIssueYear(request.issueDate());

        applyHeaderAndLines(invoice, settings, request.customerId(), request.currencyCode(),
                request.exchangeRate(), request.taxMode(), request.issueDate(), request.notes(),
                request.lines());

        Invoice saved = invoices.saveAndFlush(invoice);
        log.info("Invoice {} updated by '{}' with {} line(s), total {} {}",
                saved.getInvoiceNumber(), actor.username(), saved.getLines().size(),
                saved.getGrandTotal(), saved.getCurrency().getCode());

        return InvoiceResponse.from(saved, settings.getBaseCurrency().getCode());
    }

    /**
     * Moves a DRAFT to APPROVED, after which it can no longer be edited.
     *
     * @throws ApiException {@code STALE_VERSION} if the version does not match,
     *                      {@code INVALID_TRANSITION} if the invoice is not a draft,
     *                      {@code VALIDATION_ERROR} if it has no lines
     */
    @Transactional
    public InvoiceResponse approve(Long id, Long version, AuthenticatedUser actor) {
        Invoice invoice = requireInvoice(id);

        requireVersion(invoice, version);
        if (!invoice.getStatus().canApprove()) {
            throw ApiException.invalidTransition(
                    invoice.getInvoiceNumber(), invoice.getStatus(), "approved");
        }
        if (invoice.getLines().isEmpty()) {
            throw ApiException.invalid("An invoice must have at least one line before it can be approved");
        }

        invoice.setStatus(InvoiceStatus.APPROVED);
        invoice.setApprovedBy(requireUser(actor));
        invoice.setApprovedAt(Instant.now());

        Invoice saved = invoices.saveAndFlush(invoice);
        log.info("Invoice {} approved by '{}'", saved.getInvoiceNumber(), actor.username());

        return InvoiceResponse.from(saved, settingsService.require().getBaseCurrency().getCode());
    }

    /**
     * Cancels a DRAFT or an APPROVED invoice.
     *
     * <p>The record is kept in full and stays in the list under the Cancelled filter. There is no
     * endpoint that deletes an invoice.
     *
     * @param reason optional free text recorded against the cancellation
     * @throws ApiException {@code STALE_VERSION} if the version does not match,
     *                      {@code INVALID_TRANSITION} if it is already cancelled
     */
    @Transactional
    public InvoiceResponse cancel(Long id, Long version, String reason, AuthenticatedUser actor) {
        Invoice invoice = requireInvoice(id);

        requireVersion(invoice, version);
        if (!invoice.getStatus().canCancel()) {
            throw ApiException.invalidTransition(
                    invoice.getInvoiceNumber(), invoice.getStatus(), "cancelled");
        }

        invoice.setStatus(InvoiceStatus.CANCELLED);
        invoice.setCancelledBy(requireUser(actor));
        invoice.setCancelledAt(Instant.now());
        invoice.setCancellationReason(blankToNull(reason));

        Invoice saved = invoices.saveAndFlush(invoice);
        log.info("Invoice {} cancelled by '{}'", saved.getInvoiceNumber(), actor.username());

        return InvoiceResponse.from(saved, settingsService.require().getBaseCurrency().getCode());
    }

    // =================================================================================
    // Internals
    // =================================================================================

    /**
     * Writes the header, prices every line and stores the server's totals.
     *
     * <p>Shared by create and update so a draft edited into a different currency or tax mode is
     * recomputed by exactly the same code path that first priced it.
     */
    private void applyHeaderAndLines(
            Invoice invoice, AppSettings settings, Long customerId, String currencyCode,
            BigDecimal requestedRate, TaxMode taxMode, LocalDate issueDate, String notes,
            List<InvoiceLineRequest> lineRequests) {

        Customer customer = catalog.requireActiveCustomer(customerId);
        Currency currency = requireActiveCurrency(currencyCode);
        Currency baseCurrency = settings.getBaseCurrency();

        BigDecimal exchangeRate = resolveExchangeRate(currency, baseCurrency, requestedRate);

        invoice.setCustomer(customer);
        invoice.setCurrency(currency);
        invoice.setExchangeRate(exchangeRate);
        invoice.setTaxMode(taxMode);
        invoice.setIssueDate(issueDate);
        invoice.setNotes(blankToNull(notes));

        // Resolve every item first: one inactive item must abort the whole write, not half of it.
        List<Item> items = lineRequests.stream()
                .map(line -> catalog.requireActiveItem(line.itemId()))
                .toList();

        List<LineInput> inputs = new ArrayList<>(lineRequests.size());
        for (int i = 0; i < lineRequests.size(); i++) {
            inputs.add(new LineInput(
                    lineRequests.get(i).quantity(),
                    lineRequests.get(i).unitPrice(),
                    // The tax rate comes from the catalogue, never from the request: a client that
                    // could name its own rate could invoice at 0% tax.
                    items.get(i).getTaxRate()));
        }

        CalculatedInvoice totals = calculator.calculate(
                inputs, taxMode, currency.getMinorUnits(), exchangeRate, baseCurrency.getMinorUnits());

        List<InvoiceLine> lines = new ArrayList<>(lineRequests.size());
        for (int i = 0; i < lineRequests.size(); i++) {
            lines.add(buildLine(items.get(i), lineRequests.get(i), totals.lines().get(i)));
        }
        invoice.replaceLines(lines);

        invoice.setSubtotal(totals.subtotal());
        invoice.setTaxTotal(totals.taxTotal());
        invoice.setGrandTotal(totals.grandTotal());
        invoice.setGrandTotalBase(totals.grandTotalBase());
    }

    private static InvoiceLine buildLine(Item item, InvoiceLineRequest request, CalculatedLine amounts) {
        InvoiceLine line = new InvoiceLine();
        line.setItem(item);
        line.setItemNameSnapshot(item.getName());
        line.setBarcodeSnapshot(item.getBarcode());
        line.setQuantity(request.quantity());
        line.setUnitPrice(request.unitPrice());
        line.setTaxRate(item.getTaxRate());
        line.setNetAmount(amounts.netAmount());
        line.setTaxAmount(amounts.taxAmount());
        line.setGrossAmount(amounts.grossAmount());
        return line;
    }

    /**
     * Decides the rate the invoice will carry.
     *
     * <p>An invoice already in the base currency is pinned to exactly 1: allowing anything else
     * would let the same amount report as two different figures in the same currency.
     */
    private static BigDecimal resolveExchangeRate(
            Currency currency, Currency baseCurrency, BigDecimal requested) {

        if (currency.getCode().equals(baseCurrency.getCode())) {
            return BigDecimal.ONE.setScale(EXCHANGE_RATE_SCALE);
        }
        return requested.setScale(EXCHANGE_RATE_SCALE, java.math.RoundingMode.HALF_UP);
    }

    private Currency requireActiveCurrency(String code) {
        Currency currency = currencies.findById(code.toUpperCase())
                .orElseThrow(() -> ApiException.invalid("'" + code + "' is not a known currency"));
        if (!currency.isActive()) {
            throw ApiException.invalid("Currency '" + currency.getCode() + "' is not active");
        }
        return currency;
    }

    private Invoice requireInvoice(Long id) {
        return invoices.findDetailById(id).orElseThrow(() -> ApiException.notFound("Invoice", id));
    }

    private User requireUser(AuthenticatedUser actor) {
        return users.findById(actor.id())
                .orElseThrow(() -> ApiException.unauthorized("This account is no longer available"));
    }

    /** Compares the client's version with the stored one before any work is done. */
    private static void requireVersion(Invoice invoice, Long expected) {
        if (!Objects.equals(invoice.getVersion(), expected)) {
            throw ApiException.staleVersion(invoice.getInvoiceNumber());
        }
    }

    private static void validateIssueYear(LocalDate issueDate) {
        int year = issueDate.getYear();
        if (year < MIN_YEAR || year > MAX_YEAR) {
            throw ApiException.invalid(
                    "issueDate must fall between " + MIN_YEAR + " and " + MAX_YEAR);
        }
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private static InvoiceSummaryResponse toSummary(Invoice invoice) {
        return new InvoiceSummaryResponse(
                invoice.getId(),
                invoice.getInvoiceNumber(),
                invoice.getCustomer().getName(),
                invoice.getIssueDate(),
                invoice.getCurrency().getCode(),
                invoice.getCurrency().getSymbol(),
                invoice.getGrandTotal(),
                invoice.getGrandTotalBase(),
                invoice.getStatus());
    }
}
