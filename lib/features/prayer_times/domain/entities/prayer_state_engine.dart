import 'package:adhan_and_prayer/features/prayer_times/domain/entities/prayer_entities.dart';

class PrayerStateEngine {
  /// Resolves the current prayer and next prayer given daily prayer times and reference time
  static PrayerStateResult resolvePrayerState({
    required DailyPrayerTimes todayTimes,
    required DailyPrayerTimes tomorrowTimes,
    required DateTime now,
  }) {
    final list = todayTimes.toList();

    // Check before today's Fajr
    if (now.isBefore(todayTimes.fajr)) {
      return PrayerStateResult(
        currentPrayer: null, // Still in pre-dawn of current date
        nextPrayer: list.firstWhere((p) => p.type == PrayerType.fajr),
        nextPrayerTime: todayTimes.fajr,
      );
    }

    // Between Fajr and Sunrise
    if (now.isBefore(todayTimes.sunrise)) {
      return PrayerStateResult(
        currentPrayer: list.firstWhere((p) => p.type == PrayerType.fajr),
        nextPrayer: list.firstWhere((p) => p.type == PrayerType.dhuhr), // Next obligatory prayer
        nextPrayerTime: todayTimes.dhuhr,
      );
    }

    // Between Sunrise and Dhuhr
    if (now.isBefore(todayTimes.dhuhr)) {
      return PrayerStateResult(
        currentPrayer: null,
        nextPrayer: list.firstWhere((p) => p.type == PrayerType.dhuhr),
        nextPrayerTime: todayTimes.dhuhr,
      );
    }

    // Between Dhuhr and Asr
    if (now.isBefore(todayTimes.asr)) {
      return PrayerStateResult(
        currentPrayer: list.firstWhere((p) => p.type == PrayerType.dhuhr),
        nextPrayer: list.firstWhere((p) => p.type == PrayerType.asr),
        nextPrayerTime: todayTimes.asr,
      );
    }

    // Between Asr and Maghrib
    if (now.isBefore(todayTimes.maghrib)) {
      return PrayerStateResult(
        currentPrayer: list.firstWhere((p) => p.type == PrayerType.asr),
        nextPrayer: list.firstWhere((p) => p.type == PrayerType.maghrib),
        nextPrayerTime: todayTimes.maghrib,
      );
    }

    // Between Maghrib and Isha
    if (now.isBefore(todayTimes.isha)) {
      return PrayerStateResult(
        currentPrayer: list.firstWhere((p) => p.type == PrayerType.maghrib),
        nextPrayer: list.firstWhere((p) => p.type == PrayerType.isha),
        nextPrayerTime: todayTimes.isha,
      );
    }

    // After Isha -> next prayer is tomorrow's Fajr
    final tomorrowFajr = tomorrowTimes.toList().firstWhere((p) => p.type == PrayerType.fajr);
    return PrayerStateResult(
      currentPrayer: list.firstWhere((p) => p.type == PrayerType.isha),
      nextPrayer: tomorrowFajr,
      nextPrayerTime: tomorrowTimes.fajr,
    );
  }
}

class PrayerStateResult {
  final PrayerItem? currentPrayer;
  final PrayerItem nextPrayer;
  final DateTime nextPrayerTime;

  const PrayerStateResult({
    required this.currentPrayer,
    required this.nextPrayer,
    required this.nextPrayerTime,
  });
}
