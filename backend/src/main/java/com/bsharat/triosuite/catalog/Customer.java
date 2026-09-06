package com.bsharat.triosuite.catalog;

import com.bsharat.triosuite.common.jpa.AuditedEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * A party an invoice is billed to.
 *
 * <p>Customers are deactivated rather than deleted, because invoices reference them for ever. An
 * inactive customer is rejected when a new invoice is created but stays readable on the invoices
 * that already name it.
 */
@Entity
@Getter
@Setter
@Table(name = "customers")
public class Customer extends AuditedEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(length = 255)
    private String email;

    @Column(length = 40)
    private String phone;

    @Column(length = 500)
    private String address;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;
}
