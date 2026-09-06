package com.bsharat.triosuite.catalog;

import com.bsharat.triosuite.catalog.dto.CurrencyResponse;
import com.bsharat.triosuite.catalog.dto.CustomerResponse;
import com.bsharat.triosuite.catalog.dto.ExchangeRateResponse;
import com.bsharat.triosuite.catalog.dto.ItemResponse;
import com.bsharat.triosuite.common.error.ApiException;
import com.bsharat.triosuite.common.web.PageResponse;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Reference data behind the Create Invoice screen: currencies, exchange rates, customers and items.
 *
 * <p>All of it is read-only except the exchange rates, which an administrator maintains from the
 * Settings screen.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CatalogService {

    private final CurrencyRepository currencies;
    private final CurrencyExchangeRateRepository exchangeRates;
    private final CustomerRepository customers;
    private final ItemRepository items;

    // ---------------------------------------------------------------------------------
    // Currencies and rates
    // ---------------------------------------------------------------------------------

    /** Every currency an invoice may be issued in. */
    @Transactional(readOnly = true)
    public List<CurrencyResponse> listCurrencies() {
        return currencies.findByActiveTrueOrderByCodeAsc().stream()
                .map(CurrencyResponse::from)
                .toList();
    }

    /** The rate suggested for each currency when a new invoice is created. */
    @Transactional(readOnly = true)
    public List<ExchangeRateResponse> listExchangeRates() {
        return exchangeRates.findAllByOrderByCurrencyCodeAsc().stream()
                .map(ExchangeRateResponse::from)
                .toList();
    }

    /**
     * Sets the suggested rate for a currency.
     *
     * <p>Only affects invoices created from now on. Invoices already issued keep the rate they
     * snapshotted, which is what makes their base-currency totals reproducible.
     *
     * @throws ApiException with {@code NOT_FOUND} if the currency does not exist
     */
    @Transactional
    public ExchangeRateResponse updateExchangeRate(String currencyCode, BigDecimal rateToBase) {
        String code = currencyCode.toUpperCase();

        CurrencyExchangeRate rate = exchangeRates.findById(code).orElseGet(() -> {
            Currency currency = currencies.findById(code)
                    .orElseThrow(() -> ApiException.notFound("Currency", code));
            CurrencyExchangeRate created = new CurrencyExchangeRate();
            created.setCurrency(currency);
            created.setCurrencyCode(code);
            return created;
        });

        rate.setRateToBase(rateToBase);
        rate.setUpdatedAt(Instant.now());

        log.info("Exchange rate for {} set to {}", code, rateToBase);
        return ExchangeRateResponse.from(exchangeRates.save(rate));
    }

    // ---------------------------------------------------------------------------------
    // Customers
    // ---------------------------------------------------------------------------------

    /** Active customers matching a search term, paginated. */
    @Transactional(readOnly = true)
    public PageResponse<CustomerResponse> searchCustomers(String search, Pageable pageable) {
        return PageResponse.of(
                customers.search(likePattern(search), pageable), CustomerResponse::from);
    }

    /**
     * Loads a customer for use on an invoice.
     *
     * @throws ApiException with {@code NOT_FOUND} if unknown, or {@code VALIDATION_ERROR} if inactive
     */
    @Transactional(readOnly = true)
    public Customer requireActiveCustomer(Long id) {
        Customer customer = customers.findById(id)
                .orElseThrow(() -> ApiException.notFound("Customer", id));
        if (!customer.isActive()) {
            throw ApiException.invalid("Customer '" + customer.getName()
                    + "' is inactive and cannot be invoiced");
        }
        return customer;
    }

    // ---------------------------------------------------------------------------------
    // Items
    // ---------------------------------------------------------------------------------

    /** Active catalogue items matching a search term, paginated. */
    @Transactional(readOnly = true)
    public PageResponse<ItemResponse> searchItems(String search, Pageable pageable) {
        return PageResponse.of(items.search(likePattern(search), pageable), ItemResponse::from);
    }

    /**
     * Looks an item up by the exact barcode the scanner read.
     *
     * @throws ApiException with {@code NOT_FOUND} if no item carries it, which the app turns into
     *                      "Item not found" without closing the scanner
     */
    @Transactional(readOnly = true)
    public ItemResponse findByBarcode(String barcode) {
        return items.findByBarcode(barcode.trim())
                .map(ItemResponse::from)
                .orElseThrow(() -> ApiException.notFound("Barcode", barcode));
    }

    /**
     * Loads an item for use on an invoice line.
     *
     * @throws ApiException with {@code NOT_FOUND} if unknown, or {@code VALIDATION_ERROR} if inactive
     */
    @Transactional(readOnly = true)
    public Item requireActiveItem(Long id) {
        Item item = items.findWithCurrencyById(id)
                .orElseThrow(() -> ApiException.notFound("Item", id));
        if (!item.isActive()) {
            throw ApiException.invalid("Item '" + item.getName()
                    + "' is inactive and cannot be added to an invoice");
        }
        return item;
    }

    /**
     * Turns a user's search term into a SQL LIKE pattern, or null to match everything.
     *
     * <p>The term is lower-cased and wrapped in wildcards but never concatenated into SQL: it is
     * bound as a parameter, so {@code %} and {@code _} inside it can at worst widen the user's own
     * search.
     */
    private static String likePattern(String search) {
        if (search == null || search.isBlank()) {
            return null;
        }
        return "%" + search.trim().toLowerCase() + "%";
    }
}
