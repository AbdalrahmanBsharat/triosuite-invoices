import 'package:json_annotation/json_annotation.dart';

/// How a line's unit price relates to tax. Chosen per invoice and applied to every line on it.
///
/// The `@JsonValue`s match the server's enum exactly, so nothing has to translate between the two.
enum TaxMode {
  /// The unit price is net; tax is added on top.
  @JsonValue('EXCLUSIVE')
  exclusive('EXCLUSIVE', 'Exclusive'),

  /// The unit price already contains the tax; the net amount is extracted from it.
  @JsonValue('INCLUSIVE')
  inclusive('INCLUSIVE', 'Inclusive');

  const TaxMode(this.wireName, this.label);

  /// The value sent to and received from the API.
  final String wireName;

  /// The label shown on the tax-mode selector.
  final String label;

  /// A one-line explanation of what the mode means, shown under the selector so the choice is
  /// not a guess.
  String get description => switch (this) {
        TaxMode.exclusive => 'Unit prices are net. Tax is added on top.',
        TaxMode.inclusive => 'Unit prices already include tax. Net is extracted from them.',
      };

  static TaxMode fromWire(String wireName) => TaxMode.values.firstWhere(
        (mode) => mode.wireName == wireName,
        orElse: () => TaxMode.exclusive,
      );
}
