import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/page_response.dart';
import '../../../../core/widgets/async_state_view.dart';

/// A searchable, paginated picker in a bottom sheet.
///
/// Both the customer picker and the item picker are this widget with a different fetch function
/// and a different row — the debounce, the infinite scroll, the empty state and the error state are
/// identical, and writing them twice would mean fixing every future bug twice.
class SearchPickerSheet<T> extends StatefulWidget {
  const SearchPickerSheet({
    super.key,
    required this.title,
    required this.searchHint,
    required this.fetch,
    required this.rowBuilder,
    required this.emptyMessage,
  });

  final String title;
  final String searchHint;

  /// Fetches one page for the current search term.
  final Future<PageResponse<T>> Function(String search, int page) fetch;

  /// Builds one row. [onPick] closes the sheet with that value.
  final Widget Function(BuildContext context, T value, VoidCallback onPick) rowBuilder;

  final String emptyMessage;

  /// Opens the sheet and resolves with the chosen value, or null if it was dismissed.
  static Future<T?> show<T>({
    required String title,
    required String searchHint,
    required Future<PageResponse<T>> Function(String search, int page) fetch,
    required Widget Function(BuildContext context, T value, VoidCallback onPick) rowBuilder,
    required String emptyMessage,
  }) {
    final context = Get.context;
    if (context == null) {
      return Future<T?>.value();
    }
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SearchPickerSheet<T>(
        title: title,
        searchHint: searchHint,
        fetch: fetch,
        rowBuilder: rowBuilder,
        emptyMessage: emptyMessage,
      ),
    );
  }

  @override
  State<SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<SearchPickerSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<T> _rows = [];
  Timer? _debounce;
  String _search = '';
  int _page = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadFirstPage());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(AppConfig.searchDebounce, () {
      _search = value.trim();
      unawaited(_loadFirstPage());
    });
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
    });

    try {
      final page = await widget.fetch(_search, 0);
      if (!mounted) {
        return;
      }
      setState(() {
        _rows
          ..clear()
          ..addAll(page.content);
        _hasMore = page.hasMore;
        _loading = false;
      });
    } on ApiException catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _rows.clear();
        _hasMore = false;
        _loading = false;
        _error = failure.message;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore) {
      return;
    }
    setState(() => _loadingMore = true);

    try {
      final page = await widget.fetch(_search, _page + 1);
      if (!mounted) {
        return;
      }
      setState(() {
        _page += 1;
        _rows.addAll(page.content);
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } on ApiException {
      if (!mounted) {
        return;
      }
      // Keep the rows already fetched; the user can still pick from them.
      setState(() {
        _hasMore = false;
        _loadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      unawaited(_loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: AsyncStateView(
                isLoading: _loading,
                isEmpty: _rows.isEmpty,
                error: _error,
                onRetry: _loadFirstPage,
                emptyIcon: Icons.search_off,
                emptyTitle: 'Nothing matched',
                emptyMessage: widget.emptyMessage,
                child: ListView.separated(
                  controller: _scrollController,
                  itemCount: _rows.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index >= _rows.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        ),
                      );
                    }
                    final value = _rows[index];
                    return widget.rowBuilder(
                      context,
                      value,
                      () => Navigator.of(context).pop(value),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
