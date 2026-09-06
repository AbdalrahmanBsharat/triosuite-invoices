// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InvoiceLine _$InvoiceLineFromJson(Map<String, dynamic> json) => _InvoiceLine(
  id: (json['id'] as num?)?.toInt(),
  lineNo: (json['lineNo'] as num).toInt(),
  itemId: (json['itemId'] as num).toInt(),
  itemName: json['itemName'] as String,
  barcode: json['barcode'] as String?,
  quantity: const DecimalConverter().fromJson(json['quantity'] as Object),
  unitPrice: const DecimalConverter().fromJson(json['unitPrice'] as Object),
  taxRate: const DecimalConverter().fromJson(json['taxRate'] as Object),
  netAmount: const DecimalConverter().fromJson(json['netAmount'] as Object),
  taxAmount: const DecimalConverter().fromJson(json['taxAmount'] as Object),
  grossAmount: const DecimalConverter().fromJson(json['grossAmount'] as Object),
);

Map<String, dynamic> _$InvoiceLineToJson(_InvoiceLine instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lineNo': instance.lineNo,
      'itemId': instance.itemId,
      'itemName': instance.itemName,
      'barcode': instance.barcode,
      'quantity': const DecimalConverter().toJson(instance.quantity),
      'unitPrice': const DecimalConverter().toJson(instance.unitPrice),
      'taxRate': const DecimalConverter().toJson(instance.taxRate),
      'netAmount': const DecimalConverter().toJson(instance.netAmount),
      'taxAmount': const DecimalConverter().toJson(instance.taxAmount),
      'grossAmount': const DecimalConverter().toJson(instance.grossAmount),
    };

_Invoice _$InvoiceFromJson(Map<String, dynamic> json) => _Invoice(
  id: (json['id'] as num).toInt(),
  invoiceNumber: json['invoiceNumber'] as String,
  status: $enumDecode(_$InvoiceStatusEnumMap, json['status']),
  version: (json['version'] as num).toInt(),
  customerId: (json['customerId'] as num).toInt(),
  customerName: json['customerName'] as String,
  currencyCode: json['currencyCode'] as String,
  currencySymbol: json['currencySymbol'] as String,
  currencyMinorUnits: (json['currencyMinorUnits'] as num).toInt(),
  exchangeRate: const DecimalConverter().fromJson(
    json['exchangeRate'] as Object,
  ),
  baseCurrencyCode: json['baseCurrencyCode'] as String,
  taxMode: $enumDecode(_$TaxModeEnumMap, json['taxMode']),
  issueDate: DateTime.parse(json['issueDate'] as String),
  notes: json['notes'] as String?,
  subtotal: const DecimalConverter().fromJson(json['subtotal'] as Object),
  taxTotal: const DecimalConverter().fromJson(json['taxTotal'] as Object),
  grandTotal: const DecimalConverter().fromJson(json['grandTotal'] as Object),
  grandTotalBase: const DecimalConverter().fromJson(
    json['grandTotalBase'] as Object,
  ),
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => InvoiceLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <InvoiceLine>[],
  createdBy: json['createdBy'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  approvedBy: json['approvedBy'] as String?,
  approvedAt: json['approvedAt'] == null
      ? null
      : DateTime.parse(json['approvedAt'] as String),
  cancelledBy: json['cancelledBy'] as String?,
  cancelledAt: json['cancelledAt'] == null
      ? null
      : DateTime.parse(json['cancelledAt'] as String),
  cancellationReason: json['cancellationReason'] as String?,
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$InvoiceToJson(_Invoice instance) => <String, dynamic>{
  'id': instance.id,
  'invoiceNumber': instance.invoiceNumber,
  'status': _$InvoiceStatusEnumMap[instance.status]!,
  'version': instance.version,
  'customerId': instance.customerId,
  'customerName': instance.customerName,
  'currencyCode': instance.currencyCode,
  'currencySymbol': instance.currencySymbol,
  'currencyMinorUnits': instance.currencyMinorUnits,
  'exchangeRate': const DecimalConverter().toJson(instance.exchangeRate),
  'baseCurrencyCode': instance.baseCurrencyCode,
  'taxMode': _$TaxModeEnumMap[instance.taxMode]!,
  'issueDate': instance.issueDate.toIso8601String(),
  'notes': instance.notes,
  'subtotal': const DecimalConverter().toJson(instance.subtotal),
  'taxTotal': const DecimalConverter().toJson(instance.taxTotal),
  'grandTotal': const DecimalConverter().toJson(instance.grandTotal),
  'grandTotalBase': const DecimalConverter().toJson(instance.grandTotalBase),
  'lines': instance.lines,
  'createdBy': instance.createdBy,
  'createdAt': instance.createdAt?.toIso8601String(),
  'approvedBy': instance.approvedBy,
  'approvedAt': instance.approvedAt?.toIso8601String(),
  'cancelledBy': instance.cancelledBy,
  'cancelledAt': instance.cancelledAt?.toIso8601String(),
  'cancellationReason': instance.cancellationReason,
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

const _$InvoiceStatusEnumMap = {
  InvoiceStatus.draft: 'DRAFT',
  InvoiceStatus.approved: 'APPROVED',
  InvoiceStatus.cancelled: 'CANCELLED',
};

const _$TaxModeEnumMap = {
  TaxMode.exclusive: 'EXCLUSIVE',
  TaxMode.inclusive: 'INCLUSIVE',
};

_InvoiceSummary _$InvoiceSummaryFromJson(Map<String, dynamic> json) =>
    _InvoiceSummary(
      id: (json['id'] as num).toInt(),
      invoiceNumber: json['invoiceNumber'] as String,
      customerName: json['customerName'] as String,
      issueDate: DateTime.parse(json['issueDate'] as String),
      currencyCode: json['currencyCode'] as String,
      currencySymbol: json['currencySymbol'] as String,
      grandTotal: const DecimalConverter().fromJson(
        json['grandTotal'] as Object,
      ),
      grandTotalBase: const DecimalConverter().fromJson(
        json['grandTotalBase'] as Object,
      ),
      status: $enumDecode(_$InvoiceStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$InvoiceSummaryToJson(
  _InvoiceSummary instance,
) => <String, dynamic>{
  'id': instance.id,
  'invoiceNumber': instance.invoiceNumber,
  'customerName': instance.customerName,
  'issueDate': instance.issueDate.toIso8601String(),
  'currencyCode': instance.currencyCode,
  'currencySymbol': instance.currencySymbol,
  'grandTotal': const DecimalConverter().toJson(instance.grandTotal),
  'grandTotalBase': const DecimalConverter().toJson(instance.grandTotalBase),
  'status': _$InvoiceStatusEnumMap[instance.status]!,
};
