import 'package:intl/intl.dart';

/// Formats the API's decimal-string money values for display.
///
/// Layout only — no arithmetic ever happens on parsed doubles. Localised
/// number formats land with the i18n milestone (M11).
abstract final class PriceFormatter {
  static const Map<String, String> _symbols = <String, String>{
    'TRY': '₺',
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
  };

  static String format(String amount, String currency) {
    final double? value = double.tryParse(amount);
    // An unparseable amount is a server bug; showing it raw beats crashing.
    if (value == null) return amount;

    final String? symbol = _symbols[currency];
    if (symbol == null) {
      final String number = NumberFormat.currency(
        symbol: '',
        decimalDigits: 2,
      ).format(value).trim();
      return '$number $currency';
    }
    return NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    ).format(value);
  }
}
