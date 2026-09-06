/// The paginated envelope every list endpoint returns.
///
/// Hand-written rather than generated: a generic `freezed` class needs a `fromJson` that takes a
/// per-element parser, which the generator cannot infer, so the generated code would be a thin
/// wrapper around exactly this.
class PageResponse<T> {
  const PageResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  /// Whether another page exists after this one.
  bool get hasMore => page + 1 < totalPages;

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parseItem,
  ) {
    final rows = (json['content'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(parseItem)
        .toList(growable: false);

    return PageResponse<T>(
      content: rows,
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? rows.length,
      totalElements: json['totalElements'] as int? ?? rows.length,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }

  /// An empty page, for the initial state of a list before anything has been fetched.
  static PageResponse<T> empty<T>() => PageResponse<T>(
        content: const [],
        page: 0,
        size: 0,
        totalElements: 0,
        totalPages: 0,
      );
}
