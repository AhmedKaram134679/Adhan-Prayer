import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/features/location/data/models/static_location_data.dart';

void main() {
  group('Static Location Data & Search Verification', () {
    test('Contains supported countries', () {
      expect(StaticLocationData.countries.isNotEmpty, isTrue);
      expect(StaticLocationData.countries.any((c) => c.code == 'EG'), isTrue);
      expect(StaticLocationData.countries.any((c) => c.code == 'SA'), isTrue);
      expect(StaticLocationData.countries.any((c) => c.code == 'AE'), isTrue);
      expect(StaticLocationData.countries.any((c) => c.code == 'GB'), isTrue);
      expect(StaticLocationData.countries.any((c) => c.code == 'US'), isTrue);
    });

    test('Cities have valid non-empty coordinates and timezones', () {
      for (final city in StaticLocationData.cities) {
        expect(city.id.isNotEmpty, isTrue, reason: 'City ID should not be empty');
        expect(city.nameAr.isNotEmpty, isTrue, reason: 'City nameAr should not be empty');
        expect(city.nameEn.isNotEmpty, isTrue, reason: 'City nameEn should not be empty');
        expect(city.countryCode.isNotEmpty, isTrue, reason: 'Country code should not be empty');
        expect(city.latitude, inInclusiveRange(-90.0, 90.0));
        expect(city.longitude, inInclusiveRange(-180.0, 180.0));
        expect(city.timezone.isNotEmpty, isTrue);
      }
    });

    test('Searching cities by Arabic name matches correctly', () {
      final query = 'الإسكندرية';
      final matches = StaticLocationData.cities.where(
        (c) => c.nameAr.contains(query) || c.nameEn.toLowerCase().contains(query.toLowerCase()),
      ).toList();

      expect(matches.isNotEmpty, isTrue);
      expect(matches.first.id, equals('eg_alex'));
    });

    test('Searching cities by English name matches case-insensitively', () {
      final query = 'cai';
      final matches = StaticLocationData.cities.where(
        (c) => c.nameAr.contains(query) || c.nameEn.toLowerCase().contains(query.toLowerCase()),
      ).toList();

      expect(matches.isNotEmpty, isTrue);
      expect(matches.any((c) => c.id == 'eg_cairo'), isTrue);
    });
  });
}
