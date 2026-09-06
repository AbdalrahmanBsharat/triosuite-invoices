package com.bsharat.triosuite.support;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.bsharat.triosuite.security.LoginRateLimiter;
import com.jayway.jsonpath.JsonPath;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Base class for the integration tests.
 *
 * <p>These run against a <b>real MySQL 8</b>, not an in-memory substitute: the schema uses CHECK
 * constraints, {@code DATETIME(6)} and {@code SELECT ... FOR UPDATE}, so a different engine would
 * be testing something other than what ships. Docker is unavailable on the development machine, so
 * the {@code test} profile points at a local instance; CI supplies a MySQL service container
 * through the same environment variables (ADR-0002).
 *
 * <p>Every test starts from the freshly migrated, seeded schema — {@code clean} then
 * {@code migrate} before each test method — so no test can come to depend on another having run
 * first, and the seeded ids referenced below are always the same.
 */
@ActiveProfiles("test")
@AutoConfigureMockMvc
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
public abstract class AbstractIntegrationTest {

    /** Seeded ids the tests rely on. See {@code V2__seed.sql}. */
    protected static final long CUSTOMER_ACTIVE = 1L;
    protected static final long CUSTOMER_INACTIVE = 6L;
    protected static final long ITEM_LAPTOP = 1L;
    protected static final long ITEM_PAPER = 8L;
    protected static final long ITEM_ZERO_RATED = 13L;
    protected static final long INVOICE_DRAFT = 3L;
    protected static final long INVOICE_APPROVED = 1L;
    protected static final long INVOICE_CANCELLED = 4L;

    @Autowired
    protected MockMvc mockMvc;

    @Autowired
    private Flyway flyway;

    @Autowired
    private LoginRateLimiter loginRateLimiter;

    @BeforeEach
    void resetState() {
        flyway.clean();
        flyway.migrate();

        // The limiter is a singleton that outlives any one test. Without this reset, a test that
        // fails a few logins leaves the next one with a reduced allowance, and the suite becomes
        // order-dependent — which is precisely how the rate-limit tests came to pass locally and
        // fail in CI.
        loginRateLimiter.reset();
    }

    /** Signs in and returns a value ready for an {@code Authorization} header. */
    protected String bearerFor(String username, String password) throws Exception {
        String body = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username": "%s", "password": "%s"}""".formatted(username, password)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return "Bearer " + JsonPath.<String>read(body, "$.accessToken");
    }

    /** A bearer token for the seeded ADMIN account. */
    protected String adminToken() throws Exception {
        return bearerFor("admin", "Admin#2026");
    }

    /** A bearer token for the seeded SALES account. */
    protected String salesToken() throws Exception {
        return bearerFor("sales", "Sales#2026");
    }
}
