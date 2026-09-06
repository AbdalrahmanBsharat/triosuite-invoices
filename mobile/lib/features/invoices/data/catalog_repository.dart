import 'package:decimal/decimal.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/page_response.dart';
import '../domain/currency.dart';
import '../domain/customer.dart';
import '../domain/exchange_rate.dart';
import '../domain/item.dart';

/// The reference data behind the Create Invoice screen.
class CatalogRepository {
  const CatalogRepository(this._api);

  final ApiClient _api;

  /// Every currency an invoice may be issued in, with the minor units the app rounds by.
  Future<List<Currency>> currencies() async {
    final json = await _api.get('/api/currencies');
    return (json as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Currency.fromJson)
        .toList(growable: false);
  }

  /// The rate suggested for each currency when a new invoice is created.
  Future<List<ExchangeRate>> exchangeRates() async {
    final json = await _api.get('/api/exchange-rates');
    return (json as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ExchangeRate.fromJson)
        .toList(growable: false);
  }

  /// Sets the suggested rate for one currency. Administrators only.
  ///
  /// Invoices already issued are unaffected: each keeps the rate it was saved with.
  Future<ExchangeRate> updateExchangeRate({
    required String currencyCode,
    required Decimal rateToBase,
  }) async {
    final json = await _api.put(
      '/api/exchange-rates/$currencyCode',
      body: {'rateToBase': rateToBase.toString()},
    );
    return ExchangeRate.fromJson(json as Map<String, dynamic>);
  }

  /// Active customers matching a search term.
  Future<PageResponse<Customer>> customers({
    String? search,
    int page = 0,
    int size = AppConfig.pageSize,
  }) async {
    final json = await _api.get('/api/customers', query: {
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'size': size,
    });
    return PageResponse.fromJson(json as Map<String, dynamic>, Customer.fromJson);
  }

  /// Active catalogue items matching a search term.
  Future<PageResponse<Item>> items({
    String? search,
    int page = 0,
    int size = AppConfig.pageSize,
  }) async {
    final json = await _api.get('/api/items', query: {
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'size': size,
    });
    return PageResponse.fromJson(json as Map<String, dynamic>, Item.fromJson);
  }

  /// Looks an item up by the exact code the scanner read.
  ///
  /// Throws an [ApiException] with `NOT_FOUND` when no item carries it, which the scanner sheet
  /// treats as an ordinary outcome — it reports "not in the catalogue" and keeps scanning.
  Future<Item> itemByBarcode(String barcode) async {
    final json = await _api.get('/api/items/by-barcode/$barcode');
    return Item.fromJson(json as Map<String, dynamic>);
  }
}
