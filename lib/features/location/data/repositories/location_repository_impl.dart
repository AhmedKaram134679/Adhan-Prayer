import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/storage/local_storage.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';
import 'package:adhan_and_prayer/features/location/data/models/static_location_data.dart';
import 'package:adhan_and_prayer/features/location/domain/entities/location_entities.dart';

abstract class LocationRepository {
  Future<List<Country>> getCountries();
  Future<List<City>> getCitiesForCountry(String countryCode);
  Future<List<City>> searchCities(String query, {String? countryCode});
  Future<City?> getSelectedCity();
  Future<Country?> getSelectedCountry();
  Future<Result<void>> saveLocation(Country country, City city);
}

class LocationRepositoryImpl implements LocationRepository {
  final LocalStorage _localStorage;

  static const String _keyCountryCode = 'selected_country_code';
  static const String _keyCityId = 'selected_city_id';

  LocationRepositoryImpl(this._localStorage);

  @override
  Future<List<Country>> getCountries() async {
    return StaticLocationData.countries;
  }

  @override
  Future<List<City>> getCitiesForCountry(String countryCode) async {
    return StaticLocationData.cities
        .where((c) => c.countryCode.toUpperCase() == countryCode.toUpperCase())
        .toList();
  }

  @override
  Future<List<City>> searchCities(String query, {String? countryCode}) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      return countryCode != null ? getCitiesForCountry(countryCode) : StaticLocationData.cities;
    }

    return StaticLocationData.cities.where((city) {
      final matchesCountry = countryCode == null ||
          city.countryCode.toUpperCase() == countryCode.toUpperCase();
      if (!matchesCountry) return false;

      final matchesEn = city.nameEn.toLowerCase().contains(cleanQuery);
      final matchesAr = city.nameAr.contains(cleanQuery);
      return matchesEn || matchesAr;
    }).toList();
  }

  @override
  Future<Country?> getSelectedCountry() async {
    final code = _localStorage.getString(_keyCountryCode);
    if (code == null) return null;
    try {
      return StaticLocationData.countries.firstWhere((c) => c.code == code);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<City?> getSelectedCity() async {
    final id = _localStorage.getString(_keyCityId);
    if (id == null) return null;
    try {
      return StaticLocationData.cities.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Result<void>> saveLocation(Country country, City city) async {
    try {
      await _localStorage.setString(_keyCountryCode, country.code);
      await _localStorage.setString(_keyCityId, city.id);
      AppLogger.info('Saved location: ${city.nameEn}, ${country.nameEn}', 'LOCATION');
      return const Success(null);
    } catch (e, stack) {
      AppLogger.error('Failed to save location', e, stack, 'LOCATION');
      return Failure('Failed to save location: $e');
    }
  }
}
