import 'package:adhan_and_prayer/core/enums/time_enums.dart';

class TimeSystemResolver {
  const TimeSystemResolver._();

  /// Determines whether the local host operating system is currently observing
  /// Daylight Saving Time on [date].
  ///
  /// Compares the timezone offset of [date] with the baseline standard-time offset
  /// in January (for the Northern Hemisphere) or July (for the Southern Hemisphere).
  static bool isSystemObservingDst(DateTime date) {
    final janOffset = DateTime(date.year, 1, 15).timeZoneOffset;
    final julOffset = DateTime(date.year, 7, 15).timeZoneOffset;

    // In Northern Hemisphere, DST offset > Jan offset.
    // In Southern Hemisphere, DST offset > Jul offset.
    final standardOffset = janOffset <= julOffset ? janOffset : julOffset;
    return date.timeZoneOffset > standardOffset;
  }

  /// Calculates the compensatory offset to apply to prayer times based on [mode] and [date].
  ///
  /// - [TimeSystemMode.automatic]: Trusts device/OS wall-clock time completely (returns Duration.zero).
  /// - [TimeSystemMode.daylightSaving]: Forces summer time (+1 hr vs standard).
  ///   If the OS is already observing DST, returns Duration.zero to prevent double-offsetting.
  ///   If the OS is in standard time, adds Duration(hours: 1).
  /// - [TimeSystemMode.standard]: Forces standard winter time (no DST).
  ///   If the OS is observing DST, subtracts Duration(hours: 1) to revert to standard time.
  ///   If the OS is already in standard time, returns Duration.zero.
  static Duration calculateAdjustment({
    required TimeSystemMode mode,
    required DateTime date,
  }) {
    switch (mode) {
      case TimeSystemMode.automatic:
        return Duration.zero;

      case TimeSystemMode.daylightSaving:
        return isSystemObservingDst(date) ? Duration.zero : const Duration(hours: 1);

      case TimeSystemMode.standard:
        return isSystemObservingDst(date) ? const Duration(hours: -1) : Duration.zero;
    }
  }
}
