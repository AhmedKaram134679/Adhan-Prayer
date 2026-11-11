import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/features/location/data/models/static_location_data.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_calculation_engine.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/calculation_settings.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/prayer_entities.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/prayer_state_engine.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/countdown_time.dart';

void main() {
  group('Prayer Calculation Tests (Multi-City Matrix)', () {
    final engine = AdhanPrayerCalculationEngine();
    final testDate = DateTime(2026, 9, 5);

    test('Cairo calculation produces strictly chronological prayer times', () {
      final cairo = StaticLocationData.cities.firstWhere((c) => c.id == 'eg_cairo');
      final result = engine.calculatePrayerTimes(
        city: cairo,
        date: testDate,
        settings: const CalculationSettings(method: CalculationMethodType.egyptian),
      );

      expect(result, isA<Success<DailyPrayerTimes>>());
      final times = (result as Success<DailyPrayerTimes>).data;

      expect(times.fajr.isBefore(times.sunrise), isTrue);
      expect(times.sunrise.isBefore(times.dhuhr), isTrue);
      expect(times.dhuhr.isBefore(times.asr), isTrue);
      expect(times.asr.isBefore(times.maghrib), isTrue);
      expect(times.maghrib.isBefore(times.isha), isTrue);
    });

    test('Makkah calculation with Umm Al Qura method', () {
      final makkah = StaticLocationData.cities.firstWhere((c) => c.id == 'sa_makkah');
      final result = engine.calculatePrayerTimes(
        city: makkah,
        date: testDate,
        settings: const CalculationSettings(method: CalculationMethodType.ummAlQura),
      );

      expect(result, isA<Success<DailyPrayerTimes>>());
      final times = (result as Success<DailyPrayerTimes>).data;
      expect(times.fajr.hour, inInclusiveRange(4, 5));
      expect(times.maghrib.hour, inInclusiveRange(18, 19));
    });

    test('London calculation with Muslim World League method', () {
      final london = StaticLocationData.cities.firstWhere((c) => c.id == 'gb_london');
      final result = engine.calculatePrayerTimes(
        city: london,
        date: testDate,
        settings: const CalculationSettings(method: CalculationMethodType.muslimWorldLeague),
      );

      expect(result, isA<Success<DailyPrayerTimes>>());
    });

    test('Alexandria, Egypt prayer calculation with Egyptian General Authority', () {
      final alex = StaticLocationData.cities.firstWhere((c) => c.id == 'eg_alex');
      final result = engine.calculatePrayerTimes(
        city: alex,
        date: testDate,
        settings: const CalculationSettings(method: CalculationMethodType.egyptian, madhab: MadhabType.shafi),
      );

      expect(result, isA<Success<DailyPrayerTimes>>());
      final times = (result as Success<DailyPrayerTimes>).data;
      // ignore: avoid_print
      print('Alexandria 2026-09-05 Times: Fajr=${times.fajr}, Sunrise=${times.sunrise}, Dhuhr=${times.dhuhr}, Asr=${times.asr}, Maghrib=${times.maghrib}, Isha=${times.isha}');

      // Chronological order verification
      expect(times.fajr.isBefore(times.sunrise), isTrue);
      expect(times.sunrise.isBefore(times.dhuhr), isTrue);
      expect(times.dhuhr.isBefore(times.asr), isTrue);
      expect(times.asr.isBefore(times.maghrib), isTrue);
      expect(times.maghrib.isBefore(times.isha), isTrue);

      expect(times.fajr.hour, inInclusiveRange(4, 5));
      expect(times.dhuhr.hour, inInclusiveRange(11, 13));
      expect(times.maghrib.hour, inInclusiveRange(18, 19));
    });

    test('Madinah, Saudi Arabia prayer calculation with Umm Al-Qura University', () {
      final madinah = StaticLocationData.cities.firstWhere((c) => c.id == 'sa_madinah');
      final result = engine.calculatePrayerTimes(
        city: madinah,
        date: testDate,
        settings: const CalculationSettings(method: CalculationMethodType.ummAlQura, madhab: MadhabType.shafi),
      );

      expect(result, isA<Success<DailyPrayerTimes>>());
      final times = (result as Success<DailyPrayerTimes>).data;
      // ignore: avoid_print
      print('Madinah 2026-09-05 Times: Fajr=${times.fajr}, Sunrise=${times.sunrise}, Dhuhr=${times.dhuhr}, Asr=${times.asr}, Maghrib=${times.maghrib}, Isha=${times.isha}');
      expect(times.fajr.hour, inInclusiveRange(4, 5));
      expect(times.dhuhr.hour, inInclusiveRange(12, 13));
      expect(times.maghrib.hour, inInclusiveRange(18, 19));
    });

    test('Karachi, Pakistan prayer calculation with Karachi University & Hanafi Madhab', () {
      final karachi = StaticLocationData.cities.firstWhere((c) => c.id == 'pk_karachi');
      final result = engine.calculatePrayerTimes(
        city: karachi,
        date: testDate,
        settings: const CalculationSettings(method: CalculationMethodType.karachi, madhab: MadhabType.hanafi),
      );

      expect(result, isA<Success<DailyPrayerTimes>>());
      final times = (result as Success<DailyPrayerTimes>).data;
      // ignore: avoid_print
      print('Karachi 2026-09-05 Times (Hanafi): Fajr=${times.fajr}, Sunrise=${times.sunrise}, Dhuhr=${times.dhuhr}, Asr=${times.asr}, Maghrib=${times.maghrib}, Isha=${times.isha}');
      expect(times.fajr.isBefore(times.sunrise), isTrue);
      expect(times.sunrise.isBefore(times.dhuhr), isTrue);
      expect(times.dhuhr.isBefore(times.asr), isTrue);
      expect(times.asr.isBefore(times.maghrib), isTrue);
      expect(times.maghrib.isBefore(times.isha), isTrue);
    });

    test('Hanafi vs Shafi Asr calculation comparison', () {
      final karachi = StaticLocationData.cities.firstWhere((c) => c.id == 'pk_karachi');
      final shafiResult = engine.calculatePrayerTimes(
        city: karachi,
        date: testDate,
        settings: const CalculationSettings(
          method: CalculationMethodType.karachi,
          madhab: MadhabType.shafi,
        ),
      );
      final hanafiResult = engine.calculatePrayerTimes(
        city: karachi,
        date: testDate,
        settings: const CalculationSettings(
          method: CalculationMethodType.karachi,
          madhab: MadhabType.hanafi,
        ),
      );

      final shafiTimes = (shafiResult as Success<DailyPrayerTimes>).data;
      final hanafiTimes = (hanafiResult as Success<DailyPrayerTimes>).data;

      // Hanafi Asr is when shadow is twice the length, so it is strictly later than Shafi Asr
      expect(hanafiTimes.asr.isAfter(shafiTimes.asr), isTrue);
    });
  });

  group('Prayer State Engine & Transitions', () {
    final todayTimes = DailyPrayerTimes(
      date: DateTime(2026, 9, 5),
      fajr: DateTime(2026, 9, 5, 4, 30),
      sunrise: DateTime(2026, 9, 5, 5, 50),
      dhuhr: DateTime(2026, 9, 5, 12, 10),
      asr: DateTime(2026, 9, 5, 15, 40),
      maghrib: DateTime(2026, 9, 5, 18, 20),
      isha: DateTime(2026, 9, 5, 19, 45),
    );

    final tomorrowTimes = DailyPrayerTimes(
      date: DateTime(2026, 9, 6),
      fajr: DateTime(2026, 9, 6, 4, 31),
      sunrise: DateTime(2026, 9, 6, 5, 51),
      dhuhr: DateTime(2026, 9, 6, 12, 10),
      asr: DateTime(2026, 9, 6, 15, 39),
      maghrib: DateTime(2026, 9, 6, 18, 19),
      isha: DateTime(2026, 9, 6, 19, 44),
    );

    test('Before Fajr: Next is Fajr', () {
      final now = DateTime(2026, 9, 5, 3, 0);
      final res = PrayerStateEngine.resolvePrayerState(
        todayTimes: todayTimes,
        tomorrowTimes: tomorrowTimes,
        now: now,
      );

      expect(res.currentPrayer, isNull);
      expect(res.nextPrayer.type, equals(PrayerType.fajr));
      expect(res.nextPrayerTime, equals(todayTimes.fajr));
    });

    test('Between Fajr and Sunrise: Next obligatory is Dhuhr', () {
      final now = DateTime(2026, 9, 5, 5, 0);
      final res = PrayerStateEngine.resolvePrayerState(
        todayTimes: todayTimes,
        tomorrowTimes: tomorrowTimes,
        now: now,
      );

      expect(res.currentPrayer?.type, equals(PrayerType.fajr));
      expect(res.nextPrayer.type, equals(PrayerType.dhuhr));
    });

    test('After Isha: Next is tomorrow Fajr across midnight boundary', () {
      final now = DateTime(2026, 9, 5, 22, 30);
      final res = PrayerStateEngine.resolvePrayerState(
        todayTimes: todayTimes,
        tomorrowTimes: tomorrowTimes,
        now: now,
      );

      expect(res.currentPrayer?.type, equals(PrayerType.isha));
      expect(res.nextPrayer.type, equals(PrayerType.fajr));
      expect(res.nextPrayerTime, equals(tomorrowTimes.fajr));
    });
  });

  group('Countdown Formatting Tests', () {
    test('Calculates and formats remaining hours, minutes, seconds correctly', () {
      const duration = Duration(hours: 3, minutes: 25, seconds: 40);
      final countdown = CountdownTime.fromDuration(duration);

      expect(countdown.hours, equals(3));
      expect(countdown.minutes, equals(25));
      expect(countdown.seconds, equals(40));
      expect(countdown.isDue, isFalse);
      expect(countdown.formatFormatted(), equals('03:25:40'));
    });

    test('Handles negative/due duration gracefully without becoming negative', () {
      const duration = Duration(seconds: -10);
      final countdown = CountdownTime.fromDuration(duration);

      expect(countdown.hours, equals(0));
      expect(countdown.minutes, equals(0));
      expect(countdown.seconds, equals(0));
      expect(countdown.isDue, isTrue);
      expect(countdown.formatFormatted(), equals('00:00:00'));
    });
  });
}
