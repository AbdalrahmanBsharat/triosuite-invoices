// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invoice.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InvoiceLine {

 int? get id; int get lineNo; int get itemId; String get itemName; String? get barcode;@DecimalConverter() Decimal get quantity;@DecimalConverter() Decimal get unitPrice;@DecimalConverter() Decimal get taxRate;@DecimalConverter() Decimal get netAmount;@DecimalConverter() Decimal get taxAmount;@DecimalConverter() Decimal get grossAmount;
/// Create a copy of InvoiceLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceLineCopyWith<InvoiceLine> get copyWith => _$InvoiceLineCopyWithImpl<InvoiceLine>(this as InvoiceLine, _$identity);

  /// Serializes this InvoiceLine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceLine&&(identical(other.id, id) || other.id == id)&&(identical(other.lineNo, lineNo) || other.lineNo == lineNo)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.itemName, itemName) || other.itemName == itemName)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.taxRate, taxRate) || other.taxRate == taxRate)&&(identical(other.netAmount, netAmount) || other.netAmount == netAmount)&&(identical(other.taxAmount, taxAmount) || other.taxAmount == taxAmount)&&(identical(other.grossAmount, grossAmount) || other.grossAmount == grossAmount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,lineNo,itemId,itemName,barcode,quantity,unitPrice,taxRate,netAmount,taxAmount,grossAmount);

@override
String toString() {
  return 'InvoiceLine(id: $id, lineNo: $lineNo, itemId: $itemId, itemName: $itemName, barcode: $barcode, quantity: $quantity, unitPrice: $unitPrice, taxRate: $taxRate, netAmount: $netAmount, taxAmount: $taxAmount, grossAmount: $grossAmount)';
}


}

/// @nodoc
abstract mixin class $InvoiceLineCopyWith<$Res>  {
  factory $InvoiceLineCopyWith(InvoiceLine value, $Res Function(InvoiceLine) _then) = _$InvoiceLineCopyWithImpl;
@useResult
$Res call({
 int? id, int lineNo, int itemId, String itemName, String? barcode,@DecimalConverter() Decimal quantity,@DecimalConverter() Decimal unitPrice,@DecimalConverter() Decimal taxRate,@DecimalConverter() Decimal netAmount,@DecimalConverter() Decimal taxAmount,@DecimalConverter() Decimal grossAmount
});




}
/// @nodoc
class _$InvoiceLineCopyWithImpl<$Res>
    implements $InvoiceLineCopyWith<$Res> {
  _$InvoiceLineCopyWithImpl(this._self, this._then);

  final InvoiceLine _self;
  final $Res Function(InvoiceLine) _then;

/// Create a copy of InvoiceLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? lineNo = null,Object? itemId = null,Object? itemName = null,Object? barcode = freezed,Object? quantity = null,Object? unitPrice = null,Object? taxRate = null,Object? netAmount = null,Object? taxAmount = null,Object? grossAmount = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,lineNo: null == lineNo ? _self.lineNo : lineNo // ignore: cast_nullable_to_non_nullable
as int,itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as int,itemName: null == itemName ? _self.itemName : itemName // ignore: cast_nullable_to_non_nullable
as String,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Decimal,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate: null == taxRate ? _self.taxRate : taxRate // ignore: cast_nullable_to_non_nullable
as Decimal,netAmount: null == netAmount ? _self.netAmount : netAmount // ignore: cast_nullable_to_non_nullable
as Decimal,taxAmount: null == taxAmount ? _self.taxAmount : taxAmount // ignore: cast_nullable_to_non_nullable
as Decimal,grossAmount: null == grossAmount ? _self.grossAmount : grossAmount // ignore: cast_nullable_to_non_nullable
as Decimal,
  ));
}

}


/// Adds pattern-matching-related methods to [InvoiceLine].
extension InvoiceLinePatterns on InvoiceLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoiceLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoiceLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoiceLine value)  $default,){
final _that = this;
switch (_that) {
case _InvoiceLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoiceLine value)?  $default,){
final _that = this;
switch (_that) {
case _InvoiceLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  int lineNo,  int itemId,  String itemName,  String? barcode, @DecimalConverter()  Decimal quantity, @DecimalConverter()  Decimal unitPrice, @DecimalConverter()  Decimal taxRate, @DecimalConverter()  Decimal netAmount, @DecimalConverter()  Decimal taxAmount, @DecimalConverter()  Decimal grossAmount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceLine() when $default != null:
return $default(_that.id,_that.lineNo,_that.itemId,_that.itemName,_that.barcode,_that.quantity,_that.unitPrice,_that.taxRate,_that.netAmount,_that.taxAmount,_that.grossAmount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  int lineNo,  int itemId,  String itemName,  String? barcode, @DecimalConverter()  Decimal quantity, @DecimalConverter()  Decimal unitPrice, @DecimalConverter()  Decimal taxRate, @DecimalConverter()  Decimal netAmount, @DecimalConverter()  Decimal taxAmount, @DecimalConverter()  Decimal grossAmount)  $default,) {final _that = this;
switch (_that) {
case _InvoiceLine():
return $default(_that.id,_that.lineNo,_that.itemId,_that.itemName,_that.barcode,_that.quantity,_that.unitPrice,_that.taxRate,_that.netAmount,_that.taxAmount,_that.grossAmount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  int lineNo,  int itemId,  String itemName,  String? barcode, @DecimalConverter()  Decimal quantity, @DecimalConverter()  Decimal unitPrice, @DecimalConverter()  Decimal taxRate, @DecimalConverter()  Decimal netAmount, @DecimalConverter()  Decimal taxAmount, @DecimalConverter()  Decimal grossAmount)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceLine() when $default != null:
return $default(_that.id,_that.lineNo,_that.itemId,_that.itemName,_that.barcode,_that.quantity,_that.unitPrice,_that.taxRate,_that.netAmount,_that.taxAmount,_that.grossAmount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InvoiceLine implements InvoiceLine {
  const _InvoiceLine({this.id, required this.lineNo, required this.itemId, required this.itemName, this.barcode, @DecimalConverter() required this.quantity, @DecimalConverter() required this.unitPrice, @DecimalConverter() required this.taxRate, @DecimalConverter() required this.netAmount, @DecimalConverter() required this.taxAmount, @DecimalConverter() required this.grossAmount});
  factory _InvoiceLine.fromJson(Map<String, dynamic> json) => _$InvoiceLineFromJson(json);

@override final  int? id;
@override final  int lineNo;
@override final  int itemId;
@override final  String itemName;
@override final  String? barcode;
@override@DecimalConverter() final  Decimal quantity;
@override@DecimalConverter() final  Decimal unitPrice;
@override@DecimalConverter() final  Decimal taxRate;
@override@DecimalConverter() final  Decimal netAmount;
@override@DecimalConverter() final  Decimal taxAmount;
@override@DecimalConverter() final  Decimal grossAmount;

/// Create a copy of InvoiceLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceLineCopyWith<_InvoiceLine> get copyWith => __$InvoiceLineCopyWithImpl<_InvoiceLine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvoiceLineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceLine&&(identical(other.id, id) || other.id == id)&&(identical(other.lineNo, lineNo) || other.lineNo == lineNo)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.itemName, itemName) || other.itemName == itemName)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.unitPrice, unitPrice) || other.unitPrice == unitPrice)&&(identical(other.taxRate, taxRate) || other.taxRate == taxRate)&&(identical(other.netAmount, netAmount) || other.netAmount == netAmount)&&(identical(other.taxAmount, taxAmount) || other.taxAmount == taxAmount)&&(identical(other.grossAmount, grossAmount) || other.grossAmount == grossAmount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,lineNo,itemId,itemName,barcode,quantity,unitPrice,taxRate,netAmount,taxAmount,grossAmount);

@override
String toString() {
  return 'InvoiceLine(id: $id, lineNo: $lineNo, itemId: $itemId, itemName: $itemName, barcode: $barcode, quantity: $quantity, unitPrice: $unitPrice, taxRate: $taxRate, netAmount: $netAmount, taxAmount: $taxAmount, grossAmount: $grossAmount)';
}


}

/// @nodoc
abstract mixin class _$InvoiceLineCopyWith<$Res> implements $InvoiceLineCopyWith<$Res> {
  factory _$InvoiceLineCopyWith(_InvoiceLine value, $Res Function(_InvoiceLine) _then) = __$InvoiceLineCopyWithImpl;
@override @useResult
$Res call({
 int? id, int lineNo, int itemId, String itemName, String? barcode,@DecimalConverter() Decimal quantity,@DecimalConverter() Decimal unitPrice,@DecimalConverter() Decimal taxRate,@DecimalConverter() Decimal netAmount,@DecimalConverter() Decimal taxAmount,@DecimalConverter() Decimal grossAmount
});




}
/// @nodoc
class __$InvoiceLineCopyWithImpl<$Res>
    implements _$InvoiceLineCopyWith<$Res> {
  __$InvoiceLineCopyWithImpl(this._self, this._then);

  final _InvoiceLine _self;
  final $Res Function(_InvoiceLine) _then;

/// Create a copy of InvoiceLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? lineNo = null,Object? itemId = null,Object? itemName = null,Object? barcode = freezed,Object? quantity = null,Object? unitPrice = null,Object? taxRate = null,Object? netAmount = null,Object? taxAmount = null,Object? grossAmount = null,}) {
  return _then(_InvoiceLine(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,lineNo: null == lineNo ? _self.lineNo : lineNo // ignore: cast_nullable_to_non_nullable
as int,itemId: null == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as int,itemName: null == itemName ? _self.itemName : itemName // ignore: cast_nullable_to_non_nullable
as String,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Decimal,unitPrice: null == unitPrice ? _self.unitPrice : unitPrice // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate: null == taxRate ? _self.taxRate : taxRate // ignore: cast_nullable_to_non_nullable
as Decimal,netAmount: null == netAmount ? _self.netAmount : netAmount // ignore: cast_nullable_to_non_nullable
as Decimal,taxAmount: null == taxAmount ? _self.taxAmount : taxAmount // ignore: cast_nullable_to_non_nullable
as Decimal,grossAmount: null == grossAmount ? _self.grossAmount : grossAmount // ignore: cast_nullable_to_non_nullable
as Decimal,
  ));
}


}


/// @nodoc
mixin _$Invoice {

 int get id; String get invoiceNumber; InvoiceStatus get status; int get version; int get customerId; String get customerName; String get currencyCode; String get currencySymbol; int get currencyMinorUnits;@DecimalConverter() Decimal get exchangeRate; String get baseCurrencyCode; TaxMode get taxMode; DateTime get issueDate; String? get notes;@DecimalConverter() Decimal get subtotal;@DecimalConverter() Decimal get taxTotal;@DecimalConverter() Decimal get grandTotal;@DecimalConverter() Decimal get grandTotalBase; List<InvoiceLine> get lines; String? get createdBy; DateTime? get createdAt; String? get approvedBy; DateTime? get approvedAt; String? get cancelledBy; DateTime? get cancelledAt; String? get cancellationReason; DateTime? get updatedAt;
/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceCopyWith<Invoice> get copyWith => _$InvoiceCopyWithImpl<Invoice>(this as Invoice, _$identity);

  /// Serializes this Invoice to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Invoice&&(identical(other.id, id) || other.id == id)&&(identical(other.invoiceNumber, invoiceNumber) || other.invoiceNumber == invoiceNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.version, version) || other.version == version)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.currencySymbol, currencySymbol) || other.currencySymbol == currencySymbol)&&(identical(other.currencyMinorUnits, currencyMinorUnits) || other.currencyMinorUnits == currencyMinorUnits)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.baseCurrencyCode, baseCurrencyCode) || other.baseCurrencyCode == baseCurrencyCode)&&(identical(other.taxMode, taxMode) || other.taxMode == taxMode)&&(identical(other.issueDate, issueDate) || other.issueDate == issueDate)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.taxTotal, taxTotal) || other.taxTotal == taxTotal)&&(identical(other.grandTotal, grandTotal) || other.grandTotal == grandTotal)&&(identical(other.grandTotalBase, grandTotalBase) || other.grandTotalBase == grandTotalBase)&&const DeepCollectionEquality().equals(other.lines, lines)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.cancelledBy, cancelledBy) || other.cancelledBy == cancelledBy)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.cancellationReason, cancellationReason) || other.cancellationReason == cancellationReason)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,invoiceNumber,status,version,customerId,customerName,currencyCode,currencySymbol,currencyMinorUnits,exchangeRate,baseCurrencyCode,taxMode,issueDate,notes,subtotal,taxTotal,grandTotal,grandTotalBase,const DeepCollectionEquality().hash(lines),createdBy,createdAt,approvedBy,approvedAt,cancelledBy,cancelledAt,cancellationReason,updatedAt]);

@override
String toString() {
  return 'Invoice(id: $id, invoiceNumber: $invoiceNumber, status: $status, version: $version, customerId: $customerId, customerName: $customerName, currencyCode: $currencyCode, currencySymbol: $currencySymbol, currencyMinorUnits: $currencyMinorUnits, exchangeRate: $exchangeRate, baseCurrencyCode: $baseCurrencyCode, taxMode: $taxMode, issueDate: $issueDate, notes: $notes, subtotal: $subtotal, taxTotal: $taxTotal, grandTotal: $grandTotal, grandTotalBase: $grandTotalBase, lines: $lines, createdBy: $createdBy, createdAt: $createdAt, approvedBy: $approvedBy, approvedAt: $approvedAt, cancelledBy: $cancelledBy, cancelledAt: $cancelledAt, cancellationReason: $cancellationReason, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $InvoiceCopyWith<$Res>  {
  factory $InvoiceCopyWith(Invoice value, $Res Function(Invoice) _then) = _$InvoiceCopyWithImpl;
@useResult
$Res call({
 int id, String invoiceNumber, InvoiceStatus status, int version, int customerId, String customerName, String currencyCode, String currencySymbol, int currencyMinorUnits,@DecimalConverter() Decimal exchangeRate, String baseCurrencyCode, TaxMode taxMode, DateTime issueDate, String? notes,@DecimalConverter() Decimal subtotal,@DecimalConverter() Decimal taxTotal,@DecimalConverter() Decimal grandTotal,@DecimalConverter() Decimal grandTotalBase, List<InvoiceLine> lines, String? createdBy, DateTime? createdAt, String? approvedBy, DateTime? approvedAt, String? cancelledBy, DateTime? cancelledAt, String? cancellationReason, DateTime? updatedAt
});




}
/// @nodoc
class _$InvoiceCopyWithImpl<$Res>
    implements $InvoiceCopyWith<$Res> {
  _$InvoiceCopyWithImpl(this._self, this._then);

  final Invoice _self;
  final $Res Function(Invoice) _then;

/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? invoiceNumber = null,Object? status = null,Object? version = null,Object? customerId = null,Object? customerName = null,Object? currencyCode = null,Object? currencySymbol = null,Object? currencyMinorUnits = null,Object? exchangeRate = null,Object? baseCurrencyCode = null,Object? taxMode = null,Object? issueDate = null,Object? notes = freezed,Object? subtotal = null,Object? taxTotal = null,Object? grandTotal = null,Object? grandTotalBase = null,Object? lines = null,Object? createdBy = freezed,Object? createdAt = freezed,Object? approvedBy = freezed,Object? approvedAt = freezed,Object? cancelledBy = freezed,Object? cancelledAt = freezed,Object? cancellationReason = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,invoiceNumber: null == invoiceNumber ? _self.invoiceNumber : invoiceNumber // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as InvoiceStatus,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as int,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,currencySymbol: null == currencySymbol ? _self.currencySymbol : currencySymbol // ignore: cast_nullable_to_non_nullable
as String,currencyMinorUnits: null == currencyMinorUnits ? _self.currencyMinorUnits : currencyMinorUnits // ignore: cast_nullable_to_non_nullable
as int,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as Decimal,baseCurrencyCode: null == baseCurrencyCode ? _self.baseCurrencyCode : baseCurrencyCode // ignore: cast_nullable_to_non_nullable
as String,taxMode: null == taxMode ? _self.taxMode : taxMode // ignore: cast_nullable_to_non_nullable
as TaxMode,issueDate: null == issueDate ? _self.issueDate : issueDate // ignore: cast_nullable_to_non_nullable
as DateTime,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as Decimal,taxTotal: null == taxTotal ? _self.taxTotal : taxTotal // ignore: cast_nullable_to_non_nullable
as Decimal,grandTotal: null == grandTotal ? _self.grandTotal : grandTotal // ignore: cast_nullable_to_non_nullable
as Decimal,grandTotalBase: null == grandTotalBase ? _self.grandTotalBase : grandTotalBase // ignore: cast_nullable_to_non_nullable
as Decimal,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<InvoiceLine>,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledBy: freezed == cancelledBy ? _self.cancelledBy : cancelledBy // ignore: cast_nullable_to_non_nullable
as String?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancellationReason: freezed == cancellationReason ? _self.cancellationReason : cancellationReason // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Invoice].
extension InvoicePatterns on Invoice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Invoice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Invoice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Invoice value)  $default,){
final _that = this;
switch (_that) {
case _Invoice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Invoice value)?  $default,){
final _that = this;
switch (_that) {
case _Invoice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String invoiceNumber,  InvoiceStatus status,  int version,  int customerId,  String customerName,  String currencyCode,  String currencySymbol,  int currencyMinorUnits, @DecimalConverter()  Decimal exchangeRate,  String baseCurrencyCode,  TaxMode taxMode,  DateTime issueDate,  String? notes, @DecimalConverter()  Decimal subtotal, @DecimalConverter()  Decimal taxTotal, @DecimalConverter()  Decimal grandTotal, @DecimalConverter()  Decimal grandTotalBase,  List<InvoiceLine> lines,  String? createdBy,  DateTime? createdAt,  String? approvedBy,  DateTime? approvedAt,  String? cancelledBy,  DateTime? cancelledAt,  String? cancellationReason,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Invoice() when $default != null:
return $default(_that.id,_that.invoiceNumber,_that.status,_that.version,_that.customerId,_that.customerName,_that.currencyCode,_that.currencySymbol,_that.currencyMinorUnits,_that.exchangeRate,_that.baseCurrencyCode,_that.taxMode,_that.issueDate,_that.notes,_that.subtotal,_that.taxTotal,_that.grandTotal,_that.grandTotalBase,_that.lines,_that.createdBy,_that.createdAt,_that.approvedBy,_that.approvedAt,_that.cancelledBy,_that.cancelledAt,_that.cancellationReason,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String invoiceNumber,  InvoiceStatus status,  int version,  int customerId,  String customerName,  String currencyCode,  String currencySymbol,  int currencyMinorUnits, @DecimalConverter()  Decimal exchangeRate,  String baseCurrencyCode,  TaxMode taxMode,  DateTime issueDate,  String? notes, @DecimalConverter()  Decimal subtotal, @DecimalConverter()  Decimal taxTotal, @DecimalConverter()  Decimal grandTotal, @DecimalConverter()  Decimal grandTotalBase,  List<InvoiceLine> lines,  String? createdBy,  DateTime? createdAt,  String? approvedBy,  DateTime? approvedAt,  String? cancelledBy,  DateTime? cancelledAt,  String? cancellationReason,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Invoice():
return $default(_that.id,_that.invoiceNumber,_that.status,_that.version,_that.customerId,_that.customerName,_that.currencyCode,_that.currencySymbol,_that.currencyMinorUnits,_that.exchangeRate,_that.baseCurrencyCode,_that.taxMode,_that.issueDate,_that.notes,_that.subtotal,_that.taxTotal,_that.grandTotal,_that.grandTotalBase,_that.lines,_that.createdBy,_that.createdAt,_that.approvedBy,_that.approvedAt,_that.cancelledBy,_that.cancelledAt,_that.cancellationReason,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String invoiceNumber,  InvoiceStatus status,  int version,  int customerId,  String customerName,  String currencyCode,  String currencySymbol,  int currencyMinorUnits, @DecimalConverter()  Decimal exchangeRate,  String baseCurrencyCode,  TaxMode taxMode,  DateTime issueDate,  String? notes, @DecimalConverter()  Decimal subtotal, @DecimalConverter()  Decimal taxTotal, @DecimalConverter()  Decimal grandTotal, @DecimalConverter()  Decimal grandTotalBase,  List<InvoiceLine> lines,  String? createdBy,  DateTime? createdAt,  String? approvedBy,  DateTime? approvedAt,  String? cancelledBy,  DateTime? cancelledAt,  String? cancellationReason,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Invoice() when $default != null:
return $default(_that.id,_that.invoiceNumber,_that.status,_that.version,_that.customerId,_that.customerName,_that.currencyCode,_that.currencySymbol,_that.currencyMinorUnits,_that.exchangeRate,_that.baseCurrencyCode,_that.taxMode,_that.issueDate,_that.notes,_that.subtotal,_that.taxTotal,_that.grandTotal,_that.grandTotalBase,_that.lines,_that.createdBy,_that.createdAt,_that.approvedBy,_that.approvedAt,_that.cancelledBy,_that.cancelledAt,_that.cancellationReason,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Invoice extends Invoice {
  const _Invoice({required this.id, required this.invoiceNumber, required this.status, required this.version, required this.customerId, required this.customerName, required this.currencyCode, required this.currencySymbol, required this.currencyMinorUnits, @DecimalConverter() required this.exchangeRate, required this.baseCurrencyCode, required this.taxMode, required this.issueDate, this.notes, @DecimalConverter() required this.subtotal, @DecimalConverter() required this.taxTotal, @DecimalConverter() required this.grandTotal, @DecimalConverter() required this.grandTotalBase, final  List<InvoiceLine> lines = const <InvoiceLine>[], this.createdBy, this.createdAt, this.approvedBy, this.approvedAt, this.cancelledBy, this.cancelledAt, this.cancellationReason, this.updatedAt}): _lines = lines,super._();
  factory _Invoice.fromJson(Map<String, dynamic> json) => _$InvoiceFromJson(json);

@override final  int id;
@override final  String invoiceNumber;
@override final  InvoiceStatus status;
@override final  int version;
@override final  int customerId;
@override final  String customerName;
@override final  String currencyCode;
@override final  String currencySymbol;
@override final  int currencyMinorUnits;
@override@DecimalConverter() final  Decimal exchangeRate;
@override final  String baseCurrencyCode;
@override final  TaxMode taxMode;
@override final  DateTime issueDate;
@override final  String? notes;
@override@DecimalConverter() final  Decimal subtotal;
@override@DecimalConverter() final  Decimal taxTotal;
@override@DecimalConverter() final  Decimal grandTotal;
@override@DecimalConverter() final  Decimal grandTotalBase;
 final  List<InvoiceLine> _lines;
@override@JsonKey() List<InvoiceLine> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

@override final  String? createdBy;
@override final  DateTime? createdAt;
@override final  String? approvedBy;
@override final  DateTime? approvedAt;
@override final  String? cancelledBy;
@override final  DateTime? cancelledAt;
@override final  String? cancellationReason;
@override final  DateTime? updatedAt;

/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceCopyWith<_Invoice> get copyWith => __$InvoiceCopyWithImpl<_Invoice>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvoiceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Invoice&&(identical(other.id, id) || other.id == id)&&(identical(other.invoiceNumber, invoiceNumber) || other.invoiceNumber == invoiceNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.version, version) || other.version == version)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.currencySymbol, currencySymbol) || other.currencySymbol == currencySymbol)&&(identical(other.currencyMinorUnits, currencyMinorUnits) || other.currencyMinorUnits == currencyMinorUnits)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.baseCurrencyCode, baseCurrencyCode) || other.baseCurrencyCode == baseCurrencyCode)&&(identical(other.taxMode, taxMode) || other.taxMode == taxMode)&&(identical(other.issueDate, issueDate) || other.issueDate == issueDate)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal)&&(identical(other.taxTotal, taxTotal) || other.taxTotal == taxTotal)&&(identical(other.grandTotal, grandTotal) || other.grandTotal == grandTotal)&&(identical(other.grandTotalBase, grandTotalBase) || other.grandTotalBase == grandTotalBase)&&const DeepCollectionEquality().equals(other._lines, _lines)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.approvedBy, approvedBy) || other.approvedBy == approvedBy)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.cancelledBy, cancelledBy) || other.cancelledBy == cancelledBy)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.cancellationReason, cancellationReason) || other.cancellationReason == cancellationReason)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,invoiceNumber,status,version,customerId,customerName,currencyCode,currencySymbol,currencyMinorUnits,exchangeRate,baseCurrencyCode,taxMode,issueDate,notes,subtotal,taxTotal,grandTotal,grandTotalBase,const DeepCollectionEquality().hash(_lines),createdBy,createdAt,approvedBy,approvedAt,cancelledBy,cancelledAt,cancellationReason,updatedAt]);

@override
String toString() {
  return 'Invoice(id: $id, invoiceNumber: $invoiceNumber, status: $status, version: $version, customerId: $customerId, customerName: $customerName, currencyCode: $currencyCode, currencySymbol: $currencySymbol, currencyMinorUnits: $currencyMinorUnits, exchangeRate: $exchangeRate, baseCurrencyCode: $baseCurrencyCode, taxMode: $taxMode, issueDate: $issueDate, notes: $notes, subtotal: $subtotal, taxTotal: $taxTotal, grandTotal: $grandTotal, grandTotalBase: $grandTotalBase, lines: $lines, createdBy: $createdBy, createdAt: $createdAt, approvedBy: $approvedBy, approvedAt: $approvedAt, cancelledBy: $cancelledBy, cancelledAt: $cancelledAt, cancellationReason: $cancellationReason, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$InvoiceCopyWith<$Res> implements $InvoiceCopyWith<$Res> {
  factory _$InvoiceCopyWith(_Invoice value, $Res Function(_Invoice) _then) = __$InvoiceCopyWithImpl;
@override @useResult
$Res call({
 int id, String invoiceNumber, InvoiceStatus status, int version, int customerId, String customerName, String currencyCode, String currencySymbol, int currencyMinorUnits,@DecimalConverter() Decimal exchangeRate, String baseCurrencyCode, TaxMode taxMode, DateTime issueDate, String? notes,@DecimalConverter() Decimal subtotal,@DecimalConverter() Decimal taxTotal,@DecimalConverter() Decimal grandTotal,@DecimalConverter() Decimal grandTotalBase, List<InvoiceLine> lines, String? createdBy, DateTime? createdAt, String? approvedBy, DateTime? approvedAt, String? cancelledBy, DateTime? cancelledAt, String? cancellationReason, DateTime? updatedAt
});




}
/// @nodoc
class __$InvoiceCopyWithImpl<$Res>
    implements _$InvoiceCopyWith<$Res> {
  __$InvoiceCopyWithImpl(this._self, this._then);

  final _Invoice _self;
  final $Res Function(_Invoice) _then;

/// Create a copy of Invoice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? invoiceNumber = null,Object? status = null,Object? version = null,Object? customerId = null,Object? customerName = null,Object? currencyCode = null,Object? currencySymbol = null,Object? currencyMinorUnits = null,Object? exchangeRate = null,Object? baseCurrencyCode = null,Object? taxMode = null,Object? issueDate = null,Object? notes = freezed,Object? subtotal = null,Object? taxTotal = null,Object? grandTotal = null,Object? grandTotalBase = null,Object? lines = null,Object? createdBy = freezed,Object? createdAt = freezed,Object? approvedBy = freezed,Object? approvedAt = freezed,Object? cancelledBy = freezed,Object? cancelledAt = freezed,Object? cancellationReason = freezed,Object? updatedAt = freezed,}) {
  return _then(_Invoice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,invoiceNumber: null == invoiceNumber ? _self.invoiceNumber : invoiceNumber // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as InvoiceStatus,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as int,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,currencySymbol: null == currencySymbol ? _self.currencySymbol : currencySymbol // ignore: cast_nullable_to_non_nullable
as String,currencyMinorUnits: null == currencyMinorUnits ? _self.currencyMinorUnits : currencyMinorUnits // ignore: cast_nullable_to_non_nullable
as int,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as Decimal,baseCurrencyCode: null == baseCurrencyCode ? _self.baseCurrencyCode : baseCurrencyCode // ignore: cast_nullable_to_non_nullable
as String,taxMode: null == taxMode ? _self.taxMode : taxMode // ignore: cast_nullable_to_non_nullable
as TaxMode,issueDate: null == issueDate ? _self.issueDate : issueDate // ignore: cast_nullable_to_non_nullable
as DateTime,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as Decimal,taxTotal: null == taxTotal ? _self.taxTotal : taxTotal // ignore: cast_nullable_to_non_nullable
as Decimal,grandTotal: null == grandTotal ? _self.grandTotal : grandTotal // ignore: cast_nullable_to_non_nullable
as Decimal,grandTotalBase: null == grandTotalBase ? _self.grandTotalBase : grandTotalBase // ignore: cast_nullable_to_non_nullable
as Decimal,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<InvoiceLine>,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedBy: freezed == approvedBy ? _self.approvedBy : approvedBy // ignore: cast_nullable_to_non_nullable
as String?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledBy: freezed == cancelledBy ? _self.cancelledBy : cancelledBy // ignore: cast_nullable_to_non_nullable
as String?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancellationReason: freezed == cancellationReason ? _self.cancellationReason : cancellationReason // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$InvoiceSummary {

 int get id; String get invoiceNumber; String get customerName; DateTime get issueDate; String get currencyCode; String get currencySymbol;@DecimalConverter() Decimal get grandTotal;@DecimalConverter() Decimal get grandTotalBase; InvoiceStatus get status;
/// Create a copy of InvoiceSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvoiceSummaryCopyWith<InvoiceSummary> get copyWith => _$InvoiceSummaryCopyWithImpl<InvoiceSummary>(this as InvoiceSummary, _$identity);

  /// Serializes this InvoiceSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvoiceSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.invoiceNumber, invoiceNumber) || other.invoiceNumber == invoiceNumber)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.issueDate, issueDate) || other.issueDate == issueDate)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.currencySymbol, currencySymbol) || other.currencySymbol == currencySymbol)&&(identical(other.grandTotal, grandTotal) || other.grandTotal == grandTotal)&&(identical(other.grandTotalBase, grandTotalBase) || other.grandTotalBase == grandTotalBase)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,invoiceNumber,customerName,issueDate,currencyCode,currencySymbol,grandTotal,grandTotalBase,status);

@override
String toString() {
  return 'InvoiceSummary(id: $id, invoiceNumber: $invoiceNumber, customerName: $customerName, issueDate: $issueDate, currencyCode: $currencyCode, currencySymbol: $currencySymbol, grandTotal: $grandTotal, grandTotalBase: $grandTotalBase, status: $status)';
}


}

/// @nodoc
abstract mixin class $InvoiceSummaryCopyWith<$Res>  {
  factory $InvoiceSummaryCopyWith(InvoiceSummary value, $Res Function(InvoiceSummary) _then) = _$InvoiceSummaryCopyWithImpl;
@useResult
$Res call({
 int id, String invoiceNumber, String customerName, DateTime issueDate, String currencyCode, String currencySymbol,@DecimalConverter() Decimal grandTotal,@DecimalConverter() Decimal grandTotalBase, InvoiceStatus status
});




}
/// @nodoc
class _$InvoiceSummaryCopyWithImpl<$Res>
    implements $InvoiceSummaryCopyWith<$Res> {
  _$InvoiceSummaryCopyWithImpl(this._self, this._then);

  final InvoiceSummary _self;
  final $Res Function(InvoiceSummary) _then;

/// Create a copy of InvoiceSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? invoiceNumber = null,Object? customerName = null,Object? issueDate = null,Object? currencyCode = null,Object? currencySymbol = null,Object? grandTotal = null,Object? grandTotalBase = null,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,invoiceNumber: null == invoiceNumber ? _self.invoiceNumber : invoiceNumber // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,issueDate: null == issueDate ? _self.issueDate : issueDate // ignore: cast_nullable_to_non_nullable
as DateTime,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,currencySymbol: null == currencySymbol ? _self.currencySymbol : currencySymbol // ignore: cast_nullable_to_non_nullable
as String,grandTotal: null == grandTotal ? _self.grandTotal : grandTotal // ignore: cast_nullable_to_non_nullable
as Decimal,grandTotalBase: null == grandTotalBase ? _self.grandTotalBase : grandTotalBase // ignore: cast_nullable_to_non_nullable
as Decimal,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as InvoiceStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [InvoiceSummary].
extension InvoiceSummaryPatterns on InvoiceSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvoiceSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvoiceSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvoiceSummary value)  $default,){
final _that = this;
switch (_that) {
case _InvoiceSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvoiceSummary value)?  $default,){
final _that = this;
switch (_that) {
case _InvoiceSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String invoiceNumber,  String customerName,  DateTime issueDate,  String currencyCode,  String currencySymbol, @DecimalConverter()  Decimal grandTotal, @DecimalConverter()  Decimal grandTotalBase,  InvoiceStatus status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvoiceSummary() when $default != null:
return $default(_that.id,_that.invoiceNumber,_that.customerName,_that.issueDate,_that.currencyCode,_that.currencySymbol,_that.grandTotal,_that.grandTotalBase,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String invoiceNumber,  String customerName,  DateTime issueDate,  String currencyCode,  String currencySymbol, @DecimalConverter()  Decimal grandTotal, @DecimalConverter()  Decimal grandTotalBase,  InvoiceStatus status)  $default,) {final _that = this;
switch (_that) {
case _InvoiceSummary():
return $default(_that.id,_that.invoiceNumber,_that.customerName,_that.issueDate,_that.currencyCode,_that.currencySymbol,_that.grandTotal,_that.grandTotalBase,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String invoiceNumber,  String customerName,  DateTime issueDate,  String currencyCode,  String currencySymbol, @DecimalConverter()  Decimal grandTotal, @DecimalConverter()  Decimal grandTotalBase,  InvoiceStatus status)?  $default,) {final _that = this;
switch (_that) {
case _InvoiceSummary() when $default != null:
return $default(_that.id,_that.invoiceNumber,_that.customerName,_that.issueDate,_that.currencyCode,_that.currencySymbol,_that.grandTotal,_that.grandTotalBase,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InvoiceSummary implements InvoiceSummary {
  const _InvoiceSummary({required this.id, required this.invoiceNumber, required this.customerName, required this.issueDate, required this.currencyCode, required this.currencySymbol, @DecimalConverter() required this.grandTotal, @DecimalConverter() required this.grandTotalBase, required this.status});
  factory _InvoiceSummary.fromJson(Map<String, dynamic> json) => _$InvoiceSummaryFromJson(json);

@override final  int id;
@override final  String invoiceNumber;
@override final  String customerName;
@override final  DateTime issueDate;
@override final  String currencyCode;
@override final  String currencySymbol;
@override@DecimalConverter() final  Decimal grandTotal;
@override@DecimalConverter() final  Decimal grandTotalBase;
@override final  InvoiceStatus status;

/// Create a copy of InvoiceSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvoiceSummaryCopyWith<_InvoiceSummary> get copyWith => __$InvoiceSummaryCopyWithImpl<_InvoiceSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvoiceSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvoiceSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.invoiceNumber, invoiceNumber) || other.invoiceNumber == invoiceNumber)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.issueDate, issueDate) || other.issueDate == issueDate)&&(identical(other.currencyCode, currencyCode) || other.currencyCode == currencyCode)&&(identical(other.currencySymbol, currencySymbol) || other.currencySymbol == currencySymbol)&&(identical(other.grandTotal, grandTotal) || other.grandTotal == grandTotal)&&(identical(other.grandTotalBase, grandTotalBase) || other.grandTotalBase == grandTotalBase)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,invoiceNumber,customerName,issueDate,currencyCode,currencySymbol,grandTotal,grandTotalBase,status);

@override
String toString() {
  return 'InvoiceSummary(id: $id, invoiceNumber: $invoiceNumber, customerName: $customerName, issueDate: $issueDate, currencyCode: $currencyCode, currencySymbol: $currencySymbol, grandTotal: $grandTotal, grandTotalBase: $grandTotalBase, status: $status)';
}


}

/// @nodoc
abstract mixin class _$InvoiceSummaryCopyWith<$Res> implements $InvoiceSummaryCopyWith<$Res> {
  factory _$InvoiceSummaryCopyWith(_InvoiceSummary value, $Res Function(_InvoiceSummary) _then) = __$InvoiceSummaryCopyWithImpl;
@override @useResult
$Res call({
 int id, String invoiceNumber, String customerName, DateTime issueDate, String currencyCode, String currencySymbol,@DecimalConverter() Decimal grandTotal,@DecimalConverter() Decimal grandTotalBase, InvoiceStatus status
});




}
/// @nodoc
class __$InvoiceSummaryCopyWithImpl<$Res>
    implements _$InvoiceSummaryCopyWith<$Res> {
  __$InvoiceSummaryCopyWithImpl(this._self, this._then);

  final _InvoiceSummary _self;
  final $Res Function(_InvoiceSummary) _then;

/// Create a copy of InvoiceSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? invoiceNumber = null,Object? customerName = null,Object? issueDate = null,Object? currencyCode = null,Object? currencySymbol = null,Object? grandTotal = null,Object? grandTotalBase = null,Object? status = null,}) {
  return _then(_InvoiceSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,invoiceNumber: null == invoiceNumber ? _self.invoiceNumber : invoiceNumber // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,issueDate: null == issueDate ? _self.issueDate : issueDate // ignore: cast_nullable_to_non_nullable
as DateTime,currencyCode: null == currencyCode ? _self.currencyCode : currencyCode // ignore: cast_nullable_to_non_nullable
as String,currencySymbol: null == currencySymbol ? _self.currencySymbol : currencySymbol // ignore: cast_nullable_to_non_nullable
as String,grandTotal: null == grandTotal ? _self.grandTotal : grandTotal // ignore: cast_nullable_to_non_nullable
as Decimal,grandTotalBase: null == grandTotalBase ? _self.grandTotalBase : grandTotalBase // ignore: cast_nullable_to_non_nullable
as Decimal,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as InvoiceStatus,
  ));
}


}

// dart format on
