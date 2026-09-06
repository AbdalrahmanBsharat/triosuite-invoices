package com.bsharat.triosuite.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasItems;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.bsharat.triosuite.support.AbstractIntegrationTest;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

/** Login, refresh rotation, logout and {@code /me}. */
class AuthIT extends AbstractIntegrationTest {

    @Test
    @DisplayName("login returns a token pair and the account, and never the password hash")
    void loginSucceeds() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username": "admin", "password": "Admin#2026"}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.expiresInSeconds").value(1800))
                .andExpect(jsonPath("$.user.username").value("admin"))
                .andExpect(jsonPath("$.user.role").value("ADMIN"))
                .andExpect(jsonPath("$.user.fullName").value("System Administrator"))
                .andExpect(jsonPath("$.user.passwordHash").doesNotExist())
                .andExpect(jsonPath("$.user.email").doesNotExist());
    }

    @Test
    @DisplayName("the SALES account signs in with its own role")
    void salesLoginSucceeds() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username": "sales", "password": "Sales#2026"}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user.role").value("SALES"));
    }

    @Test
    @DisplayName("a wrong password is rejected with a message that does not confirm the username")
    void wrongPasswordIsRejected() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username": "admin", "password": "not-the-password"}"""))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.detail").value("Incorrect username or password"));
    }

    @Test
    @DisplayName("an unknown username gets exactly the same answer as a wrong password")
    void unknownUsernameIsIndistinguishable() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username": "no-such-account", "password": "whatever"}"""))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.detail").value("Incorrect username or password"));
    }

    @Test
    @DisplayName("a blank username is a validation error, not an authentication one")
    void blankUsernameIsAValidationError() throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username": "", "password": ""}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.errors[*].field").value(
                        hasItems("username", "password")));
    }

    @Test
    @DisplayName("me resolves the access token to the signed-in account")
    void meReturnsTheCaller() throws Exception {
        mockMvc.perform(get("/api/auth/me").header(HttpHeaders.AUTHORIZATION, salesToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("sales"))
                .andExpect(jsonPath("$.role").value("SALES"));
    }

    @Test
    @DisplayName("refresh issues a new pair and revokes the token that was presented")
    void refreshRotatesTheToken() throws Exception {
        String loginBody = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username": "admin", "password": "Admin#2026"}"""))
                .andReturn().getResponse().getContentAsString();
        String firstRefreshToken = JsonPath.read(loginBody, "$.refreshToken");

        String refreshBody = mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken": "%s"}""".formatted(firstRefreshToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.user.username").value("admin"))
                .andReturn().getResponse().getContentAsString();

        String secondRefreshToken = JsonPath.read(refreshBody, "$.refreshToken");
        assertThat(secondRefreshToken).isNotEqualTo(firstRefreshToken);

        // The first token is single-use: presenting it again must fail.
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken": "%s"}""".formatted(firstRefreshToken)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("an unknown refresh token is rejected")
    void unknownRefreshTokenIsRejected() throws Exception {
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken": "this-token-was-never-issued"}"""))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("logout revokes the refresh token, and repeating it is still 204")
    void logoutRevokesAndIsIdempotent() throws Exception {
        String loginBody = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username": "admin", "password": "Admin#2026"}"""))
                .andReturn().getResponse().getContentAsString();
        String accessToken = "Bearer " + JsonPath.<String>read(loginBody, "$.accessToken");
        String refreshToken = JsonPath.read(loginBody, "$.refreshToken");

        mockMvc.perform(post("/api/auth/logout")
                        .header(HttpHeaders.AUTHORIZATION, accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken": "%s"}""".formatted(refreshToken)))
                .andExpect(status().isNoContent());

        mockMvc.perform(post("/api/auth/logout")
                        .header(HttpHeaders.AUTHORIZATION, accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken": "%s"}""".formatted(refreshToken)))
                .andExpect(status().isNoContent());

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken": "%s"}""".formatted(refreshToken)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("every response carries a request id header for log correlation")
    void responsesCarryARequestId() throws Exception {
        mockMvc.perform(get("/api/auth/me").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andExpect(header().exists("X-Request-Id"));
    }
}
