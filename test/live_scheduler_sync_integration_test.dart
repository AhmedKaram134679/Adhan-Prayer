import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan_and_prayer/core/audio/audio_player_service.dart';
import 'package:adhan_and_prayer/core/di/injection.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/notifications/app_notification_service.dart';
import 'package:adhan_and_prayer/core/platform/adhan_scheduler_service.dart';
import 'package:adhan_and_prayer/core/storage/local_storage.dart';
import 'package:adhan_and_prayer/features/adhan/data/repositories/audio_repository_impl.dart';
import 'package:adhan_and_prayer/features/adhan/domain/services/adhan_playback_coordinator.dart';
import 'package:adhan_and_prayer/features/location/data/repositories/location_repository_impl.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_calculation_engine.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import 'package:adhan_and_prayer/features/prayer_times/presentation/cubit/prayer_cubit.dart';

class MockAudioPlayerService implements AudioPlayerService {
  @override
  bool get isPlaying => false;
  @override
  double get volume => 1.0;
  @override
  AudioPlaybackContext get currentContext => AudioPlaybackContext.none;
  @override
  Stream<PlayerState> get onPlayerStateChanged => const Stream.empty();
  @override
  Future<Result<void>> playAsset(String assetPath, {AudioPlaybackContext context = AudioPlaybackContext.none}) async => const Success(null);
  @override
  Future<Result<void>> playFile(String filePath, {AudioPlaybackContext context = AudioPlaybackContext.none}) async => const Success(null);
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> stopPreview() async {}
  @override
  Future<void> dispose() async {}
}

class MockAppNotificationService implements AppNotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<Result<void>> showPrayerNotification({required int id, required String title, required String body, String? prayerName, dynamic onStopPressed, dynamic onBodyTapped}) async => const Success(null);
  @override
  Future<void> cancelNotification(int id) async {}
  @override
  Future<void> cancelAllNotifications() async {}
}

class MockAdhanPlaybackCoordinator implements AdhanPlaybackCoordinator {
  @override
  bool get isAdhanActive => false;
  @override
  String? get activePrayerName => null;
  @override
  Stream<String> get onShowAdhanDialogRequested => const Stream.empty();
  @override
  Stream<bool> get onAdhanActiveChanged => const Stream.empty();
  @override
  void markAdhanStarted(String prayerName) {}
  @override
  void markAdhanFinished() {}
  @override
  Future<void> stopCurrentAdhan() async {}
  @override
  void requestShowAdhanDialog(String prayerName) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Live Windows Task Scheduler reconciliation updates task arguments to new reciter', () async {
    if (!Platform.isWindows) return;

    SharedPreferences.setMockInitialValues({
      'selected_country_code': 'EG',
      'selected_city_id': 'eg_cairo',
      'selected_reciter_id': 'makkah',
    });

    // 1. Setup DI with mocked audio player
    getIt.registerSingleton<AudioPlayerService>(MockAudioPlayerService());
    getIt.registerSingleton<AppNotificationService>(MockAppNotificationService());
    getIt.registerSingleton<AdhanPlaybackCoordinator>(MockAdhanPlaybackCoordinator());
    getIt.registerSingleton<AdhanSchedulerService>(AdhanSchedulerServiceImpl());

    final sharedPrefs = await SharedPreferences.getInstance();
    getIt.registerSingleton<LocalStorage>(SharedPreferencesStorage(sharedPrefs));

    getIt.registerLazySingleton<PrayerCalculationEngine>(() => AdhanPrayerCalculationEngine());
    getIt.registerLazySingleton<LocationRepository>(() => LocationRepositoryImpl(getIt<LocalStorage>()));
    getIt.registerLazySingleton<PrayerTimesRepository>(
      () => PrayerTimesRepositoryImpl(
        engine: getIt<PrayerCalculationEngine>(),
        storage: getIt<LocalStorage>(),
      ),
    );
    getIt.registerLazySingleton<AudioRepository>(() => AudioRepositoryImpl(getIt<LocalStorage>()));
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

    // 2. Select Makkah reciter
    final audioRepo = getIt<AudioRepository>();
    final reciters = await audioRepo.getReciters();
    final makkah = reciters.firstWhere((r) => r.id == 'makkah');
    final madinah = reciters.firstWhere((r) => r.id == 'madinah');

    await audioRepo.saveSelectedReciter(makkah);

    // 3. Load prayer times and reconcile schedules
    final prayerCubit = getIt<PrayerCubit>();
    await prayerCubit.loadPrayerTimes();

    // 4. Verify initial task arguments contain makkah
    final resultMakkah = await Process.run('powershell', [
      '-ExecutionPolicy', 'Bypass',
      '-Command',
      r'$now = Get-Date; (Get-ScheduledTask | Where-Object { $_.TaskName -like "*Adhan*" -and $_.Actions.Arguments -match "adhan_" } | Sort-Object TaskName -Descending)[0].Actions.Arguments',
    ]);
    final initialArgs = (resultMakkah.stdout as String).trim();
    expect(initialArgs, contains('adhan_makkah.mp3'));

    // 5. User changes reciter to Madinah and caller triggers loadPrayerTimes(isRefresh: true)
    await audioRepo.saveSelectedReciter(madinah);
    await prayerCubit.loadPrayerTimes(isRefresh: true);

    // 6. Verify Task Scheduler arguments now contain madinah
    final resultMadinah = await Process.run('powershell', [
      '-ExecutionPolicy', 'Bypass',
      '-Command',
      r'(Get-ScheduledTask | Where-Object { $_.TaskName -like "*Adhan*" -and $_.Actions.Arguments -match "adhan_" } | Sort-Object TaskName -Descending)[0].Actions.Arguments',
    ]);
    final updatedArgs = (resultMadinah.stdout as String).trim();
    expect(updatedArgs, contains('adhan_madinah.mp3'));

    // 7. Verify reverse transition: Madinah -> Makkah
    await audioRepo.saveSelectedReciter(makkah);
    await prayerCubit.loadPrayerTimes(isRefresh: true);

    final resultReverted = await Process.run('powershell', [
      '-ExecutionPolicy', 'Bypass',
      '-Command',
      r'(Get-ScheduledTask | Where-Object { $_.TaskName -like "*Adhan*" -and $_.Actions.Arguments -match "adhan_" } | Sort-Object TaskName -Descending)[0].Actions.Arguments',
    ]);
    final revertedArgs = (resultReverted.stdout as String).trim();
    expect(revertedArgs, contains('adhan_makkah.mp3'));
  });
}
