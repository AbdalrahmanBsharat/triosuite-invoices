import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/money/tax_mode.dart';
import '../../../core/network/json_converters.dart';

part 'invoice.freezed.dart';
part 'invoice.g.dart';

/// Where an invoice is in its lifecycle.
///
/// ```
///   DRAFT ──approve──▶ APPROVED ──cancel──▶ CANCELLED
///     │                                         ▲
///     └──────────────────cancel──────────────────┘
/// ```
///
/// The server is the only authority on these transitions; the getters below exist so the UI can
/// offer the right buttons, not so it can decide anything.
enum InvoiceStatus {
  @JsonValue('DRAFT')
  draft,

  @JsonValue('APPROVED')
  approved,

  @JsonValue('CANCELLED')
  cancelled;

  String get label => switch (this) {
        InvoiceStatus.draft => 'Draft',
        InvoiceStatus.approved => 'Approved',
        InvoiceStatus.cancelled => 'Cancelled',
      };

  /// The value used for the `status` query parameter on the list endpoint.
  String get wireName => switch (this) {
        InvoiceStatus.draft => 'DRAFT',
        InvoiceStatus.approved => 'APPROVED',
        InvoiceStatus.cancelled => 'CANCELLED',
      };

  bool get isEditable => this == InvoiceStatus.draft;

  bool get canApprove => this == InvoiceStatus.draft;

  bool get canCancel => this == InvoiceStatus.draft || this == InvoiceStatus.approved;
}

/// One priced line of an invoice, as stored.
///
/// [itemName] and [barcode] are the snapshots taken when the line was written, not the catalogue's
/// current values — which is why an invoice from last year still renders as it was issued.
@freezed
abstract class InvoiceLine with _$InvoiceLine {
  const factory InvoiceLine({
    int? id,
    required int lineNo,
    required int itemId,
    required String itemName,
    String? barcode,
    @DecimalConverter() required Decimal quantity,
    @DecimalConverter() required Decimal unitPrice,
    @DecimalConverter() required Decimal taxRate,
    @DecimalConverter() required Decimal netAmount,
    @DecimalConverter() required Decimal taxAmount,
    @DecimalConverter() required Decimal grossAmount,
  }) = _InvoiceLine;

  factory InvoiceLine.fromJson(Map<String, dynamic> json) => _$InvoiceLineFromJson(json);
}

/// A full invoice: header, lines, server-computed totals and the audit trail.
///
/// [version] must be echoed back on update, approve and cancel. A mismatch means someone else
/// changed the record, and the server answers `409 STALE_VERSION` rather than overwriting them.
@freezed
abstract class Invoice with _$Invoice {
  const factory Invoice({
    required int id,
    required String invoiceNumber,
    required InvoiceStatus status,
    required int version,
    required int customerId,
    required String customerName,
    required String currencyCode,
    required String currencySymbol,
    required int currencyMinorUnits,
    @DecimalConverter() required Decimal exchangeRate,
    required String baseCurrencyCode,
    required TaxMode taxMode,
    required DateTime issueDate,
    String? notes,
    @DecimalConverter() required Decimal subtotal,
    @DecimalConverter() required Decimal taxTotal,
    @DecimalConverter() required Decimal grandTotal,
    @DecimalConverter() required Decimal grandTotalBase,
    @Default(<InvoiceLine>[]) List<InvoiceLine> lines,
    String? createdBy,
    DateTime? createdAt,
    String? approvedBy,
    DateTime? approvedAt,
    String? cancelledBy,
    DateTime? cancelledAt,
    String? cancellationReason,
    DateTime? updatedAt,
  }) = _Invoice;

  const Invoice._();

  factory Invoice.fromJson(Map<String, dynamic> json) => _$InvoiceFromJson(json);

  /// Whether the base-currency total is worth showing separately.
  ///
  /// For an invoice already in the base currency the two figures are identical, and repeating them
  /// is noise.
  bool get showsBaseCurrencyTotal => currencyCode != baseCurrencyCode;
}

/// A row of the invoice list. Deliberately narrower than [Invoice]: listing a page never loads
/// anyone's lines.
@freezed
abstract class InvoiceSummary with _$InvoiceSummary {
  const factory InvoiceSummary({
    required int id,
    required String invoiceNumber,
    required String customerName,
    required DateTime issueDate,
    required String currencyCode,
    required String currencySymbol,
    @DecimalConverter() required Decimal grandTotal,
    @DecimalConverter() required Decimal grandTotalBase,
    required InvoiceStatus status,
  }) = _InvoiceSummary;

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) => _$InvoiceSummaryFromJson(json);
}
