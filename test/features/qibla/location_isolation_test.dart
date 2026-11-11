import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan_and_prayer/core/storage/local_storage.dart';
import 'package:adhan_and_prayer/features/location/data/repositories/location_repository_impl.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_calculation_engine.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/prayer_entities.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/features/qibla/data/repositories/qibla_repository_impl.dart';

void main() {
  group('MANDATORY Location Isolation Tests (Qibla Location vs Prayer Times Location)', () {
    late SharedPreferences sharedPrefs;
    late LocalStorage storage;
    late LocationRepositoryImpl locationRepo;
    late PrayerTimesRepositoryImpl prayerRepo;
    late QiblaRepositoryImpl qiblaRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'selected_country_code': 'EG',
        'selected_city_id': 'eg_cairo',
        'calculation_method': 'egyptian',
      });
      sharedPrefs = await SharedPreferences.getInstance();
      storage = SharedPreferencesStorage(sharedPrefs);
      locationRepo = LocationRepositoryImpl(storage);
      prayerRepo = PrayerTimesRepositoryImpl(
        engine: AdhanPrayerCalculationEngine(),
        storage: storage,
      );
      qiblaRepo = QiblaRepositoryImpl();
    });

    test(
      'Executing Qibla calculation for a completely different GPS coordinate DOES NOT change selected prayer city or prayer times',
      () async {
        // 1. Initial State: Selected city is Cairo, Egypt
        final initialCountry = await locationRepo.getSelectedCountry();
        final initialCity = await locationRepo.getSelectedCity();

        expect(initialCountry, isNotNull);
        expect(initialCity, isNotNull);
        expect(initialCountry!.code, equals('EG'));
        expect(initialCity!.id, equals('eg_cairo'));
        expect(initialCity.nameEn, equals('Cairo'));
        expect(initialCity.latitude, closeTo(30.0444, 0.001));
        expect(initialCity.longitude, closeTo(31.2357, 0.001));

        final initialSettings = await prayerRepo.getCalculationSettings();
        final testDate = DateTime(2026, 9, 15);
        final initialPrayerTimes = await prayerRepo.getPrayerTimes(
          city: initialCity,
          date: testDate,
          settings: initialSettings,
        );
        expect(initialPrayerTimes, isA<Success<DailyPrayerTimes>>());
        final initialTimes = (initialPrayerTimes as Success<DailyPrayerTimes>).data;

        // 2. User opens Qibla in Tokyo, Japan (GPS: 35.6762° N, 139.6503° E)
        const tokyoGpsLat = 35.6762;
        const tokyoGpsLng = 139.6503;

        final qiblaResult = await qiblaRepo.getQiblaDirection(tokyoGpsLat, tokyoGpsLng);

        // Verify Qibla calculated for Tokyo GPS
        expect(qiblaResult.latitude, equals(tokyoGpsLat));
        expect(qiblaResult.longitude, equals(tokyoGpsLng));
        expect(qiblaResult.qiblaBearing, closeTo(293.02, 0.5));

        // 3. STRICT ASSERTION: Selected Prayer Times country and city remain Cairo, Egypt
        final postCountry = await locationRepo.getSelectedCountry();
        final postCity = await locationRepo.getSelectedCity();

        expect(postCountry?.code, equals('EG'), reason: 'Prayer country must NOT change');
        expect(postCity?.id, equals('eg_cairo'), reason: 'Prayer city must NOT change');
        expect(postCity?.nameEn, equals('Cairo'));
        expect(postCity?.latitude, closeTo(30.0444, 0.001));
        expect(postCity?.longitude, closeTo(31.2357, 0.001));

        // 4. STRICT ASSERTION: Prayer calculation times remain exactly identical to initial Cairo times
        final postPrayerTimes = await prayerRepo.getPrayerTimes(
          city: postCity!,
          date: testDate,
          settings: initialSettings,
        );
        expect(postPrayerTimes, isA<Success<DailyPrayerTimes>>());
        final postTimes = (postPrayerTimes as Success<DailyPrayerTimes>).data;

        expect(postTimes.fajr, equals(initialTimes.fajr));
        expect(postTimes.sunrise, equals(initialTimes.sunrise));
        expect(postTimes.dhuhr, equals(initialTimes.dhuhr));
        expect(postTimes.asr, equals(initialTimes.asr));
        expect(postTimes.maghrib, equals(initialTimes.maghrib));
        expect(postTimes.isha, equals(initialTimes.isha));

        // 5. Check persistent storage has not been contaminated
        expect(storage.getString('selected_country_code'), equals('EG'));
        expect(storage.getString('selected_city_id'), equals('eg_cairo'));
      },
    );
  });
}
