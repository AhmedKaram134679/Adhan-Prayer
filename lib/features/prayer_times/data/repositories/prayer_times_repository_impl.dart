import 'package:adhan_and_prayer/core/enums/time_enums.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/storage/local_storage.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';
import 'package:adhan_and_prayer/features/location/domain/entities/location_entities.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_calculation_engine.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/calculation_settings.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/prayer_entities.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/services/time_system_resolver.dart';

abstract class PrayerTimesRepository {
  Future<Result<DailyPrayerTimes>> getPrayerTimes({
    required City city,
    required DateTime date,
    required CalculationSettings settings,
    TimeSystemMode? timeSystemMode,
  });
  Future<CalculationSettings> getCalculationSettings();
  Future<Result<void>> saveCalculationSettings(CalculationSettings settings);
  Future<TimeSystemMode> getTimeSystemMode();
  Future<Result<void>> saveTimeSystemMode(TimeSystemMode mode);
  Future<Map<PrayerType, bool>> getPerPrayerAdhanSettings();
  Future<Result<void>> setPrayerAdhanEnabled(PrayerType prayerType, bool enabled);
  Future<bool> getGlobalAdhanEnabled();
  Future<Result<void>> setGlobalAdhanEnabled(bool enabled);
}

class PrayerTimesRepositoryImpl implements PrayerTimesRepository {
  final PrayerCalculationEngine engine;
  final LocalStorage storage;

  static const String _keyCalcMethod = 'calc_method';
  static const String _keyCalcMethodMode = 'calc_method_mode';
  static const String _keyMadhab = 'calc_madhab';
  static const String _keyTimeSystemMode = 'app_time_system_mode';
  static const String _keyGlobalAdhan = 'global_adhan_enabled';
  static const String _keyPrefixPrayerAdhan = 'adhan_enabled_';

  // In-memory cache for the day
  String? _cachedKey;
  DailyPrayerTimes? _cachedTimes;

  PrayerTimesRepositoryImpl({
    required this.engine,
    required this.storage,
  });

  @override
  Future<Result<DailyPrayerTimes>> getPrayerTimes({
    required City city,
    required DateTime date,
    required CalculationSettings settings,
    TimeSystemMode? timeSystemMode,
  }) async {
    final mode = timeSystemMode ?? await getTimeSystemMode();
    final key = '${city.id}_${date.year}_${date.month}_${date.day}_${settings.mode.name}_${settings.method.name}_${settings.madhab.name}_${mode.name}';
    if (_cachedKey == key && _cachedTimes != null) {
      return Success(_cachedTimes!);
    }

    final result = engine.calculatePrayerTimes(
      city: city,
      date: date,
      settings: settings,
    );

    if (result is Success<DailyPrayerTimes>) {
      final adjustment = TimeSystemResolver.calculateAdjustment(
        mode: mode,
        date: date,
      );
      final adjustedTimes = result.data.applyAdjustment(adjustment);
      _cachedKey = key;
      _cachedTimes = adjustedTimes;
      return Success(adjustedTimes);
    } else {
      return result;
    }
  }

  @override
  Future<TimeSystemMode> getTimeSystemMode() async {
    final modeStr = storage.getString(_keyTimeSystemMode);
    if (modeStr == null) return TimeSystemMode.automatic;
    return TimeSystemMode.values.firstWhere(
      (e) => e.name == modeStr,
      orElse: () => TimeSystemMode.automatic,
    );
  }

  @override
  Future<Result<void>> saveTimeSystemMode(TimeSystemMode mode) async {
    try {
      await storage.setString(_keyTimeSystemMode, mode.name);
      // Invalidate in-memory cache to force recalculation
      _cachedKey = null;
      _cachedTimes = null;
      return const Success(null);
    } catch (e, stack) {
      AppLogger.error('Failed to save time system mode', e, stack, 'PRAYER_REPO');
      return Failure('Failed to save time system mode: $e');
    }
  }

  @override
  Future<CalculationSettings> getCalculationSettings() async {
    final modeStr = storage.getString(_keyCalcMethodMode);
    final methodStr = storage.getString(_keyCalcMethod);
    final madhabStr = storage.getString(_keyMadhab);

    // Safe migration:
    // If mode is explicitly stored, use it.
    // If mode was never stored:
    // - If method was never stored, or was stored as the old default ('egyptian'),
    //   migrate to automatic so the user benefits from automatic location resolution.
    // - If method was stored as any other specific method, preserve manual mode to
    //   respect an intentional past user choice.
    final CalculationMethodMode mode = modeStr != null
        ? CalculationMethodMode.values.firstWhere(
            (e) => e.name == modeStr,
            orElse: () => CalculationMethodMode.automatic,
          )
        : (methodStr != null && methodStr != 'egyptian'
            ? CalculationMethodMode.manual
            : CalculationMethodMode.automatic);

    final method = CalculationMethodType.values.firstWhere(
      (e) => e.name == methodStr,
      orElse: () => CalculationMethodType.egyptian,
    );
    final madhab = MadhabType.values.firstWhere(
      (e) => e.name == madhabStr,
      orElse: () => MadhabType.shafi,
    );

    return CalculationSettings(mode: mode, method: method, madhab: madhab);
  }

  @override
  Future<Result<void>> saveCalculationSettings(CalculationSettings settings) async {
    try {
      await storage.setString(_keyCalcMethodMode, settings.mode.name);
      await storage.setString(_keyCalcMethod, settings.method.name);
      await storage.setString(_keyMadhab, settings.madhab.name);
      // Invalidate cache
      _cachedKey = null;
      _cachedTimes = null;
      AppLogger.info(
        'Saved calculation settings: mode=${settings.mode.name}, method=${settings.method.name}, madhab=${settings.madhab.name}',
        'PRAYER_REPO',
      );
      return const Success(null);
    } catch (e, stack) {
      AppLogger.error('Failed to save calculation settings', e, stack, 'PRAYER_REPO');
      return Failure('Failed to save calculation settings: $e');
    }
  }

  @override
  Future<bool> getGlobalAdhanEnabled() async {
    return storage.getBool(_keyGlobalAdhan) ?? true;
  }

  @override
  Future<Result<void>> setGlobalAdhanEnabled(bool enabled) async {
    try {
      await storage.setBool(_keyGlobalAdhan, enabled);
      return const Success(null);
    } catch (e, stack) {
      AppLogger.error('Failed to set global adhan setting', e, stack, 'PRAYER_REPO');
      return Failure('Failed to set global adhan: $e');
    }
  }

  @override
  Future<Map<PrayerType, bool>> getPerPrayerAdhanSettings() async {
    final map = <PrayerType, bool>{};
    for (final type in PrayerType.values) {
      if (type == PrayerType.sunrise) {
        map[type] = false;
        continue;
      }
      final key = '$_keyPrefixPrayerAdhan${type.name}';
      map[type] = storage.getBool(key) ?? true;
    }
    return map;
  }

  @override
  Future<Result<void>> setPrayerAdhanEnabled(PrayerType prayerType, bool enabled) async {
    try {
      final key = '$_keyPrefixPrayerAdhan${prayerType.name}';
      await storage.setBool(key, enabled);
      return const Success(null);
    } catch (e, stack) {
      AppLogger.error('Failed to set prayer adhan setting', e, stack, 'PRAYER_REPO');
      return Failure('Failed to set prayer adhan: $e');
    }
  }
}
