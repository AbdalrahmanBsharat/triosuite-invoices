// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Currency _$CurrencyFromJson(Map<String, dynamic> json) => _Currency(
  code: json['code'] as String,
  name: json['name'] as String,
  symbol: json['symbol'] as String,
  minorUnits: (json['minorUnits'] as num).toInt(),
  active: json['active'] as bool,
);

Map<String, dynamic> _$CurrencyToJson(_Currency instance) => <String, dynamic>{
  'code': instance.code,
  'name': instance.name,
  'symbol': instance.symbol,
  'minorUnits': instance.minorUnits,
  'active': instance.active,
};
