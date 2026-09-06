// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppSettings {

 String get baseCurrencyCode; String get defaultCurrencyCode; TaxMode get defaultTaxMode;@DecimalConverter() Decimal get defaultTaxRate; String get invoiceNumberPrefix; DateTime get updatedAt;
/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSettingsCopyWith<AppSettings> get copyWith => _$AppSettingsCopyWithImpl<AppSettings>(this as AppSettings, _$identity);

  /// Serializes this AppSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSettings&&(identical(other.baseCurrencyCode, baseCurrencyCode) || other.baseCurrencyCode == baseCurrencyCode)&&(identical(other.defaultCurrencyCode, defaultCurrencyCode) || other.defaultCurrencyCode == defaultCurrencyCode)&&(identical(other.defaultTaxMode, defaultTaxMode) || other.defaultTaxMode == defaultTaxMode)&&(identical(other.defaultTaxRate, defaultTaxRate) || other.defaultTaxRate == defaultTaxRate)&&(identical(other.invoiceNumberPrefix, invoiceNumberPrefix) || other.invoiceNumberPrefix == invoiceNumberPrefix)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,baseCurrencyCode,defaultCurrencyCode,defaultTaxMode,defaultTaxRate,invoiceNumberPrefix,updatedAt);

@override
String toString() {
  return 'AppSettings(baseCurrencyCode: $baseCurrencyCode, defaultCurrencyCode: $defaultCurrencyCode, defaultTaxMode: $defaultTaxMode, defaultTaxRate: $defaultTaxRate, invoiceNumberPrefix: $invoiceNumberPrefix, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $AppSettingsCopyWith<$Res>  {
  factory $AppSettingsCopyWith(AppSettings value, $Res Function(AppSettings) _then) = _$AppSettingsCopyWithImpl;
@useResult
$Res call({
 String baseCurrencyCode, String defaultCurrencyCode, TaxMode defaultTaxMode,@DecimalConverter() Decimal defaultTaxRate, String invoiceNumberPrefix, DateTime updatedAt
});




}
/// @nodoc
class _$AppSettingsCopyWithImpl<$Res>
    implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._self, this._then);

  final AppSettings _self;
  final $Res Function(AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? baseCurrencyCode = null,Object? defaultCurrencyCode = null,Object? defaultTaxMode = null,Object? defaultTaxRate = null,Object? invoiceNumberPrefix = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
baseCurrencyCode: null == baseCurrencyCode ? _self.baseCurrencyCode : baseCurrencyCode // ignore: cast_nullable_to_non_nullable
as String,defaultCurrencyCode: null == defaultCurrencyCode ? _self.defaultCurrencyCode : defaultCurrencyCode // ignore: cast_nullable_to_non_nullable
as String,defaultTaxMode: null == defaultTaxMode ? _self.defaultTaxMode : defaultTaxMode // ignore: cast_nullable_to_non_nullable
as TaxMode,defaultTaxRate: null == defaultTaxRate ? _self.defaultTaxRate : defaultTaxRate // ignore: cast_nullable_to_non_nullable
as Decimal,invoiceNumberPrefix: null == invoiceNumberPrefix ? _self.invoiceNumberPrefix : invoiceNumberPrefix // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [AppSettings].
extension AppSettingsPatterns on AppSettings {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppSettings value)  $default,){
final _that = this;
switch (_that) {
case _AppSettings():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppSettings value)?  $default,){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String baseCurrencyCode,  String defaultCurrencyCode,  TaxMode defaultTaxMode, @DecimalConverter()  Decimal defaultTaxRate,  String invoiceNumberPrefix,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.baseCurrencyCode,_that.defaultCurrencyCode,_that.defaultTaxMode,_that.defaultTaxRate,_that.invoiceNumberPrefix,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String baseCurrencyCode,  String defaultCurrencyCode,  TaxMode defaultTaxMode, @DecimalConverter()  Decimal defaultTaxRate,  String invoiceNumberPrefix,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _AppSettings():
return $default(_that.baseCurrencyCode,_that.defaultCurrencyCode,_that.defaultTaxMode,_that.defaultTaxRate,_that.invoiceNumberPrefix,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String baseCurrencyCode,  String defaultCurrencyCode,  TaxMode defaultTaxMode, @DecimalConverter()  Decimal defaultTaxRate,  String invoiceNumberPrefix,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.baseCurrencyCode,_that.defaultCurrencyCode,_that.defaultTaxMode,_that.defaultTaxRate,_that.invoiceNumberPrefix,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppSettings implements AppSettings {
  const _AppSettings({required this.baseCurrencyCode, required this.defaultCurrencyCode, required this.defaultTaxMode, @DecimalConverter() required this.defaultTaxRate, required this.invoiceNumberPrefix, required this.updatedAt});
  factory _AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);

@override final  String baseCurrencyCode;
@override final  String defaultCurrencyCode;
@override final  TaxMode defaultTaxMode;
@override@DecimalConverter() final  Decimal defaultTaxRate;
@override final  String invoiceNumberPrefix;
@override final  DateTime updatedAt;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppSettingsCopyWith<_AppSettings> get copyWith => __$AppSettingsCopyWithImpl<_AppSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppSettings&&(identical(other.baseCurrencyCode, baseCurrencyCode) || other.baseCurrencyCode == baseCurrencyCode)&&(identical(other.defaultCurrencyCode, defaultCurrencyCode) || other.defaultCurrencyCode == defaultCurrencyCode)&&(identical(other.defaultTaxMode, defaultTaxMode) || other.defaultTaxMode == defaultTaxMode)&&(identical(other.defaultTaxRate, defaultTaxRate) || other.defaultTaxRate == defaultTaxRate)&&(identical(other.invoiceNumberPrefix, invoiceNumberPrefix) || other.invoiceNumberPrefix == invoiceNumberPrefix)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,baseCurrencyCode,defaultCurrencyCode,defaultTaxMode,defaultTaxRate,invoiceNumberPrefix,updatedAt);

@override
String toString() {
  return 'AppSettings(baseCurrencyCode: $baseCurrencyCode, defaultCurrencyCode: $defaultCurrencyCode, defaultTaxMode: $defaultTaxMode, defaultTaxRate: $defaultTaxRate, invoiceNumberPrefix: $invoiceNumberPrefix, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$AppSettingsCopyWith<$Res> implements $AppSettingsCopyWith<$Res> {
  factory _$AppSettingsCopyWith(_AppSettings value, $Res Function(_AppSettings) _then) = __$AppSettingsCopyWithImpl;
@override @useResult
$Res call({
 String baseCurrencyCode, String defaultCurrencyCode, TaxMode defaultTaxMode,@DecimalConverter() Decimal defaultTaxRate, String invoiceNumberPrefix, DateTime updatedAt
});




}
/// @nodoc
class __$AppSettingsCopyWithImpl<$Res>
    implements _$AppSettingsCopyWith<$Res> {
  __$AppSettingsCopyWithImpl(this._self, this._then);

  final _AppSettings _self;
  final $Res Function(_AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? baseCurrencyCode = null,Object? defaultCurrencyCode = null,Object? defaultTaxMode = null,Object? defaultTaxRate = null,Object? invoiceNumberPrefix = null,Object? updatedAt = null,}) {
  return _then(_AppSettings(
baseCurrencyCode: null == baseCurrencyCode ? _self.baseCurrencyCode : baseCurrencyCode // ignore: cast_nullable_to_non_nullable
as String,defaultCurrencyCode: null == defaultCurrencyCode ? _self.defaultCurrencyCode : defaultCurrencyCode // ignore: cast_nullable_to_non_nullable
as String,defaultTaxMode: null == defaultTaxMode ? _self.defaultTaxMode : defaultTaxMode // ignore: cast_nullable_to_non_nullable
as TaxMode,defaultTaxRate: null == defaultTaxRate ? _self.defaultTaxRate : defaultTaxRate // ignore: cast_nullable_to_non_nullable
as Decimal,invoiceNumberPrefix: null == invoiceNumberPrefix ? _self.invoiceNumberPrefix : invoiceNumberPrefix // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
