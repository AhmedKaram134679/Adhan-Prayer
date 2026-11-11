import 'package:adhan_and_prayer/core/utils/logger.dart';
import 'package:adhan_and_prayer/features/location/domain/entities/location_entities.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/calculation_settings.dart';

class LocationCalculationRule {
  final String countryCode;
  final Set<String> cityIds;
  final CalculationMethodType method;
  final int priority;

  const LocationCalculationRule({
    required this.countryCode,
    this.cityIds = const {},
    required this.method,
    required this.priority,
  });
}

class LocationCalculationMethodResolver {
  static const CalculationMethodType fallbackMethod = CalculationMethodType.muslimWorldLeague;

  /// Centralized rule catalog
  /// Priorities:
  /// - City Override: 100
  /// - Country Default: 10
  static final List<LocationCalculationRule> _rules = [
    // --- Saudi Arabia ---
    // Specific Holy City Overrides (Priority 100)
    const LocationCalculationRule(
      countryCode: 'SA',
      cityIds: {'sa_makkah', 'sa_madinah'},
      method: CalculationMethodType.ummAlQura,
      priority: 100,
    ),
    // Country Default (Priority 10)
    const LocationCalculationRule(
      countryCode: 'SA',
      method: CalculationMethodType.ummAlQura,
      priority: 10,
    ),

    // --- Egypt ---
    const LocationCalculationRule(
      countryCode: 'EG',
      method: CalculationMethodType.egyptian,
      priority: 10,
    ),

    // --- UAE ---
    const LocationCalculationRule(
      countryCode: 'AE',
      method: CalculationMethodType.dubai,
      priority: 10,
    ),

    // --- Kuwait ---
    const LocationCalculationRule(
      countryCode: 'KW',
      method: CalculationMethodType.kuwait,
      priority: 10,
    ),

    // --- Qatar ---
    const LocationCalculationRule(
      countryCode: 'QA',
      method: CalculationMethodType.qatar,
      priority: 10,
    ),

    // --- Bahrain & Oman ---
    const LocationCalculationRule(
      countryCode: 'BH',
      method: CalculationMethodType.ummAlQura,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'OM',
      method: CalculationMethodType.ummAlQura,
      priority: 10,
    ),

    // --- Pakistan ---
    const LocationCalculationRule(
      countryCode: 'PK',
      method: CalculationMethodType.karachi,
      priority: 10,
    ),

    // --- Bangladesh & India ---
    const LocationCalculationRule(
      countryCode: 'BD',
      method: CalculationMethodType.karachi,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'IN',
      method: CalculationMethodType.karachi,
      priority: 10,
    ),

    // --- United Kingdom & Europe ---
    const LocationCalculationRule(
      countryCode: 'GB',
      method: CalculationMethodType.muslimWorldLeague,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'FR',
      method: CalculationMethodType.muslimWorldLeague,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'DE',
      method: CalculationMethodType.muslimWorldLeague,
      priority: 10,
    ),

    // --- North America (USA & Canada) ---
    const LocationCalculationRule(
      countryCode: 'US',
      method: CalculationMethodType.northAmerica,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'CA',
      method: CalculationMethodType.northAmerica,
      priority: 10,
    ),

    // --- Levant & North Africa ---
    const LocationCalculationRule(
      countryCode: 'JO',
      method: CalculationMethodType.muslimWorldLeague,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'PS',
      method: CalculationMethodType.muslimWorldLeague,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'LB',
      method: CalculationMethodType.muslimWorldLeague,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'SY',
      method: CalculationMethodType.muslimWorldLeague,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'IQ',
      method: CalculationMethodType.muslimWorldLeague,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'SD',
      method: CalculationMethodType.egyptian,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'LY',
      method: CalculationMethodType.egyptian,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'TN',
      method: CalculationMethodType.muslimWorldLeague,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'DZ',
      method: CalculationMethodType.muslimWorldLeague,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'MA',
      method: CalculationMethodType.muslimWorldLeague,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'TR',
      method: CalculationMethodType.muslimWorldLeague,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'ID',
      method: CalculationMethodType.muslimWorldLeague,
      priority: 10,
    ),
    const LocationCalculationRule(
      countryCode: 'MY',
      method: CalculationMethodType.muslimWorldLeague,
      priority: 10,
    ),
  ];

  /// Resolves the recommended calculation method for a given country and optional city.
  /// Evaluation Order:
  /// 1. City-level override rule (highest priority)
  /// 2. Country-level default rule
  /// 3. Fallback method
  static CalculationMethodType resolve({
    required Country country,
    City? city,
  }) {
    final countryCode = country.code.toUpperCase().trim();
    final cityId = city?.id.toLowerCase().trim();

    // 1. Check for City Override
    if (cityId != null && cityId.isNotEmpty) {
      for (final rule in _rules) {
        if (rule.priority >= 100 &&
            rule.countryCode.toUpperCase() == countryCode &&
            rule.cityIds.contains(cityId)) {
          AppLogger.info(
            'Resolved calculation method by City Override: ${city?.nameEn} -> ${rule.method.name}',
            'RESOLVER',
          );
          return rule.method;
        }
      }
    }

    // 2. Check for Country Default
    for (final rule in _rules) {
      if (rule.priority < 100 && rule.countryCode.toUpperCase() == countryCode) {
        AppLogger.info(
          'Resolved calculation method by Country Default: ${country.nameEn} -> ${rule.method.name}',
          'RESOLVER',
        );
        return rule.method;
      }
    }

    // 3. Fallback
    AppLogger.info(
      'Using Fallback calculation method for ${country.nameEn}: ${fallbackMethod.name}',
      'RESOLVER',
    );
    return fallbackMethod;
  }
}
