import 'package:decimal/decimal.dart';

import '../../../core/money/decimal_json.dart';

/// A catalogue entry, found by search or by scanning its barcode.
///
/// [unitPrice] and [taxRate] are catalogue defaults. When the item is put on an invoice the server
/// copies them onto the line, so re-pricing an item later never changes an invoice already issued.
class Item {
  const Item({
    required this.id,
    required this.sku,
    this.barcode,
    required this.name,
    required this.unitPrice,
    required this.currencyCode,
    required this.taxRate,
    this.active = true,
  });

  final int id;
  final String sku;
  final String? barcode;
  final String name;
  final Decimal unitPrice;
  final String currencyCode;
  final Decimal taxRate;
  final bool active;

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as int,
      sku: json['sku'] as String,
      barcode: json['barcode'] as String?,
      name: json['name'] as String,
      unitPrice: decimalFromJson(json['unitPrice']),
      currencyCode: json['currencyCode'] as String,
      taxRate: decimalFromJson(json['taxRate']),
      active: json['active'] as bool? ?? true,
    );
  }
}
