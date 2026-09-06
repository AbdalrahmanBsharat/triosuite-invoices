import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../settings/presentation/app_data_controller.dart';
import '../data/invoice_repository.dart';
import '../domain/invoice.dart';

/// The invoice list: filtering, searching and infinite scroll.
class InvoiceListController extends GetxController {
  InvoiceListController({
    required InvoiceRepository invoiceRepository,
    required AppDataController appDataController,
  })  : _invoices = invoiceRepository,
        _appData = appDataController;

  /// Distance from the bottom at which the next page is fetched, so the spinner is rarely seen.
  static const double _prefetchExtent = 320;

  final InvoiceRepository _invoices;
  final AppDataController _appData;

  final ScrollController scrollController = ScrollController();
  final TextEditingController searchController = TextEditingController();

  final RxList<InvoiceSummary> invoices = <InvoiceSummary>[].obs;
  final Rxn<InvoiceStatus> statusFilter = Rxn<InvoiceStatus>();
  final RxString searchTerm = ''.obs;

  /// True only for a first load or a filter change — a pull-to-refresh keeps the rows on screen.
  final RxBool loading = false.obs;
  final RxBool loadingMore = false.obs;
  final RxnString error = RxnString();

  int _page = 0;
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  @override
  void onInit() {
    super.onInit();

    // One request per pause in typing, not one per keystroke.
    debounce<String>(
      searchTerm,
      (_) => reload(),
      time: AppConfig.searchDebounce,
    );

    scrollController.addListener(_onScroll);
    _appData.ensureLoaded();
    reload();
  }

  @override
  void onClose() {
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    searchController.dispose();
    super.onClose();
  }

  /// Applies a status chip. Passing null means "all", which is the default.
  void setStatusFilter(InvoiceStatus? status) {
    if (statusFilter.value == status) {
      return;
    }
    statusFilter.value = status;
    reload();
  }

  void onSearchChanged(String value) => searchTerm.value = value;

  void clearSearch() {
    searchController.clear();
    searchTerm.value = '';
  }

  /// Fetches the first page, showing a spinner in place of the list.
  Future<void> reload() => _fetchFirstPage(showSpinner: true);

  /// Fetches the first page, keeping the current rows visible — for pull-to-refresh.
  Future<void> refreshQuietly() => _fetchFirstPage(showSpinner: false);

  Future<void> _fetchFirstPage({required bool showSpinner}) async {
    if (showSpinner) {
      loading.value = true;
    }
    error.value = null;
    _page = 0;

    try {
      final page = await _invoices.list(
        status: statusFilter.value,
        search: searchTerm.value,
        page: 0,
      );
      invoices.assignAll(page.content);
      _hasMore = page.hasMore;
    } on ApiException catch (failure) {
      error.value = failure.message;
      invoices.clear();
      _hasMore = false;
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (loadingMore.value || loading.value || !_hasMore) {
      return;
    }
    loadingMore.value = true;

    try {
      final next = await _invoices.list(
        status: statusFilter.value,
        search: searchTerm.value,
        page: _page + 1,
      );
      _page += 1;
      invoices.addAll(next.content);
      _hasMore = next.hasMore;
    } on ApiException catch (failure) {
      // A failed page does not wipe the rows already on screen; the user keeps what they had and
      // can pull to refresh.
      error.value = failure.message;
      _hasMore = false;
    } finally {
      loadingMore.value = false;
    }
  }

  void _onScroll() {
    if (!scrollController.hasClients) {
      return;
    }
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _prefetchExtent) {
      loadMore();
    }
  }

  /// The symbol for a currency, so a row can render its total.
  String symbolOf(String currencyCode) => _appData.symbolOf(currencyCode);

  /// The decimal places a currency is quoted in.
  int minorUnitsOf(String currencyCode) => _appData.minorUnitsOf(currencyCode);
}
