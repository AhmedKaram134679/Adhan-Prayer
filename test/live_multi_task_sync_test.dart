import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan_and_prayer/core/platform/adhan_scheduler_service.dart';
import 'package:adhan_and_prayer/core/storage/local_storage.dart';
import 'package:adhan_and_prayer/features/adhan/data/repositories/audio_repository_impl.dart';
import 'package:adhan_and_prayer/features/adhan/presentation/cubit/audio_cubit.dart';
import 'package:adhan_and_prayer/features/location/data/repositories/location_repository_impl.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_calculation_engine.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import 'package:adhan_and_prayer/features/prayer_times/presentation/cubit/prayer_cubit.dart';
import 'live_scheduler_sync_integration_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Multi-task verification: Makkah -> Madinah updates all tasks without restart', () async {
    if (!Platform.isWindows) return;

    SharedPreferences.setMockInitialValues({
      'selected_country_code': 'EG',
      'selected_city_id': 'eg_cairo',
      'selected_reciter_id': 'makkah',
    });

    final sharedPrefs = await SharedPreferences.getInstance();
    final localStorage = SharedPreferencesStorage(sharedPrefs);
    final audioRepo = AudioRepositoryImpl(localStorage);
    final mockPlayer = MockAudioPlayerService();
    final mockNotif = MockAppNotificationService();
    final mockCoord = MockAdhanPlaybackCoordinator();
    final scheduler = AdhanSchedulerServiceImpl();
    final calcEngine = AdhanPrayerCalculationEngine();
    final locationRepo = LocationRepositoryImpl(localStorage);
    final prayerRepo = PrayerTimesRepositoryImpl(engine: calcEngine, storage: localStorage);

    final prayerCubit = PrayerCubit(
      prayerRepo: prayerRepo,
      locationRepo: locationRepo,
      audioRepo: audioRepo,
      schedulerService: scheduler,
      notificationService: mockNotif,
      audioPlayer: mockPlayer,
      coordinator: mockCoord,
    );

    final audioCubit = AudioCubit(
      audioRepo: audioRepo,
      audioPlayer: mockPlayer,
    );
    await audioCubit.initialize();

    // Initial load: Makkah
    await prayerCubit.loadPrayerTimes();

    final reciters = await audioRepo.getReciters();
    final makkah = reciters.firstWhere((r) => r.id == 'makkah');
    final madinah = reciters.firstWhere((r) => r.id == 'madinah');

    // Simulate User changing reciter in AudioCubit
    await audioCubit.selectReciter(madinah);

    // Caller (HomeScreen / SettingsScreen) receives changed == true and triggers:
    await prayerCubit.loadPrayerTimes(isRefresh: true);

    // Query newly reconciled Adhan tasks
    final queryRes = await Process.run('powershell', [
      '-ExecutionPolicy', 'Bypass',
      '-Command',
      r'$tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*Adhan*" -and $_.Actions.Arguments -match "adhan_" -and $_.TaskName -match "20260913" }; foreach ($t in $tasks) { Write-Host "$($t.TaskName) ==>$($t.Actions.Arguments)" }',
    ]);

    final output = (queryRes.stdout as String);
    expect(output, contains('adhan_madinah.mp3'));
    expect(output.contains('adhan_makkah.mp3'), isFalse, reason: 'Zero tasks should have old makkah reciter');

    // Verify Reverse Transition: Madinah -> Makkah
    await audioCubit.selectReciter(makkah);
    await prayerCubit.loadPrayerTimes(isRefresh: true);

    final reverseRes = await Process.run('powershell', [
      '-ExecutionPolicy', 'Bypass',
      '-Command',
      r'$tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*Adhan*" -and $_.Actions.Arguments -match "adhan_" -and $_.TaskName -match "20260913" }; foreach ($t in $tasks) { Write-Host "$($t.TaskName) ==>$($t.Actions.Arguments)" }',
    ]);

    final reverseOutput = (reverseRes.stdout as String);
    expect(reverseOutput, contains('adhan_makkah.mp3'));
    expect(reverseOutput.contains('adhan_madinah.mp3'), isFalse, reason: 'Zero tasks should have madinah reciter after reversion');
  });
}
