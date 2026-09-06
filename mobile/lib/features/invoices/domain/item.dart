import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/network/json_converters.dart';

part 'item.freezed.dart';
part 'item.g.dart';

/// A catalogue entry, found by search or by scanning its barcode.
///
/// [unitPrice] and [taxRate] are catalogue defaults. When the item is put on an invoice the server
/// copies them onto the line, so re-pricing an item later never changes an invoice already issued.
@freezed
abstract class Item with _$Item {
  const factory Item({
    required int id,
    required String sku,
    String? barcode,
    required String name,
    @DecimalConverter() required Decimal unitPrice,
    required String currencyCode,
    @DecimalConverter() required Decimal taxRate,
    @Default(true) bool active,
  }) = _Item;

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
}
