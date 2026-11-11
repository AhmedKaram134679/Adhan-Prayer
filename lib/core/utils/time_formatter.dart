import 'package:adhan_and_prayer/core/enums/time_enums.dart';

class AppTimeFormatter {
  const AppTimeFormatter._();

  /// Formats a prayer time according to the selected [ClockFormat] and [locale].
  ///
  /// - [ClockFormat.twentyFourHour]: e.g. "18:30" (HH:mm)
  /// - [ClockFormat.twelveHour]: e.g. "6:30 PM" (h:mm a) or "6:30 م" in Arabic
  static String formatPrayerTime(
    DateTime time,
    ClockFormat format, {
    String? locale,
  }) {
    if (format == ClockFormat.twentyFourHour) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else {
      final isPm = time.hour >= 12;
      final rawHour = time.hour % 12;
      final hour12 = rawHour == 0 ? 12 : rawHour;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = locale == 'ar'
          ? (isPm ? 'م' : 'ص')
          : (isPm ? 'PM' : 'AM');
      return '$hour12:$minute $period';
    }
  }
}
