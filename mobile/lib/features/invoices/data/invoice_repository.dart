import 'package:decimal/decimal.dart';

import '../../../core/config/app_config.dart';
import '../../../core/money/tax_mode.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/page_response.dart';
import '../domain/invoice.dart';

/// One line as the app sends it.
///
/// Note what it does not carry: no tax rate and no amounts. The server takes the rate from the
/// catalogue item and computes every amount itself, so a client cannot invoice at a rate of its own
/// choosing or state a total that does not follow from the lines.
class InvoiceLineDraft {
  const InvoiceLineDraft({
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
  });

  final int itemId;
  final Decimal quantity;
  final Decimal unitPrice;

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        // Decimals cross the wire as strings; nothing the user typed passes through a double.
        'quantity': quantity.toString(),
        'unitPrice': unitPrice.toString(),
      };
}

/// The header the app sends, shared by create and update.
class InvoiceDraft {
  const InvoiceDraft({
    required this.customerId,
    required this.currencyCode,
    required this.exchangeRate,
    required this.taxMode,
    required this.issueDate,
    required this.lines,
    this.notes,
  });

  final int customerId;
  final String currencyCode;
  final Decimal exchangeRate;
  final TaxMode taxMode;
  final DateTime issueDate;
  final String? notes;
  final List<InvoiceLineDraft> lines;

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'currencyCode': currencyCode,
        'exchangeRate': exchangeRate.toString(),
        'taxMode': taxMode.wireName,
        'issueDate': _isoDate(issueDate),
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
        'lines': lines.map((line) => line.toJson()).toList(growable: false),
      };

  /// `LocalDate` on the server, so send a plain calendar date with no time and no zone.
  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// The invoice lifecycle.
///
/// There is no `delete`, because the API has no such endpoint. An invoice that should not stand is
/// cancelled, which keeps the record and its audit trail.
class InvoiceRepository {
  const InvoiceRepository(this._api);

  final ApiClient _api;

  /// One page of the list, newest first.
  Future<PageResponse<InvoiceSummary>> list({
    InvoiceStatus? status,
    String? search,
    int page = 0,
    int size = AppConfig.pageSize,
  }) async {
    final json = await _api.get('/api/invoices', query: {
      if (status != null) 'status': status.wireName,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'size': size,
      'sort': 'issueDate,desc',
    });
    return PageResponse.fromJson(json as Map<String, dynamic>, InvoiceSummary.fromJson);
  }

  /// The full document: header, lines, totals and audit trail.
  Future<Invoice> byId(int id) async {
    final json = await _api.get('/api/invoices/$id');
    return Invoice.fromJson(json as Map<String, dynamic>);
  }

  /// Creates a DRAFT. The server allocates the number; the app never sends one.
  Future<Invoice> create(InvoiceDraft draft) async {
    final json = await _api.post('/api/invoices', body: draft.toJson());
    return Invoice.fromJson(json as Map<String, dynamic>);
  }

  /// Replaces the header and every line of a DRAFT.
  ///
  /// [version] is the one last read. A mismatch is answered with `409 STALE_VERSION` rather than
  /// silently overwriting whoever got there first.
  Future<Invoice> update({
    required int id,
    required int version,
    required InvoiceDraft draft,
  }) async {
    final json = await _api.put('/api/invoices/$id', body: {
      'version': version,
      ...draft.toJson(),
    });
    return Invoice.fromJson(json as Map<String, dynamic>);
  }

  /// DRAFT to APPROVED, after which the invoice can no longer be edited.
  Future<Invoice> approve({required int id, required int version}) async {
    final json = await _api.post('/api/invoices/$id/approve', body: {'version': version});
    return Invoice.fromJson(json as Map<String, dynamic>);
  }

  /// DRAFT or APPROVED to CANCELLED. Administrators only.
  Future<Invoice> cancel({
    required int id,
    required int version,
    String? reason,
  }) async {
    final json = await _api.post('/api/invoices/$id/cancel', body: {
      'version': version,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return Invoice.fromJson(json as Map<String, dynamic>);
  }
}
