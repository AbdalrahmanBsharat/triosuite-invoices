package com.bsharat.triosuite.invoice;

import static org.assertj.core.api.Assertions.assertThat;

import com.bsharat.triosuite.invoice.dto.CreateInvoiceRequest;
import com.bsharat.triosuite.invoice.dto.InvoiceLineRequest;
import com.bsharat.triosuite.invoice.dto.InvoiceResponse;
import com.bsharat.triosuite.security.AuthenticatedUser;
import com.bsharat.triosuite.support.AbstractIntegrationTest;
import com.bsharat.triosuite.user.Role;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.stream.IntStream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * Proves that the row lock behind invoice numbering actually serialises concurrent creates.
 *
 * <p>Deliberately calls the service rather than MockMvc: each call then runs in its own thread and
 * its own transaction against the real MySQL, which is the only arrangement in which
 * {@code SELECT ... FOR UPDATE} means anything. A test that went through MockMvc on one thread
 * would pass whether or not the lock existed.
 */
class InvoiceNumberingConcurrencyIT extends AbstractIntegrationTest {

    private static final int CONCURRENT_CREATES = 12;

    @Autowired
    private InvoiceService invoiceService;

    @Test
    @DisplayName("parallel creates receive distinct, gapless, sequential numbers")
    void parallelCreatesGetDistinctSequentialNumbers() throws Exception {
        AuthenticatedUser actor = new AuthenticatedUser(1L, "admin", Role.ADMIN);
        CreateInvoiceRequest request = new CreateInvoiceRequest(
                CUSTOMER_ACTIVE,
                "ILS",
                new BigDecimal("1.000000"),
                TaxMode.EXCLUSIVE,
                LocalDate.of(2026, 9, 6),
                "Concurrency probe",
                List.of(new InvoiceLineRequest(
                        ITEM_LAPTOP, new BigDecimal("1.000"), new BigDecimal("100.0000"))));

        // Every thread blocks on the same latch so the creates genuinely overlap rather than
        // trickling out one at a time as the pool warms up.
        CountDownLatch startGate = new CountDownLatch(1);
        List<Callable<InvoiceResponse>> tasks = IntStream.range(0, CONCURRENT_CREATES)
                .<Callable<InvoiceResponse>>mapToObj(i -> () -> {
                    startGate.await();
                    return invoiceService.create(request, actor);
                })
                .toList();

        ExecutorService pool = Executors.newFixedThreadPool(CONCURRENT_CREATES);
        List<String> numbers = new ArrayList<>(CONCURRENT_CREATES);
        try {
            List<Future<InvoiceResponse>> futures = new ArrayList<>(CONCURRENT_CREATES);
            for (Callable<InvoiceResponse> task : tasks) {
                futures.add(pool.submit(task));
            }
            startGate.countDown();

            for (Future<InvoiceResponse> future : futures) {
                numbers.add(future.get(60, TimeUnit.SECONDS).invoiceNumber());
            }
        } finally {
            pool.shutdownNow();
        }

        assertThat(numbers)
                .as("every create must succeed")
                .hasSize(CONCURRENT_CREATES)
                .as("no two invoices may share a number")
                .doesNotHaveDuplicates();

        // The seed leaves the 2026 counter at 7, so these must be exactly 7 through 18.
        List<String> expected = IntStream.rangeClosed(7, 6 + CONCURRENT_CREATES)
                .mapToObj("INV-2026-%06d"::formatted)
                .toList();

        assertThat(numbers.stream().sorted(Comparator.naturalOrder()).toList())
                .as("numbers must be gapless and continue the seeded sequence")
                .isEqualTo(expected);
    }
}
