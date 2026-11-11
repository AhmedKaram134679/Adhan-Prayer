import 'package:adhan/adhan.dart' as adhan;
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';
import 'package:adhan_and_prayer/features/location/domain/entities/location_entities.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/calculation_settings.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/prayer_entities.dart';

abstract class PrayerCalculationEngine {
  Result<DailyPrayerTimes> calculatePrayerTimes({
    required City city,
    required DateTime date,
    required CalculationSettings settings,
  });
}

class AdhanPrayerCalculationEngine implements PrayerCalculationEngine {
  @override
  Result<DailyPrayerTimes> calculatePrayerTimes({
    required City city,
    required DateTime date,
    required CalculationSettings settings,
  }) {
    try {
      final coordinates = adhan.Coordinates(city.latitude, city.longitude);
      final dateComponents = adhan.DateComponents(date.year, date.month, date.day);

      final params = _getCalculationParameters(settings.method);
      params.madhab = settings.madhab == MadhabType.hanafi
          ? adhan.Madhab.hanafi
          : adhan.Madhab.shafi;

      final prayerTimes = adhan.PrayerTimes(coordinates, dateComponents, params);

      return Success(
        DailyPrayerTimes(
          date: DateTime(date.year, date.month, date.day),
          fajr: prayerTimes.fajr,
          sunrise: prayerTimes.sunrise,
          dhuhr: prayerTimes.dhuhr,
          asr: prayerTimes.asr,
          maghrib: prayerTimes.maghrib,
          isha: prayerTimes.isha,
        ),
      );
    } catch (e, stack) {
      AppLogger.error('Failed to calculate prayer times', e, stack, 'PRAYER_ENGINE');
      return Failure('Error calculating prayer times: $e');
    }
  }

  adhan.CalculationParameters _getCalculationParameters(CalculationMethodType method) {
    switch (method) {
      case CalculationMethodType.muslimWorldLeague:
        return adhan.CalculationMethod.muslim_world_league.getParameters();
      case CalculationMethodType.egyptian:
        return adhan.CalculationMethod.egyptian.getParameters();
      case CalculationMethodType.karachi:
        return adhan.CalculationMethod.karachi.getParameters();
      case CalculationMethodType.ummAlQura:
        return adhan.CalculationMethod.umm_al_qura.getParameters();
      case CalculationMethodType.dubai:
        return adhan.CalculationMethod.dubai.getParameters();
      case CalculationMethodType.qatar:
        return adhan.CalculationMethod.qatar.getParameters();
      case CalculationMethodType.kuwait:
        return adhan.CalculationMethod.kuwait.getParameters();
      case CalculationMethodType.moonsightingCommittee:
        return adhan.CalculationMethod.moon_sighting_committee.getParameters();
      case CalculationMethodType.northAmerica:
        return adhan.CalculationMethod.north_america.getParameters();
    }
  }
}
