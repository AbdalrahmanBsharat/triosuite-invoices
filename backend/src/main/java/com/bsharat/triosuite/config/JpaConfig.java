package com.bsharat.triosuite.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/**
 * Turns on the auditing that fills created_at and updated_at.
 *
 * <p>No AuditorAware is registered: the columns that record <em>who</em> acted — created_by,
 * approved_by, cancelled_by — are set explicitly by the invoice service, because they are part of
 * the domain's audit trail rather than incidental bookkeeping and must be written in the same
 * transaction as the state change they describe.
 */
@Configuration
@EnableJpaAuditing
public class JpaConfig {
}
