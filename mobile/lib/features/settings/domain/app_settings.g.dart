// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => _AppSettings(
  baseCurrencyCode: json['baseCurrencyCode'] as String,
  defaultCurrencyCode: json['defaultCurrencyCode'] as String,
  defaultTaxMode: $enumDecode(_$TaxModeEnumMap, json['defaultTaxMode']),
  defaultTaxRate: const DecimalConverter().fromJson(
    json['defaultTaxRate'] as Object,
  ),
  invoiceNumberPrefix: json['invoiceNumberPrefix'] as String,
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$AppSettingsToJson(
  _AppSettings instance,
) => <String, dynamic>{
  'baseCurrencyCode': instance.baseCurrencyCode,
  'defaultCurrencyCode': instance.defaultCurrencyCode,
  'defaultTaxMode': _$TaxModeEnumMap[instance.defaultTaxMode]!,
  'defaultTaxRate': const DecimalConverter().toJson(instance.defaultTaxRate),
  'invoiceNumberPrefix': instance.invoiceNumberPrefix,
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$TaxModeEnumMap = {
  TaxMode.exclusive: 'EXCLUSIVE',
  TaxMode.inclusive: 'INCLUSIVE',
};
