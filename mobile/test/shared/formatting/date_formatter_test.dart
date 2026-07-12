import 'package:ecommerce_app/shared/formatting/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // The English symbols are built into intl; every other locale's must be
  // loaded first (the app's localizations delegate does this at runtime).
  setUpAll(() => initializeDateFormatting('tr'));

  // Local DateTimes keep the assertions independent of the machine's zone
  // (toLocal() is the identity for them).
  test('date renders the day only', () {
    expect(
      DateFormatter.date(DateTime(2026, 7, 11, 14, 30), 'en'),
      'Jul 11, 2026',
    );
  });

  test('dateTime renders the day and the 24h time', () {
    expect(
      DateFormatter.dateTime(DateTime(2026, 7, 11, 14, 30), 'en'),
      'Jul 11, 2026 14:30',
    );
  });

  test('the skeleton reorders the fields per locale', () {
    expect(
      DateFormatter.date(DateTime(2026, 7, 11, 14, 30), 'tr'),
      '11 Tem 2026',
    );
  });
}
