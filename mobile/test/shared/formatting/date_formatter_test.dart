import 'package:ecommerce_app/shared/formatting/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Local DateTimes keep the assertions independent of the machine's zone
  // (toLocal() is the identity for them).
  test('date renders the day only', () {
    expect(DateFormatter.date(DateTime(2026, 7, 11, 14, 30)), 'Jul 11, 2026');
  });

  test('dateTime renders the day and the 24h time', () {
    expect(
      DateFormatter.dateTime(DateTime(2026, 7, 11, 14, 30)),
      'Jul 11, 2026 · 14:30',
    );
  });
}
