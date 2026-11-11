import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/storage/local_storage.dart';
import 'package:adhan_and_prayer/features/location/data/models/static_location_data.dart';
import 'package:adhan_and_prayer/features/location/data/repositories/location_repository_impl.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_calculation_engine.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/calculation_settings.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/prayer_entities.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/services/location_calculation_method_resolver.dart';

class InMemoryLocalStorage implements LocalStorage {
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

void main() {
  group('End-to-End Automatic vs Manual Calculation Flow Tests', () {
    late InMemoryLocalStorage storage;
    late LocationRepository locationRepo;
    late PrayerTimesRepository prayerRepo;

    final egypt = StaticLocationData.countries.firstWhere((c) => c.code == 'EG');
    final cairo = StaticLocationData.cities.firstWhere((c) => c.id == 'eg_cairo');
    final saudi = StaticLocationData.countries.firstWhere((c) => c.code == 'SA');
    final makkah = StaticLocationData.cities.firstWhere((c) => c.id == 'sa_makkah');
    final uk = StaticLocationData.countries.firstWhere((c) => c.code == 'GB');
    final london = StaticLocationData.cities.firstWhere((c) => c.id == 'gb_london');

    setUp(() {
      storage = InMemoryLocalStorage();
      locationRepo = LocationRepositoryImpl(storage);
      prayerRepo = PrayerTimesRepositoryImpl(
        engine: AdhanPrayerCalculationEngine(),
        storage: storage,
      );
    });

    test('Automatic Mode: Changing Location automatically updates recommended calculation method', () async {
      // 1. Initial setup: Cairo, Egypt in Automatic mode
      await locationRepo.saveLocation(egypt, cairo);
      await prayerRepo.saveCalculationSettings(
        const CalculationSettings(mode: CalculationMethodMode.automatic, method: CalculationMethodType.egyptian),
      );

      var settings = await prayerRepo.getCalculationSettings();
      expect(settings.mode, equals(CalculationMethodMode.automatic));
      expect(settings.method, equals(CalculationMethodType.egyptian));

      // 2. User moves to Makkah, Saudi Arabia
      await locationRepo.saveLocation(saudi, makkah);
      final currentCountry = (await locationRepo.getSelectedCountry())!;
      final currentCity = (await locationRepo.getSelectedCity())!;

      if (settings.mode == CalculationMethodMode.automatic) {
        final autoMethod = LocationCalculationMethodResolver.resolve(
          country: currentCountry,
          city: currentCity,
        );
        settings = settings.copyWith(method: autoMethod);
        await prayerRepo.saveCalculationSettings(settings);
      }

      // Verify Makkah resolves to Umm Al Qura
      final updatedSettings = await prayerRepo.getCalculationSettings();
      expect(updatedSettings.mode, equals(CalculationMethodMode.automatic));
      expect(updatedSettings.method, equals(CalculationMethodType.ummAlQura));

      // 3. User moves to London, UK
      await locationRepo.saveLocation(uk, london);
      final ukCountry = (await locationRepo.getSelectedCountry())!;
      final ukCity = (await locationRepo.getSelectedCity())!;

      if (updatedSettings.mode == CalculationMethodMode.automatic) {
        final autoMethod = LocationCalculationMethodResolver.resolve(
          country: ukCountry,
          city: ukCity,
        );
        await prayerRepo.saveCalculationSettings(updatedSettings.copyWith(method: autoMethod));
      }

      final londonSettings = await prayerRepo.getCalculationSettings();
      expect(londonSettings.mode, equals(CalculationMethodMode.automatic));
      expect(londonSettings.method, equals(CalculationMethodType.muslimWorldLeague));
    });

    test('Manual Mode: Location changes MUST NOT overwrite user manually selected method', () async {
      // 1. Setup: User explicitly chooses Egyptian method in Manual Mode
      await locationRepo.saveLocation(egypt, cairo);
      await prayerRepo.saveCalculationSettings(
        const CalculationSettings(
          mode: CalculationMethodMode.manual,
          method: CalculationMethodType.egyptian,
        ),
      );

      var settings = await prayerRepo.getCalculationSettings();
      expect(settings.mode, equals(CalculationMethodMode.manual));
      expect(settings.method, equals(CalculationMethodType.egyptian));

      // 2. User travels to Makkah, Saudi Arabia
      await locationRepo.saveLocation(saudi, makkah);
      final currentCountry = (await locationRepo.getSelectedCountry())!;
      final currentCity = (await locationRepo.getSelectedCity())!;

      // In manual mode, auto-resolver MUST NOT be applied to override method
      if (settings.mode == CalculationMethodMode.automatic) {
        final autoMethod = LocationCalculationMethodResolver.resolve(
          country: currentCountry,
          city: currentCity,
        );
        settings = settings.copyWith(method: autoMethod);
        await prayerRepo.saveCalculationSettings(settings);
      }

      final postMoveSettings = await prayerRepo.getCalculationSettings();
      expect(postMoveSettings.mode, equals(CalculationMethodMode.manual));
      // Method strictly preserved as Egyptian
      expect(postMoveSettings.method, equals(CalculationMethodType.egyptian));

      // 3. User travels to London, UK
      await locationRepo.saveLocation(uk, london);
      final ukSettings = await prayerRepo.getCalculationSettings();
      expect(ukSettings.mode, equals(CalculationMethodMode.manual));
      expect(ukSettings.method, equals(CalculationMethodType.egyptian));
    });

    test('Switching from Manual to Automatic restores recommended method immediately', () async {
      // User is in Makkah with manual Egyptian method
      await locationRepo.saveLocation(saudi, makkah);
      await prayerRepo.saveCalculationSettings(
        const CalculationSettings(
          mode: CalculationMethodMode.manual,
          method: CalculationMethodType.egyptian,
        ),
      );

      // User selects "Automatic (Recommended)"
      final country = (await locationRepo.getSelectedCountry())!;
      final city = (await locationRepo.getSelectedCity())!;
      final resolved = LocationCalculationMethodResolver.resolve(
        country: country,
        city: city,
      );

      await prayerRepo.saveCalculationSettings(
        CalculationSettings(
          mode: CalculationMethodMode.automatic,
          method: resolved,
        ),
      );

      final restored = await prayerRepo.getCalculationSettings();
      expect(restored.mode, equals(CalculationMethodMode.automatic));
      expect(restored.method, equals(CalculationMethodType.ummAlQura));
    });

    test('Lifecycle persistence: Saved settings and location survive repository reload', () async {
      // 1. Configure settings and location
      await locationRepo.saveLocation(saudi, makkah);
      await prayerRepo.saveCalculationSettings(
        const CalculationSettings(
          mode: CalculationMethodMode.manual,
          method: CalculationMethodType.ummAlQura,
          madhab: MadhabType.hanafi,
        ),
      );
      await prayerRepo.setGlobalAdhanEnabled(true);
      await prayerRepo.setPrayerAdhanEnabled(PrayerType.fajr, false);

      // 2. Simulate application restart: instantiate new repository instances pointing to same storage
      final reloadedLocationRepo = LocationRepositoryImpl(storage);
      final reloadedPrayerRepo = PrayerTimesRepositoryImpl(
        engine: AdhanPrayerCalculationEngine(),
        storage: storage,
      );

      final reloadedCountry = await reloadedLocationRepo.getSelectedCountry();
      final reloadedCity = await reloadedLocationRepo.getSelectedCity();
      final reloadedCalc = await reloadedPrayerRepo.getCalculationSettings();
      final reloadedGlobalAdhan = await reloadedPrayerRepo.getGlobalAdhanEnabled();
      final reloadedPerPrayer = await reloadedPrayerRepo.getPerPrayerAdhanSettings();

      expect(reloadedCountry?.code, equals('SA'));
      expect(reloadedCity?.id, equals('sa_makkah'));
      expect(reloadedCalc.mode, equals(CalculationMethodMode.manual));
      expect(reloadedCalc.method, equals(CalculationMethodType.ummAlQura));
      expect(reloadedCalc.madhab, equals(MadhabType.hanafi));
      expect(reloadedGlobalAdhan, isTrue);
      expect(reloadedPerPrayer[PrayerType.fajr], isFalse);
      expect(reloadedPerPrayer[PrayerType.dhuhr], isTrue);
    });

    test('Madhab change invalidates and recalculates Asr time', () async {
      await locationRepo.saveLocation(egypt, cairo);
      final testDate = DateTime(2026, 9, 6);

      // Standard (Shafi) calculation
      final shafiRes = await prayerRepo.getPrayerTimes(
        city: cairo,
        date: testDate,
        settings: const CalculationSettings(
          method: CalculationMethodType.egyptian,
          madhab: MadhabType.shafi,
        ),
      );
      final shafiTimes = (shafiRes as Success<DailyPrayerTimes>).data;

      // User changes Madhab to Hanafi
      final hanafiRes = await prayerRepo.getPrayerTimes(
        city: cairo,
        date: testDate,
        settings: const CalculationSettings(
          method: CalculationMethodType.egyptian,
          madhab: MadhabType.hanafi,
        ),
      );
      final hanafiTimes = (hanafiRes as Success<DailyPrayerTimes>).data;

      // In Hanafi, Asr shadow factor is 2 instead of 1 -> Asr is strictly later
      expect(hanafiTimes.asr.isAfter(shafiTimes.asr), isTrue);
      // Other prayer times remain unchanged
      expect(hanafiTimes.fajr, equals(shafiTimes.fajr));
      expect(hanafiTimes.dhuhr, equals(shafiTimes.dhuhr));
      expect(hanafiTimes.maghrib, equals(shafiTimes.maghrib));
    });
  });
}
