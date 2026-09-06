package com.bsharat.triosuite;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

/**
 * Entry point for the Triosuite ERP sales-invoice REST API.
 */
@SpringBootApplication
@ConfigurationPropertiesScan
public class TriosuiteInvoicesApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(TriosuiteInvoicesApiApplication.class, args);
    }
}
