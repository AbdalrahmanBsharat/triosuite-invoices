package com.bsharat.triosuite.user;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

/** Account lookups. */
public interface UserRepository extends JpaRepository<User, Long> {

    /**
     * Finds an account by name.
     *
     * <p>Deliberately does not filter on {@code active}: the login flow needs to distinguish a
     * disabled account from a wrong password so it can rate-limit both identically while logging
     * them differently.
     */
    Optional<User> findByUsername(String username);
}
