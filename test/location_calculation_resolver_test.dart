import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/features/location/data/models/static_location_data.dart';
import 'package:adhan_and_prayer/features/location/domain/entities/location_entities.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/calculation_settings.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/services/location_calculation_method_resolver.dart';

void main() {
  group('LocationCalculationMethodResolver Tests', () {
    final egypt = StaticLocationData.countries.firstWhere((c) => c.code == 'EG');
    final saudi = StaticLocationData.countries.firstWhere((c) => c.code == 'SA');
    final uae = StaticLocationData.countries.firstWhere((c) => c.code == 'AE');
    final kuwait = StaticLocationData.countries.firstWhere((c) => c.code == 'KW');
    final qatar = StaticLocationData.countries.firstWhere((c) => c.code == 'QA');
    final pakistan = StaticLocationData.countries.firstWhere((c) => c.code == 'PK');
    final uk = StaticLocationData.countries.firstWhere((c) => c.code == 'GB');
    final usa = StaticLocationData.countries.firstWhere((c) => c.code == 'US');

    test('Egypt country and cities resolve to Egyptian General Authority', () {
      final cairo = StaticLocationData.cities.firstWhere((c) => c.id == 'eg_cairo');
      final alex = StaticLocationData.cities.firstWhere((c) => c.id == 'eg_alex');

      expect(
        LocationCalculationMethodResolver.resolve(country: egypt, city: cairo),
        equals(CalculationMethodType.egyptian),
      );
      expect(
        LocationCalculationMethodResolver.resolve(country: egypt, city: alex),
        equals(CalculationMethodType.egyptian),
      );
      expect(
        LocationCalculationMethodResolver.resolve(country: egypt),
        equals(CalculationMethodType.egyptian),
      );
    });

    test('Saudi Arabia Makkah & Madinah resolve to Umm Al Qura (City Override Priority 100)', () {
      final makkah = StaticLocationData.cities.firstWhere((c) => c.id == 'sa_makkah');
      final madinah = StaticLocationData.cities.firstWhere((c) => c.id == 'sa_madinah');
      final riyadh = StaticLocationData.cities.firstWhere((c) => c.id == 'sa_riyadh');

      expect(
        LocationCalculationMethodResolver.resolve(country: saudi, city: makkah),
        equals(CalculationMethodType.ummAlQura),
      );
      expect(
        LocationCalculationMethodResolver.resolve(country: saudi, city: madinah),
        equals(CalculationMethodType.ummAlQura),
      );
      expect(
        LocationCalculationMethodResolver.resolve(country: saudi, city: riyadh),
        equals(CalculationMethodType.ummAlQura),
      );
    });

    test('Gulf countries resolve to their designated local authorities', () {
      final dubai = StaticLocationData.cities.firstWhere((c) => c.id == 'ae_dubai');
      final kwCity = StaticLocationData.cities.firstWhere((c) => c.id == 'kw_kuwait');
      final doha = StaticLocationData.cities.firstWhere((c) => c.id == 'qa_doha');

      expect(
        LocationCalculationMethodResolver.resolve(country: uae, city: dubai),
        equals(CalculationMethodType.dubai),
      );
      expect(
        LocationCalculationMethodResolver.resolve(country: kuwait, city: kwCity),
        equals(CalculationMethodType.kuwait),
      );
      expect(
        LocationCalculationMethodResolver.resolve(country: qatar, city: doha),
        equals(CalculationMethodType.qatar),
      );
    });

    test('Pakistan Karachi resolves to University of Islamic Sciences (Karachi)', () {
      final karachi = StaticLocationData.cities.firstWhere((c) => c.id == 'pk_karachi');
      final lahore = StaticLocationData.cities.firstWhere((c) => c.id == 'pk_lahore');

      expect(
        LocationCalculationMethodResolver.resolve(country: pakistan, city: karachi),
        equals(CalculationMethodType.karachi),
      );
      expect(
        LocationCalculationMethodResolver.resolve(country: pakistan, city: lahore),
        equals(CalculationMethodType.karachi),
      );
    });

    test('United Kingdom resolves to Muslim World League', () {
      final london = StaticLocationData.cities.firstWhere((c) => c.id == 'gb_london');

      expect(
        LocationCalculationMethodResolver.resolve(country: uk, city: london),
        equals(CalculationMethodType.muslimWorldLeague),
      );
    });

    test('United States & Canada resolve to ISNA (North America)', () {
      final nyc = StaticLocationData.cities.firstWhere((c) => c.id == 'us_nyc');
      final toronto = StaticLocationData.cities.firstWhere((c) => c.id == 'ca_toronto');
      final canada = StaticLocationData.countries.firstWhere((c) => c.code == 'CA');

      expect(
        LocationCalculationMethodResolver.resolve(country: usa, city: nyc),
        equals(CalculationMethodType.northAmerica),
      );
      expect(
        LocationCalculationMethodResolver.resolve(country: canada, city: toronto),
        equals(CalculationMethodType.northAmerica),
      );
    });

    test('Unknown country falls back gracefully to Muslim World League without crashing', () {
      const unknownCountry = Country(code: 'XX', nameAr: 'غير معروف', nameEn: 'Unknown');
      expect(
        LocationCalculationMethodResolver.resolve(country: unknownCountry),
        equals(CalculationMethodType.muslimWorldLeague),
      );
    });

    test('City override wins over country level rule', () {
      // Mock hypothetical rule override
      final makkah = StaticLocationData.cities.firstWhere((c) => c.id == 'sa_makkah');
      final resolved = LocationCalculationMethodResolver.resolve(country: saudi, city: makkah);
      expect(resolved, equals(CalculationMethodType.ummAlQura));
    });
  });

  group('CalculationSettings JSON & Migration Tests', () {
    test('Fresh default calculation settings uses automatic mode', () {
      const settings = CalculationSettings();
      expect(settings.mode, equals(CalculationMethodMode.automatic));
      expect(settings.method, equals(CalculationMethodType.egyptian));
      expect(settings.madhab, equals(MadhabType.shafi));
    });

    test('Legacy JSON with explicit non-default method migrates to manual', () {
      final legacyJson = {
        'method': 'karachi',
        'madhab': 'hanafi',
      };
      final migrated = CalculationSettings.fromJson(legacyJson);
      expect(migrated.mode, equals(CalculationMethodMode.manual));
      expect(migrated.method, equals(CalculationMethodType.karachi));
      expect(migrated.madhab, equals(MadhabType.hanafi));
    });

    test('Legacy JSON with old default method (egyptian) migrates to automatic', () {
      final legacyJson = {
        'method': 'egyptian',
        'madhab': 'shafi',
      };
      final migrated = CalculationSettings.fromJson(legacyJson);
      expect(migrated.mode, equals(CalculationMethodMode.automatic));
      expect(migrated.method, equals(CalculationMethodType.egyptian));
      expect(migrated.madhab, equals(MadhabType.shafi));
    });

    test('Modern JSON with mode round-trips perfectly', () {
      const original = CalculationSettings(
        mode: CalculationMethodMode.automatic,
        method: CalculationMethodType.ummAlQura,
        madhab: MadhabType.shafi,
      );
      final json = original.toJson();
      expect(json['mode'], equals('automatic'));
      expect(json['method'], equals('ummAlQura'));
      expect(json['madhab'], equals('shafi'));

      final reconstructed = CalculationSettings.fromJson(json);
      expect(reconstructed.mode, equals(CalculationMethodMode.automatic));
      expect(reconstructed.method, equals(CalculationMethodType.ummAlQura));
      expect(reconstructed.madhab, equals(MadhabType.shafi));
    });
  });
}
