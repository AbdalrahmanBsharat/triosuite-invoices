package com.bsharat.triosuite.security;

import com.bsharat.triosuite.config.AppProperties;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

/**
 * The application's security policy.
 *
 * <p>Default-deny: only login, refresh, the health probe and the API documentation are anonymous;
 * everything else needs a verified bearer token, and the endpoints that change data additionally
 * carry {@code @PreAuthorize}. Sessions are stateless and CSRF is off because there is no cookie
 * to forge — the only credential is a header the browser will not attach on its own.
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    /** Endpoints reachable without a token. Everything not listed here requires one. */
    private static final String[] PUBLIC_GET = {
            "/actuator/health",
            "/actuator/health/**",
            "/v3/api-docs",
            "/v3/api-docs/**",
            "/swagger-ui.html",
            "/swagger-ui/**"
    };

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final ProblemAuthenticationHandlers problemHandlers;
    private final AppProperties properties;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
                .csrf(csrf -> csrf.disable())
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.POST, "/api/auth/login", "/api/auth/refresh").permitAll()
                        .requestMatchers(HttpMethod.GET, PUBLIC_GET).permitAll()
                        .anyRequest().authenticated())
                .exceptionHandling(handling -> handling
                        .authenticationEntryPoint(problemHandlers)
                        .accessDeniedHandler(problemHandlers))
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
                .build();
    }

    /**
     * BCrypt at strength 12.
     *
     * <p>Above the brief's minimum of 10 and a reasonable 2026 default: roughly a quarter of a
     * second per verification on commodity hardware, which is invisible to a user logging in and
     * expensive for anyone working through a stolen hash table.
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    /**
     * CORS for browser clients, restricted to the exact origins in {@code CORS_ALLOWED_ORIGINS}.
     *
     * <p>Empty by default. The Flutter app is not a browser and is unaffected; this exists so a web
     * console could be added without loosening anything else.
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        List<String> allowedOrigins = properties.cors().allowedOrigins().stream()
                .map(String::trim)
                .filter(origin -> !origin.isEmpty())
                .toList();

        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOrigins(allowedOrigins);
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "OPTIONS"));
        configuration.setAllowedHeaders(List.of("Authorization", "Content-Type", "X-Request-Id"));
        configuration.setExposedHeaders(List.of("Location", "Retry-After", "X-Request-Id"));
        configuration.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        if (!allowedOrigins.isEmpty()) {
            source.registerCorsConfiguration("/api/**", configuration);
        }
        return source;
    }
}
