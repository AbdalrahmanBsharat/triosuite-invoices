package com.bsharat.triosuite.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * OpenAPI document metadata and the bearer-token security scheme.
 *
 * <p>The scheme is declared globally, so Swagger UI shows an <em>Authorize</em> button and every
 * operation except the anonymous ones inherits the requirement. Operations that are genuinely
 * public opt out with {@code @SecurityRequirements}.
 */
@Configuration
public class OpenApiConfig {

    private static final String BEARER_SCHEME = "bearerAuth";

    private final String applicationVersion;

    public OpenApiConfig(@Value("${info.app.version:1.0.0}") String applicationVersion) {
        this.applicationVersion = applicationVersion;
    }

    @Bean
    public OpenAPI triosuiteOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("Triosuite Invoices API")
                        .version(applicationVersion)
                        .description("""
                                REST API for the Triosuite ERP sales-invoice assessment.

                                Multi-currency invoices with user-supplied exchange rates, tax-inclusive
                                and tax-exclusive calculation, server-side automatic numbering, an
                                approval and cancellation state machine, and barcode lookup.

                                Authenticate with `POST /api/auth/login` (try `admin` / `Admin#2026`),
                                then paste the returned `accessToken` into **Authorize**.

                                Errors are RFC 9457 problem documents carrying a stable `code`
                                property; see docs/API.md for the full list.""")
                        .contact(new Contact().name("Abdalrahman Bsharat"))
                        .license(new License().name("MIT")))
                .components(new Components().addSecuritySchemes(BEARER_SCHEME, new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT")
                        .description("Access token from POST /api/auth/login")))
                .addSecurityItem(new SecurityRequirement().addList(BEARER_SCHEME));
    }
}
