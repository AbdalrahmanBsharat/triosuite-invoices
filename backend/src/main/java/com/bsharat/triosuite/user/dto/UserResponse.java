package com.bsharat.triosuite.user.dto;

import com.bsharat.triosuite.user.Role;
import com.bsharat.triosuite.user.User;
import io.swagger.v3.oas.annotations.media.Schema;

/**
 * The signed-in account, as returned by login, refresh and {@code GET /api/auth/me}.
 *
 * <p>Deliberately narrow: no email, no timestamps and above all no password hash.
 *
 * @param id       account identifier
 * @param username account name
 * @param fullName display name
 * @param role     drives which actions the app offers; the server enforces them regardless
 */
@Schema(name = "User")
public record UserResponse(
        Long id,
        @Schema(example = "admin") String username,
        @Schema(example = "System Administrator") String fullName,
        Role role) {

    public static UserResponse from(User user) {
        return new UserResponse(user.getId(), user.getUsername(), user.getFullName(), user.getRole());
    }
}
