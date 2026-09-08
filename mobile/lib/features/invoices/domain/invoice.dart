import 'package:decimal/decimal.dart';

import '../../../core/money/decimal_json.dart';
import '../../../core/money/tax_mode.dart';

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
  draft('DRAFT', 'Draft'),
  approved('APPROVED', 'Approved'),
  cancelled('CANCELLED', 'Cancelled');

  const InvoiceStatus(this.wireName, this.label);

  /// The value used for the `status` query parameter, and the one the API sends back.
  final String wireName;

  /// The name shown on the status badge.
  final String label;

  bool get isEditable => this == InvoiceStatus.draft;

  bool get canApprove => this == InvoiceStatus.draft;

  bool get canCancel => this == InvoiceStatus.draft || this == InvoiceStatus.approved;

  /// Anything unrecognised becomes [cancelled], the most restrictive of the three — a status added
  /// to the server later must not make an older build offer Approve or Edit on it.
  static InvoiceStatus fromWire(String? wireName) => InvoiceStatus.values.firstWhere(
        (status) => status.wireName == wireName,
        orElse: () => InvoiceStatus.cancelled,
      );
}

/// One priced line of an invoice, as stored.
///
/// [itemName] and [barcode] are the snapshots taken when the line was written, not the catalogue's
/// current values — which is why an invoice from last year still renders as it was issued.
class InvoiceLine {
  const InvoiceLine({
    this.id,
    required this.lineNo,
    required this.itemId,
    required this.itemName,
    this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.taxRate,
    required this.netAmount,
    required this.taxAmount,
    required this.grossAmount,
  });

  final int? id;
  final int lineNo;
  final int itemId;
  final String itemName;
  final String? barcode;
  final Decimal quantity;
  final Decimal unitPrice;
  final Decimal taxRate;
  final Decimal netAmount;
  final Decimal taxAmount;
  final Decimal grossAmount;

  factory InvoiceLine.fromJson(Map<String, dynamic> json) {
    return InvoiceLine(
      id: json['id'] as int?,
      lineNo: json['lineNo'] as int,
      itemId: json['itemId'] as int,
      itemName: json['itemName'] as String,
      barcode: json['barcode'] as String?,
      quantity: decimalFromJson(json['quantity']),
      unitPrice: decimalFromJson(json['unitPrice']),
      taxRate: decimalFromJson(json['taxRate']),
      netAmount: decimalFromJson(json['netAmount']),
      taxAmount: decimalFromJson(json['taxAmount']),
      grossAmount: decimalFromJson(json['grossAmount']),
    );
  }
}

/// A full invoice: header, lines, server-computed totals and the audit trail.
///
/// [version] must be echoed back on update, approve and cancel. A mismatch means someone else
/// changed the record, and the server answers `409 STALE_VERSION` rather than overwriting them.
class Invoice {
  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.version,
    required this.customerId,
    required this.customerName,
    required this.currencyCode,
    required this.currencySymbol,
    required this.currencyMinorUnits,
    required this.exchangeRate,
    required this.baseCurrencyCode,
    required this.taxMode,
    required this.issueDate,
    this.notes,
    required this.subtotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.grandTotalBase,
    this.lines = const <InvoiceLine>[],
    this.createdBy,
    this.createdAt,
    this.approvedBy,
    this.approvedAt,
    this.cancelledBy,
    this.cancelledAt,
    this.cancellationReason,
    this.updatedAt,
  });

  final int id;
  final String invoiceNumber;
  final InvoiceStatus status;
  final int version;
  final int customerId;
  final String customerName;
  final String currencyCode;
  final String currencySymbol;
  final int currencyMinorUnits;
  final Decimal exchangeRate;
  final String baseCurrencyCode;
  final TaxMode taxMode;
  final DateTime issueDate;
  final String? notes;
  final Decimal subtotal;
  final Decimal taxTotal;
  final Decimal grandTotal;
  final Decimal grandTotalBase;
  final List<InvoiceLine> lines;
  final String? createdBy;
  final DateTime? createdAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? cancelledBy;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime? updatedAt;

  /// Whether the base-currency total is worth showing separately.
  ///
  /// For an invoice already in the base currency the two figures are identical, and repeating them
  /// is noise.
  bool get showsBaseCurrencyTotal => currencyCode != baseCurrencyCode;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as int,
      invoiceNumber: json['invoiceNumber'] as String,
      status: InvoiceStatus.fromWire(json['status'] as String?),
      version: json['version'] as int,
      customerId: json['customerId'] as int,
      customerName: json['customerName'] as String,
      currencyCode: json['currencyCode'] as String,
      currencySymbol: json['currencySymbol'] as String,
      currencyMinorUnits: json['currencyMinorUnits'] as int,
      exchangeRate: decimalFromJson(json['exchangeRate']),
      baseCurrencyCode: json['baseCurrencyCode'] as String,
      taxMode: TaxMode.fromWire(json['taxMode'] as String?),
      issueDate: DateTime.parse(json['issueDate'] as String),
      notes: json['notes'] as String?,
      subtotal: decimalFromJson(json['subtotal']),
      taxTotal: decimalFromJson(json['taxTotal']),
      grandTotal: decimalFromJson(json['grandTotal']),
      grandTotalBase: decimalFromJson(json['grandTotalBase']),
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(InvoiceLine.fromJson)
          .toList(growable: false),
      createdBy: json['createdBy'] as String?,
      createdAt: _dateOrNull(json['createdAt']),
      approvedBy: json['approvedBy'] as String?,
      approvedAt: _dateOrNull(json['approvedAt']),
      cancelledBy: json['cancelledBy'] as String?,
      cancelledAt: _dateOrNull(json['cancelledAt']),
      cancellationReason: json['cancellationReason'] as String?,
      updatedAt: _dateOrNull(json['updatedAt']),
    );
  }
}

/// A row of the invoice list. Deliberately narrower than [Invoice]: listing a page never loads
/// anyone's lines.
class InvoiceSummary {
  const InvoiceSummary({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.issueDate,
    required this.currencyCode,
    required this.currencySymbol,
    required this.grandTotal,
    required this.grandTotalBase,
    required this.status,
  });

  final int id;
  final String invoiceNumber;
  final String customerName;
  final DateTime issueDate;
  final String currencyCode;
  final String currencySymbol;
  final Decimal grandTotal;
  final Decimal grandTotalBase;
  final InvoiceStatus status;

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) {
    return InvoiceSummary(
      id: json['id'] as int,
      invoiceNumber: json['invoiceNumber'] as String,
      customerName: json['customerName'] as String,
      issueDate: DateTime.parse(json['issueDate'] as String),
      currencyCode: json['currencyCode'] as String,
      currencySymbol: json['currencySymbol'] as String,
      grandTotal: decimalFromJson(json['grandTotal']),
      grandTotalBase: decimalFromJson(json['grandTotalBase']),
      status: InvoiceStatus.fromWire(json['status'] as String?),
    );
  }
}

/// The audit timestamps are absent on a draft and filled in as the invoice moves through its
/// lifecycle, so every one of them has to tolerate a missing value.
DateTime? _dateOrNull(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
