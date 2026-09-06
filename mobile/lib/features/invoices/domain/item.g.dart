// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Item _$ItemFromJson(Map<String, dynamic> json) => _Item(
  id: (json['id'] as num).toInt(),
  sku: json['sku'] as String,
  barcode: json['barcode'] as String?,
  name: json['name'] as String,
  unitPrice: const DecimalConverter().fromJson(json['unitPrice'] as Object),
  currencyCode: json['currencyCode'] as String,
  taxRate: const DecimalConverter().fromJson(json['taxRate'] as Object),
  active: json['active'] as bool? ?? true,
);

Map<String, dynamic> _$ItemToJson(_Item instance) => <String, dynamic>{
  'id': instance.id,
  'sku': instance.sku,
  'barcode': instance.barcode,
  'name': instance.name,
  'unitPrice': const DecimalConverter().toJson(instance.unitPrice),
  'currencyCode': instance.currencyCode,
  'taxRate': const DecimalConverter().toJson(instance.taxRate),
  'active': instance.active,
};
