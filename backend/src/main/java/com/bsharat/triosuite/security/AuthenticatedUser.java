package com.bsharat.triosuite.security;

import com.bsharat.triosuite.user.Role;
import java.util.Collection;
import java.util.List;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

/**
 * The caller behind the current request, reconstructed from a verified access token.
 *
 * <p>Everything here comes from signed claims, so no database read is needed to authorise an
 * ordinary request. Controllers receive it with {@code @AuthenticationPrincipal}.
 *
 * @param id       the account's identifier, taken from the {@code sub} claim
 * @param username the account name, for logging and for {@code GET /api/auth/me}
 * @param role     the account's role, taken from the {@code role} claim
 */
public record AuthenticatedUser(Long id, String username, Role role) {

    /** The single authority this caller holds, in Spring Security's {@code ROLE_} form. */
    public Collection<GrantedAuthority> authorities() {
        return List.of(new SimpleGrantedAuthority(role.authority()));
    }
}
