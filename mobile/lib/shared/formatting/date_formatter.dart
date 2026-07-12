import 'package:intl/intl.dart';

/// Renders API timestamps (UTC) in the device's local time.
///
/// [locale] is the BCP 47 tag to format for — pass
/// `context.l10n.localeName`, which is guaranteed to have its date symbols
/// loaded by the localizations delegate. The skeleton formats reorder the
/// fields per locale (`Jul 11, 2026` in en, `11 Tem 2026` in tr).
abstract final class DateFormatter {
  /// `Jul 11, 2026`
  static String date(DateTime value, String locale) =>
      DateFormat.yMMMd(locale).format(value.toLocal());

  /// `Jul 11, 2026 14:30`
  static String dateTime(DateTime value, String locale) =>
      DateFormat.yMMMd(locale).add_Hm().format(value.toLocal());
}
