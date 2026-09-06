package com.bsharat.triosuite.security;

import com.bsharat.triosuite.common.error.ErrorCode;
import com.bsharat.triosuite.common.error.ProblemDetails;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.net.URI;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;

/**
 * Renders authentication and authorization failures as problem documents.
 *
 * <p>These two failures happen inside the filter chain, before any controller advice can see them,
 * so without this they would come back as Spring Security's default empty 401/403. Routing them
 * through the same {@link ProblemDetails} builder keeps every error the API emits — whatever layer
 * produced it — a single shape the app can parse once.
 */
@Component
@RequiredArgsConstructor
public class ProblemAuthenticationHandlers implements AuthenticationEntryPoint, AccessDeniedHandler {

    private final ObjectMapper objectMapper;

    /** No credentials, or credentials that did not survive verification. */
    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException {
        write(request, response, ErrorCode.UNAUTHORIZED,
                "Authentication is required to access this resource");
    }

    /** Authenticated, but the role does not permit this operation. */
    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response,
                       AccessDeniedException accessDeniedException) throws IOException {
        write(request, response, ErrorCode.FORBIDDEN,
                "Your role does not permit this operation");
    }

    private void write(HttpServletRequest request, HttpServletResponse response,
                       ErrorCode code, String detail) throws IOException {
        ProblemDetail problem = ProblemDetails.of(code, detail);
        problem.setInstance(URI.create(request.getRequestURI()));

        response.setStatus(code.status().value());
        response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        objectMapper.writeValue(response.getOutputStream(), problem);
    }
}
