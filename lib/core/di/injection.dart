import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan_and_prayer/core/audio/audio_player_service.dart';
import 'package:adhan_and_prayer/core/notifications/app_notification_service.dart';
import 'package:adhan_and_prayer/core/platform/adhan_scheduler_service.dart';
import 'package:adhan_and_prayer/core/storage/local_storage.dart';
import 'package:adhan_and_prayer/features/adhan/data/repositories/audio_repository_impl.dart';
import 'package:adhan_and_prayer/features/adhan/domain/services/adhan_playback_coordinator.dart';
import 'package:adhan_and_prayer/features/adhan/presentation/cubit/audio_cubit.dart';
import 'package:adhan_and_prayer/features/location/data/repositories/location_repository_impl.dart';
import 'package:adhan_and_prayer/features/location/presentation/cubit/location_cubit.dart';
import 'package:adhan_and_prayer/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_calculation_engine.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import 'package:adhan_and_prayer/features/prayer_times/presentation/cubit/prayer_cubit.dart';
import 'package:adhan_and_prayer/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:adhan_and_prayer/core/update/config/update_config.dart';
import 'package:adhan_and_prayer/core/update/engine/update_engine.dart';
import 'package:adhan_and_prayer/core/update/presentation/cubit/update_cubit.dart';
import 'package:adhan_and_prayer/core/config/app_version.dart';
import 'package:adhan_and_prayer/features/qibla/domain/repositories/qibla_repository.dart';
import 'package:adhan_and_prayer/features/qibla/data/repositories/qibla_repository_impl.dart';
import 'package:adhan_and_prayer/features/qibla/presentation/cubit/qibla_cubit.dart';

final getIt = GetIt.instance;

Future<void> setupDependencyInjection() async {
  // 1. Storage & Core Services
  final sharedPrefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<LocalStorage>(SharedPreferencesStorage(sharedPrefs));

  getIt.registerSingleton<AudioPlayerService>(AudioPlayerServiceImpl());
  getIt.registerSingleton<AppNotificationService>(
      AppNotificationServiceImpl(getIt<LocalStorage>()));
  getIt.registerSingleton<AdhanPlaybackCoordinator>(
    AdhanPlaybackCoordinatorImpl(
      audioPlayer: getIt<AudioPlayerService>(),
      notificationService: getIt<AppNotificationService>(),
    ),
  );
  getIt.registerSingleton<AdhanSchedulerService>(AdhanSchedulerServiceImpl());

  // 1.1 Auto-Update Engine
  const updateConfig = AppUpdateConfig(
    appId: 'adhan_and_prayer',
    metadataUrl: 'https://raw.githubusercontent.com/AhmedKaram222/ahmed-app-updates/main/Adhan%20&%20Prayer/version.json',
    currentVersion: AppVersion.versionName,
    currentVersionCode: AppVersion.versionCode,
  );
  getIt.registerLazySingleton<UpdateEngine>(
    () => UpdateEngine(config: updateConfig),
  );

  // 2. Engines & Repositories
  getIt.registerLazySingleton<PrayerCalculationEngine>(
    () => AdhanPrayerCalculationEngine(),
  );

  getIt.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(getIt<LocalStorage>()),
  );

  getIt.registerLazySingleton<PrayerTimesRepository>(
    () => PrayerTimesRepositoryImpl(
      engine: getIt<PrayerCalculationEngine>(),
      storage: getIt<LocalStorage>(),
    ),
  );

  getIt.registerLazySingleton<AudioRepository>(
    () => AudioRepositoryImpl(getIt<LocalStorage>()),
  );

  getIt.registerLazySingleton<QiblaRepository>(
    () => QiblaRepositoryImpl(),
  );

  // 3. Presentation State Managers (Cubits)
  getIt.registerFactory<OnboardingCubit>(
    () => OnboardingCubit(getIt<LocalStorage>()),
  );

  getIt.registerFactory<LocationCubit>(
    () => LocationCubit(
      locationRepo: getIt<LocationRepository>(),
      schedulerService: getIt<AdhanSchedulerService>(),
    ),
  );

  getIt.registerFactory<AudioCubit>(
    () => AudioCubit(
      audioRepo: getIt<AudioRepository>(),
      audioPlayer: getIt<AudioPlayerService>(),
    ),
  );

  getIt.registerFactory<SettingsCubit>(
    () => SettingsCubit(
      storage: getIt<LocalStorage>(),
      prayerRepo: getIt<PrayerTimesRepository>(),
      locationRepo: getIt<LocationRepository>(),
      audioRepo: getIt<AudioRepository>(),
      audioPlayer: getIt<AudioPlayerService>(),
    ),
  );

  getIt.registerFactory<PrayerCubit>(
    () => PrayerCubit(
      prayerRepo: getIt<PrayerTimesRepository>(),
      locationRepo: getIt<LocationRepository>(),
      audioRepo: getIt<AudioRepository>(),
      schedulerService: getIt<AdhanSchedulerService>(),
      notificationService: getIt<AppNotificationService>(),
      audioPlayer: getIt<AudioPlayerService>(),
      coordinator: getIt<AdhanPlaybackCoordinator>(),
    ),
  );

  getIt.registerFactory<UpdateCubit>(
    () => UpdateCubit(engine: getIt<UpdateEngine>()),
  );

  getIt.registerFactory<QiblaCubit>(
    () => QiblaCubit(repository: getIt<QiblaRepository>()),
  );
}
