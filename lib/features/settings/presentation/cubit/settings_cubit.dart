import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adhan_and_prayer/core/audio/audio_player_service.dart';
import 'package:adhan_and_prayer/core/platform/windows_tray_manager.dart';
import 'package:adhan_and_prayer/core/storage/local_storage.dart';
import 'package:adhan_and_prayer/core/enums/time_enums.dart';
import 'package:adhan_and_prayer/features/adhan/data/repositories/audio_repository_impl.dart';
import 'package:adhan_and_prayer/features/location/data/repositories/location_repository_impl.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/calculation_settings.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/prayer_entities.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/services/location_calculation_method_resolver.dart';

class SettingsState {
  final ThemeMode themeMode;
  final Locale locale;
  final CalculationSettings calculationSettings;
  final TimeSystemMode timeSystemMode;
  final ClockFormat clockFormat;
  final bool globalAdhanEnabled;
  final Map<PrayerType, bool> perPrayerAdhan;
  final bool startWithWindows;
  final double adhanVolume;

  const SettingsState({
    required this.themeMode,
    required this.locale,
    required this.calculationSettings,
    this.timeSystemMode = TimeSystemMode.automatic,
    this.clockFormat = ClockFormat.twelveHour,
    required this.globalAdhanEnabled,
    required this.perPrayerAdhan,
    required this.startWithWindows,
    this.adhanVolume = 1.0,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    CalculationSettings? calculationSettings,
    TimeSystemMode? timeSystemMode,
    ClockFormat? clockFormat,
    bool? globalAdhanEnabled,
    Map<PrayerType, bool>? perPrayerAdhan,
    bool? startWithWindows,
    double? adhanVolume,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      calculationSettings: calculationSettings ?? this.calculationSettings,
      timeSystemMode: timeSystemMode ?? this.timeSystemMode,
      clockFormat: clockFormat ?? this.clockFormat,
      globalAdhanEnabled: globalAdhanEnabled ?? this.globalAdhanEnabled,
      perPrayerAdhan: perPrayerAdhan ?? this.perPrayerAdhan,
      startWithWindows: startWithWindows ?? this.startWithWindows,
      adhanVolume: adhanVolume ?? this.adhanVolume,
    );
  }
}

class SettingsCubit extends Cubit<SettingsState> {
  final LocalStorage storage;
  final PrayerTimesRepository prayerRepo;
  final LocationRepository locationRepo;
  final AudioRepository audioRepo;
  final AudioPlayerService audioPlayer;

  static const String _keyTheme = 'app_theme_mode';
  static const String _keyLocale = 'app_locale';
  static const String _keyStartWindows = 'start_with_windows';
  static const String _keyClockFormat = 'app_clock_format';

  SettingsCubit({
    required this.storage,
    required this.prayerRepo,
    required this.locationRepo,
    required this.audioRepo,
    required this.audioPlayer,
  }) : super(
          const SettingsState(
            themeMode: ThemeMode.system,
            locale: Locale('en'),
            calculationSettings: CalculationSettings(),
            timeSystemMode: TimeSystemMode.automatic,
            clockFormat: ClockFormat.twelveHour,
            globalAdhanEnabled: true,
            perPrayerAdhan: {},
            startWithWindows: false,
            adhanVolume: 1.0,
          ),
        );

  Future<void> initialize() async {
    // Theme
    final themeStr = storage.getString(_keyTheme);
    final themeMode = themeStr == 'dark'
        ? ThemeMode.dark
        : themeStr == 'light'
            ? ThemeMode.light
            : ThemeMode.system;

    // Locale
    final langStr = storage.getString(_keyLocale) ?? 'en';
    final locale = Locale(langStr);

    // Prayer settings & Time system
    final calcSettings = await prayerRepo.getCalculationSettings();
    final timeSystemMode = await prayerRepo.getTimeSystemMode();

    // Clock format
    final clockFormatStr = storage.getString(_keyClockFormat);
    final clockFormat = clockFormatStr == ClockFormat.twentyFourHour.name
        ? ClockFormat.twentyFourHour
        : ClockFormat.twelveHour;

    final globalAdhan = await prayerRepo.getGlobalAdhanEnabled();
    final perPrayer = await prayerRepo.getPerPrayerAdhanSettings();

    // Windows startup
    bool startWindows = false;
    if (Platform.isWindows) {
      startWindows = await WindowsTrayManager().isLaunchAtStartupEnabled();
    }

    // Adhan volume
    final volume = await audioRepo.getAdhanVolume();
    await audioPlayer.setVolume(volume);

    emit(
      SettingsState(
        themeMode: themeMode,
        locale: locale,
        calculationSettings: calcSettings,
        timeSystemMode: timeSystemMode,
        clockFormat: clockFormat,
        globalAdhanEnabled: globalAdhan,
        perPrayerAdhan: perPrayer,
        startWithWindows: startWindows,
        adhanVolume: volume,
      ),
    );
  }

  Future<void> setAdhanVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    await audioRepo.saveAdhanVolume(clamped);
    await audioPlayer.setVolume(clamped);
    emit(state.copyWith(adhanVolume: clamped));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final modeStr = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.light
            ? 'light'
            : 'system';
    await storage.setString(_keyTheme, modeStr);
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> setLocale(Locale locale) async {
    await storage.setString(_keyLocale, locale.languageCode);
    emit(state.copyWith(locale: locale));
  }

  Future<void> setCalculationSettings(CalculationSettings settings) async {
    await prayerRepo.saveCalculationSettings(settings);
    emit(state.copyWith(calculationSettings: settings));
  }

  Future<void> setCalculationMethodMode(CalculationMethodMode mode) async {
    if (mode == CalculationMethodMode.automatic) {
      final country = await locationRepo.getSelectedCountry();
      final city = await locationRepo.getSelectedCity();
      CalculationMethodType resolvedMethod = state.calculationSettings.method;
      if (country != null) {
        resolvedMethod = LocationCalculationMethodResolver.resolve(
          country: country,
          city: city,
        );
      }
      final newSettings = state.calculationSettings.copyWith(
        mode: CalculationMethodMode.automatic,
        method: resolvedMethod,
      );
      await setCalculationSettings(newSettings);
    } else {
      final newSettings = state.calculationSettings.copyWith(
        mode: CalculationMethodMode.manual,
      );
      await setCalculationSettings(newSettings);
    }
  }

  Future<void> setManualCalculationMethod(CalculationMethodType method) async {
    final newSettings = state.calculationSettings.copyWith(
      mode: CalculationMethodMode.manual,
      method: method,
    );
    await setCalculationSettings(newSettings);
  }

  Future<void> setGlobalAdhanEnabled(bool enabled) async {
    await prayerRepo.setGlobalAdhanEnabled(enabled);
    emit(state.copyWith(globalAdhanEnabled: enabled));
  }

  Future<void> setPrayerAdhanEnabled(PrayerType type, bool enabled) async {
    await prayerRepo.setPrayerAdhanEnabled(type, enabled);
    final updated = Map<PrayerType, bool>.from(state.perPrayerAdhan);
    updated[type] = enabled;
    emit(state.copyWith(perPrayerAdhan: updated));
  }

  Future<void> setTimeSystemMode(TimeSystemMode mode) async {
    await prayerRepo.saveTimeSystemMode(mode);
    emit(state.copyWith(timeSystemMode: mode));
  }

  Future<void> setClockFormat(ClockFormat format) async {
    await storage.setString(_keyClockFormat, format.name);
    emit(state.copyWith(clockFormat: format));
  }

  Future<void> setStartWithWindows(bool enabled) async {
    if (Platform.isWindows) {
      await WindowsTrayManager().setLaunchAtStartup(enabled);
      await storage.setBool(_keyStartWindows, enabled);
      emit(state.copyWith(startWithWindows: enabled));
    }
  }
}

