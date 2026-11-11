import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/storage/local_storage.dart';
import 'package:adhan_and_prayer/features/location/domain/entities/location_entities.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_calculation_engine.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/calculation_settings.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/prayer_entities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/core/enums/time_enums.dart';
import 'package:adhan_and_prayer/core/utils/time_formatter.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/services/time_system_resolver.dart';

void main() {
  group('TimeSystemResolver Tests', () {
    test('Automatic mode always returns Duration.zero adjustment', () {
      final winterDate = DateTime(2026, 1, 15, 12, 0);
      final summerDate = DateTime(2026, 7, 15, 12, 0);

      expect(
        TimeSystemResolver.calculateAdjustment(
          mode: TimeSystemMode.automatic,
          date: winterDate,
        ),
        equals(Duration.zero),
      );

      expect(
        TimeSystemResolver.calculateAdjustment(
          mode: TimeSystemMode.automatic,
          date: summerDate,
        ),
        equals(Duration.zero),
      );
    });

    test('DaylightSaving mode handles OS DST state safely', () {
      final testDate = DateTime(2026, 7, 15);
      final isDst = TimeSystemResolver.isSystemObservingDst(testDate);

      final adjustment = TimeSystemResolver.calculateAdjustment(
        mode: TimeSystemMode.daylightSaving,
        date: testDate,
      );

      if (isDst) {
        // Prevents double-offset if OS is already observing DST!
        expect(adjustment, equals(Duration.zero));
      } else {
        // Forces +1 hour if OS is in standard time
        expect(adjustment, equals(const Duration(hours: 1)));
      }
    });

    test('Standard mode handles OS DST state safely', () {
      final testDate = DateTime(2026, 7, 15);
      final isDst = TimeSystemResolver.isSystemObservingDst(testDate);

      final adjustment = TimeSystemResolver.calculateAdjustment(
        mode: TimeSystemMode.standard,
        date: testDate,
      );

      if (isDst) {
        // Reverts +1 hour to return to standard time
        expect(adjustment, equals(const Duration(hours: -1)));
      } else {
        // Stays on standard time
        expect(adjustment, equals(Duration.zero));
      }
    });
  });

  group('AppTimeFormatter Tests', () {
    test('Formats 24-hour clock correctly across edge times', () {
      final morning = DateTime(2026, 9, 11, 4, 30);
      final noon = DateTime(2026, 9, 11, 12, 0);
      final evening = DateTime(2026, 9, 11, 18, 45);
      final midnight = DateTime(2026, 9, 11, 0, 5);

      expect(
        AppTimeFormatter.formatPrayerTime(morning, ClockFormat.twentyFourHour),
        equals('04:30'),
      );
      expect(
        AppTimeFormatter.formatPrayerTime(noon, ClockFormat.twentyFourHour),
        equals('12:00'),
      );
      expect(
        AppTimeFormatter.formatPrayerTime(evening, ClockFormat.twentyFourHour),
        equals('18:45'),
      );
      expect(
        AppTimeFormatter.formatPrayerTime(midnight, ClockFormat.twentyFourHour),
        equals('00:05'),
      );
    });

    test('Formats 12-hour clock in English correctly', () {
      final morning = DateTime(2026, 9, 11, 4, 30);
      final noon = DateTime(2026, 9, 11, 12, 0);
      final evening = DateTime(2026, 9, 11, 18, 45);
      final midnight = DateTime(2026, 9, 11, 0, 5);

      expect(
        AppTimeFormatter.formatPrayerTime(
          morning,
          ClockFormat.twelveHour,
          locale: 'en',
        ),
        equals('4:30 AM'),
      );
      expect(
        AppTimeFormatter.formatPrayerTime(
          noon,
          ClockFormat.twelveHour,
          locale: 'en',
        ),
        equals('12:00 PM'),
      );
      expect(
        AppTimeFormatter.formatPrayerTime(
          evening,
          ClockFormat.twelveHour,
          locale: 'en',
        ),
        equals('6:45 PM'),
      );
      expect(
        AppTimeFormatter.formatPrayerTime(
          midnight,
          ClockFormat.twelveHour,
          locale: 'en',
        ),
        equals('12:05 AM'),
      );
    });

    test('Formats 12-hour clock in Arabic correctly', () {
      final morning = DateTime(2026, 9, 11, 4, 30);
      final evening = DateTime(2026, 9, 11, 18, 45);

      final formattedMorning = AppTimeFormatter.formatPrayerTime(
        morning,
        ClockFormat.twelveHour,
        locale: 'ar',
      );
      final formattedEvening = AppTimeFormatter.formatPrayerTime(
        evening,
        ClockFormat.twelveHour,
        locale: 'ar',
      );

      expect(formattedMorning.contains('ص'), isTrue);
      expect(formattedEvening.contains('م'), isTrue);
    });
  });

  group('PrayerTimesRepository TimeSystemMode Integration Tests', () {
    test(
      'DailyPrayerTimes.applyAdjustment correctly shifts all prayer moments',
      () {
        final baseDate = DateTime(2026, 9, 11);
        final dailyTimes = DailyPrayerTimes(
          date: baseDate,
          fajr: DateTime(2026, 9, 11, 4, 30),
          sunrise: DateTime(2026, 9, 11, 6, 0),
          dhuhr: DateTime(2026, 9, 11, 12, 15),
          asr: DateTime(2026, 9, 11, 15, 45),
          maghrib: DateTime(2026, 9, 11, 18, 20),
          isha: DateTime(2026, 9, 11, 19, 45),
        );

        final adjustedPlusOneHour = dailyTimes.applyAdjustment(
          const Duration(hours: 1),
        );
        expect(adjustedPlusOneHour.fajr, equals(DateTime(2026, 9, 11, 5, 30)));
        expect(
          adjustedPlusOneHour.sunrise,
          equals(DateTime(2026, 9, 11, 7, 0)),
        );
        expect(
          adjustedPlusOneHour.dhuhr,
          equals(DateTime(2026, 9, 11, 13, 15)),
        );
        expect(adjustedPlusOneHour.asr, equals(DateTime(2026, 9, 11, 16, 45)));
        expect(
          adjustedPlusOneHour.maghrib,
          equals(DateTime(2026, 9, 11, 19, 20)),
        );
        expect(adjustedPlusOneHour.isha, equals(DateTime(2026, 9, 11, 20, 45)));

        final adjustedZero = dailyTimes.applyAdjustment(Duration.zero);
        expect(identical(adjustedZero, dailyTimes), isTrue);
      },
    );

    test('PrayerTimesRepositoryImpl respects TimeSystemMode and invalidates cache on mode change', () async {
      final storage = _MockLocalStorage();
      final engine = AdhanPrayerCalculationEngine();
      final repo = PrayerTimesRepositoryImpl(engine: engine, storage: storage);

      const city = City(
        id: 'eg_cairo',
        countryCode: 'EG',
        nameAr: 'القاهرة',
        nameEn: 'Cairo',
        latitude: 30.0444,
        longitude: 31.2357,
        timezone: 'Africa/Cairo',
      );

      final testDate = DateTime(2026, 9, 11);
      const settings = CalculationSettings();

      // Default should be automatic
      expect(await repo.getTimeSystemMode(), equals(TimeSystemMode.automatic));

      final autoResult = await repo.getPrayerTimes(
        city: city,
        date: testDate,
        settings: settings,
      );
      expect(autoResult, isA<Success<DailyPrayerTimes>>());
      final autoTimes = (autoResult as Success<DailyPrayerTimes>).data;

      // Save mode daylightSaving
      await repo.saveTimeSystemMode(TimeSystemMode.daylightSaving);
      expect(
        await repo.getTimeSystemMode(),
        equals(TimeSystemMode.daylightSaving),
      );

      final dstResult = await repo.getPrayerTimes(
        city: city,
        date: testDate,
        settings: settings,
      );
      expect(dstResult, isA<Success<DailyPrayerTimes>>());
      final dstTimes = (dstResult as Success<DailyPrayerTimes>).data;

      // In daylightSaving, if system is not in DST it adds 1 hour, otherwise 0
      final isDst = TimeSystemResolver.isSystemObservingDst(testDate);
      if (isDst) {
        expect(dstTimes.dhuhr, equals(autoTimes.dhuhr));
      } else {
        expect(
          dstTimes.dhuhr.difference(autoTimes.dhuhr),
          equals(const Duration(hours: 1)),
        );
      }
    });
  });
}

class _MockLocalStorage implements LocalStorage {
  final Map<String, dynamic> _data = {};

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  int? getInt(String key) => _data[key] as int?;

  @override
  Future<bool> setInt(String key, int value) async {
    _data[key] = value;
    return true;
  }

  @override
  double? getDouble(String key) => _data[key] as double?;

  @override
  Future<bool> setDouble(String key, double value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }
}
