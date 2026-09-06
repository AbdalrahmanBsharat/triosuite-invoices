import 'package:freezed_annotation/freezed_annotation.dart';

part 'customer.freezed.dart';
part 'customer.g.dart';

/// A party an invoice is billed to.
@freezed
abstract class Customer with _$Customer {
  const factory Customer({
    required int id,
    required String name,
    String? email,
    String? phone,
    String? address,
    @Default(true) bool active,
  }) = _Customer;

  factory Customer.fromJson(Map<String, dynamic> json) => _$CustomerFromJson(json);
}
