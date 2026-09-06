package com.bsharat.triosuite.user;

import com.bsharat.triosuite.security.AuthenticatedUser;
import com.bsharat.triosuite.user.dto.LoginRequest;
import com.bsharat.triosuite.user.dto.RefreshTokenRequest;
import com.bsharat.triosuite.user.dto.TokenResponse;
import com.bsharat.triosuite.user.dto.UserResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Sign-in, token rotation and sign-out. */
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Tag(name = "Authentication", description = "Sign in, rotate tokens and sign out")
public class AuthController {

    private final AuthService authService;

    @PostMapping("/login")
    @SecurityRequirements
    @Operation(
            summary = "Sign in",
            description = """
                    Exchanges a username and password for an access token and a refresh token.

                    Rate limited to five failed attempts per minute, counted separately per username
                    and per client IP; exceeding either returns 429 with a Retry-After header.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Signed in"),
            @ApiResponse(responseCode = "400", description = "Missing username or password", content = @Content),
            @ApiResponse(responseCode = "401", description = "Incorrect username or password", content = @Content),
            @ApiResponse(responseCode = "429", description = "Too many attempts", content = @Content)
    })
    public TokenResponse login(@Valid @RequestBody LoginRequest request, HttpServletRequest httpRequest) {
        return authService.login(request, httpRequest.getRemoteAddr());
    }

    @PostMapping("/refresh")
    @SecurityRequirements
    @Operation(
            summary = "Rotate tokens",
            description = """
                    Exchanges a refresh token for a new pair. The presented token is revoked in the
                    same transaction, so each one works exactly once.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "New token pair issued"),
            @ApiResponse(responseCode = "401", description = "Unknown, revoked or expired refresh token", content = @Content)
    })
    public TokenResponse refresh(@Valid @RequestBody RefreshTokenRequest request) {
        return authService.refresh(request.refreshToken());
    }

    @PostMapping("/logout")
    @Operation(
            summary = "Sign out",
            description = """
                    Revokes a refresh token. Idempotent: an unknown or already revoked token also
                    returns 204, so the endpoint cannot be used to probe which tokens exist.""")
    @ApiResponse(responseCode = "204", description = "Token revoked")
    public ResponseEntity<Void> logout(@Valid @RequestBody RefreshTokenRequest request) {
        authService.logout(request.refreshToken());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/me")
    @Operation(summary = "The signed-in account", description = "Resolves the caller's access token to an account.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "The signed-in account"),
            @ApiResponse(responseCode = "401", description = "Missing or invalid access token", content = @Content)
    })
    public UserResponse me(@AuthenticationPrincipal AuthenticatedUser caller) {
        return authService.currentUser(caller.id());
    }
}
