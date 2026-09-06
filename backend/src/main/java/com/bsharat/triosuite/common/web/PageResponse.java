package com.bsharat.triosuite.common.web;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;
import java.util.function.Function;
import org.springframework.data.domain.Page;

/**
 * The paginated envelope every list endpoint returns.
 *
 * @param content       the page's rows
 * @param page          zero-based page index
 * @param size          requested page size
 * @param totalElements total rows matching the query
 * @param totalPages    total pages at this size
 * @param <T>           row type
 */
@Schema(name = "Page", description = "A page of results")
public record PageResponse<T>(
        List<T> content,
        @Schema(example = "0") int page,
        @Schema(example = "20") int size,
        @Schema(example = "42") long totalElements,
        @Schema(example = "3") int totalPages) {

    /** Wraps a Spring Data page whose rows are already the response type. */
    public static <T> PageResponse<T> of(Page<T> page) {
        return new PageResponse<>(
                page.getContent(), page.getNumber(), page.getSize(),
                page.getTotalElements(), page.getTotalPages());
    }

    /** Wraps a Spring Data page of entities, mapping each row to its response type. */
    public static <E, T> PageResponse<T> of(Page<E> page, Function<E, T> mapper) {
        return new PageResponse<>(
                page.getContent().stream().map(mapper).toList(), page.getNumber(), page.getSize(),
                page.getTotalElements(), page.getTotalPages());
    }
}
