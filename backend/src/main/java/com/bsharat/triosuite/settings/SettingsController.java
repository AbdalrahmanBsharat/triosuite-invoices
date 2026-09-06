package com.bsharat.triosuite.settings;

import com.bsharat.triosuite.settings.dto.SettingsResponse;
import com.bsharat.triosuite.settings.dto.UpdateSettingsRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Company-wide invoicing defaults. */
@RestController
@RequestMapping("/api/settings")
@RequiredArgsConstructor
@Tag(name = "Settings", description = "Base currency, invoicing defaults and the number prefix")
public class SettingsController {

    private final SettingsService settingsService;

    @GetMapping
    @Operation(
            summary = "Read settings",
            description = """
                    Readable by any signed-in user. The app reads this at start-up to know the base
                    currency, the defaults for a new invoice and the number prefix.""")
    public SettingsResponse get() {
        return settingsService.get();
    }

    @PutMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(
            summary = "Update settings",
            description = """
                    Replaces every setting. Changing the base currency affects invoices created from
                    now on; those already issued keep the base-currency total they were saved with.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Settings updated"),
            @ApiResponse(responseCode = "400", description = "Unknown or inactive currency", content = @Content),
            @ApiResponse(responseCode = "403", description = "Caller is not an administrator", content = @Content)
    })
    public SettingsResponse update(@Valid @RequestBody UpdateSettingsRequest request) {
        return settingsService.update(request);
    }
}
