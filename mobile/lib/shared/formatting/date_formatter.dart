import 'package:intl/intl.dart';

/// Renders API timestamps (UTC) in the device's local time.
abstract final class DateFormatter {
  /// `Jul 11, 2026`
  static String date(DateTime value) =>
      DateFormat('MMM d, y').format(value.toLocal());

  /// `Jul 11, 2026 · 14:30`
  static String dateTime(DateTime value) =>
      DateFormat('MMM d, y · HH:mm').format(value.toLocal());
}
