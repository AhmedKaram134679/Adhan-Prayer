import 'package:flutter/foundation.dart';

enum PrayerType {
  fajr,
  sunrise,
  dhuhr,
  asr,
  maghrib,
  isha,
}

@immutable
class PrayerItem {
  final PrayerType type;
  final String identifier;
  final String nameEn;
  final String nameAr;
  final DateTime time;
  final bool isObligatory;
  final bool isAdhanEnabled;

  const PrayerItem({
    required this.type,
    required this.identifier,
    required this.nameEn,
    required this.nameAr,
    required this.time,
    required this.isObligatory,
    this.isAdhanEnabled = true,
  });

  String getLocalizedName(String languageCode) {
    return languageCode == 'ar' ? nameAr : nameEn;
  }
}

@immutable
class DailyPrayerTimes {
  final DateTime date;
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  const DailyPrayerTimes({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  /// Returns a new [DailyPrayerTimes] with the specified time [offset] applied to all prayer times.
  DailyPrayerTimes applyAdjustment(Duration offset) {
    if (offset == Duration.zero) return this;
    return DailyPrayerTimes(
      date: date,
      fajr: fajr.add(offset),
      sunrise: sunrise.add(offset),
      dhuhr: dhuhr.add(offset),
      asr: asr.add(offset),
      maghrib: maghrib.add(offset),
      isha: isha.add(offset),
    );
  }

  List<PrayerItem> toList({Map<PrayerType, bool>? perPrayerAdhan}) {
    bool isAdhanOn(PrayerType t) => perPrayerAdhan?[t] ?? true;

    return [
      PrayerItem(
        type: PrayerType.fajr,
        identifier: 'fajr',
        nameEn: 'Fajr',
        nameAr: 'الفجر',
        time: fajr,
        isObligatory: true,
        isAdhanEnabled: isAdhanOn(PrayerType.fajr),
      ),
      PrayerItem(
        type: PrayerType.sunrise,
        identifier: 'sunrise',
        nameEn: 'Sunrise',
        nameAr: 'الشروق',
        time: sunrise,
        isObligatory: false,
        isAdhanEnabled: false, // Sunrise is informational
      ),
      PrayerItem(
        type: PrayerType.dhuhr,
        identifier: 'dhuhr',
        nameEn: 'Dhuhr',
        nameAr: 'الظهر',
        time: dhuhr,
        isObligatory: true,
        isAdhanEnabled: isAdhanOn(PrayerType.dhuhr),
      ),
      PrayerItem(
        type: PrayerType.asr,
        identifier: 'asr',
        nameEn: 'Asr',
        nameAr: 'العصر',
        time: asr,
        isObligatory: true,
        isAdhanEnabled: isAdhanOn(PrayerType.asr),
      ),
      PrayerItem(
        type: PrayerType.maghrib,
        identifier: 'maghrib',
        nameEn: 'Maghrib',
        nameAr: 'المغرب',
        time: maghrib,
        isObligatory: true,
        isAdhanEnabled: isAdhanOn(PrayerType.maghrib),
      ),
      PrayerItem(
        type: PrayerType.isha,
        identifier: 'isha',
        nameEn: 'Isha',
        nameAr: 'العشاء',
        time: isha,
        isObligatory: true,
        isAdhanEnabled: isAdhanOn(PrayerType.isha),
      ),
    ];
  }
}
