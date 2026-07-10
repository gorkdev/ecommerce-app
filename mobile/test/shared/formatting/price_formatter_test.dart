import 'package:ecommerce_app/shared/formatting/price_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats known currencies with their symbol', () {
    expect(PriceFormatter.format('1299.99', 'TRY'), '₺1,299.99');
    expect(PriceFormatter.format('5', 'USD'), r'$5.00');
    expect(PriceFormatter.format('19.9', 'EUR'), '€19.90');
  });

  test('falls back to an amount-plus-code layout for unknown currencies', () {
    expect(PriceFormatter.format('129.99', 'SEK'), '129.99 SEK');
  });

  test('shows an unparseable amount raw instead of crashing', () {
    expect(PriceFormatter.format('not-a-number', 'TRY'), 'not-a-number');
  });
}
