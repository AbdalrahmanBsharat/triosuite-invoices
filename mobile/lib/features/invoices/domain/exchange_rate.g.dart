// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exchange_rate.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ExchangeRate _$ExchangeRateFromJson(Map<String, dynamic> json) =>
    _ExchangeRate(
      currencyCode: json['currencyCode'] as String,
      rateToBase: const DecimalConverter().fromJson(
        json['rateToBase'] as Object,
      ),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ExchangeRateToJson(_ExchangeRate instance) =>
    <String, dynamic>{
      'currencyCode': instance.currencyCode,
      'rateToBase': const DecimalConverter().toJson(instance.rateToBase),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
