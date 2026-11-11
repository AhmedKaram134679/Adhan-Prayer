import 'dart:async';
import 'dart:io';
import 'package:adhan_and_prayer/features/prayer_times/domain/services/location_calculation_method_resolver.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/notifications/app_notification_service.dart';
import 'package:adhan_and_prayer/core/platform/adhan_scheduler_service.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';
import 'package:adhan_and_prayer/features/adhan/data/repositories/audio_repository_impl.dart';
import 'package:adhan_and_prayer/features/location/data/repositories/location_repository_impl.dart';
import 'package:adhan_and_prayer/features/location/domain/entities/location_entities.dart';
import 'package:adhan_and_prayer/features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/calculation_settings.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/countdown_time.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/prayer_entities.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/prayer_state_engine.dart';
import 'package:adhan_and_prayer/core/audio/audio_player_service.dart';
import 'package:adhan_and_prayer/features/adhan/domain/services/adhan_playback_coordinator.dart';

sealed class PrayerState {
  const PrayerState();
}

class PrayerInitialState extends PrayerState {}

class PrayerLoadingState extends PrayerState {}

class PrayerLoadedState extends PrayerState {
  final City city;
  final Country country;
  final DailyPrayerTimes todayTimes;
  final DailyPrayerTimes tomorrowTimes;
  final PrayerItem? currentPrayer;
  final PrayerItem nextPrayer;
  final DateTime nextPrayerTime;
  final CountdownTime countdown;
  final CalculationSettings calculationSettings;
  final Map<PrayerType, bool> perPrayerAdhan;
  final bool globalAdhanEnabled;

  const PrayerLoadedState({
    required this.city,
    required this.country,
    required this.todayTimes,
    required this.tomorrowTimes,
    required this.currentPrayer,
    required this.nextPrayer,
    required this.nextPrayerTime,
    required this.countdown,
    required this.calculationSettings,
    required this.perPrayerAdhan,
    required this.globalAdhanEnabled,
  });

  PrayerLoadedState copyWith({
    City? city,
    Country? country,
    DailyPrayerTimes? todayTimes,
    DailyPrayerTimes? tomorrowTimes,
    PrayerItem? currentPrayer,
    PrayerItem? nextPrayer,
    DateTime? nextPrayerTime,
    CountdownTime? countdown,
    CalculationSettings? calculationSettings,
    Map<PrayerType, bool>? perPrayerAdhan,
    bool? globalAdhanEnabled,
  }) {
    return PrayerLoadedState(
      city: city ?? this.city,
      country: country ?? this.country,
      todayTimes: todayTimes ?? this.todayTimes,
      tomorrowTimes: tomorrowTimes ?? this.tomorrowTimes,
      currentPrayer: currentPrayer ?? this.currentPrayer,
      nextPrayer: nextPrayer ?? this.nextPrayer,
      nextPrayerTime: nextPrayerTime ?? this.nextPrayerTime,
      countdown: countdown ?? this.countdown,
      calculationSettings: calculationSettings ?? this.calculationSettings,
      perPrayerAdhan: perPrayerAdhan ?? this.perPrayerAdhan,
      globalAdhanEnabled: globalAdhanEnabled ?? this.globalAdhanEnabled,
    );
  }
}

class PrayerErrorState extends PrayerState {
  final String message;
  const PrayerErrorState(this.message);
}

class PrayerCubit extends Cubit<PrayerState> {
  final PrayerTimesRepository prayerRepo;
  final LocationRepository locationRepo;
  final AudioRepository audioRepo;
  final AdhanSchedulerService schedulerService;
  final AppNotificationService notificationService;
  final AudioPlayerService audioPlayer;
  final AdhanPlaybackCoordinator coordinator;

  Timer? _countdownTimer;
  DateTime? _lastEvaluatedDate;
  final Set<String> _playedPrayers = {};

  PrayerCubit({
    required this.prayerRepo,
    required this.locationRepo,
    required this.audioRepo,
    required this.schedulerService,
    required this.notificationService,
    required this.audioPlayer,
    required this.coordinator,
  }) : super(PrayerInitialState());

  Future<void> loadPrayerTimes({bool isRefresh = false}) async {
    if (!isRefresh && state is PrayerLoadingState) return;
    emit(PrayerLoadingState());

    try {
      final city = await locationRepo.getSelectedCity();
      final country = await locationRepo.getSelectedCountry();

      if (city == null || country == null) {
        emit(const PrayerErrorState('No location selected'));
        return;
      }

      final now = DateTime.now();
      _lastEvaluatedDate = DateTime(now.year, now.month, now.day);
      final tomorrow = now.add(const Duration(days: 1));

      var calcSettings = await prayerRepo.getCalculationSettings();
      final perPrayerAdhan = await prayerRepo.getPerPrayerAdhanSettings();
      final globalAdhan = await prayerRepo.getGlobalAdhanEnabled();

      // Automatic Calculation Method Resolution
      if (calcSettings.mode == CalculationMethodMode.automatic) {
        final recommendedMethod = LocationCalculationMethodResolver.resolve(
          country: country,
          city: city,
        );
        if (calcSettings.method != recommendedMethod) {
          AppLogger.info(
            'Auto-switching calculation method for ${city.nameEn}, ${country.nameEn}: '
            '${calcSettings.method.name} -> ${recommendedMethod.name}',
            'PRAYER_CUBIT',
          );
          calcSettings = calcSettings.copyWith(method: recommendedMethod);
          await prayerRepo.saveCalculationSettings(calcSettings);
        }
      }

      final todayResult = await prayerRepo.getPrayerTimes(
        city: city,
        date: now,
        settings: calcSettings,
      );
      final tomorrowResult = await prayerRepo.getPrayerTimes(
        city: city,
        date: tomorrow,
        settings: calcSettings,
      );

      if (todayResult is Failure || tomorrowResult is Failure) {
        emit(const PrayerErrorState('Failed to calculate prayer times'));
        return;
      }

      final todayTimes = (todayResult as Success<DailyPrayerTimes>).data;
      final tomorrowTimes = (tomorrowResult as Success<DailyPrayerTimes>).data;

      final prayerState = PrayerStateEngine.resolvePrayerState(
        todayTimes: todayTimes,
        tomorrowTimes: tomorrowTimes,
        now: now,
      );

      final diff = prayerState.nextPrayerTime.difference(now);
      final countdown = CountdownTime.fromDuration(diff);

      emit(
        PrayerLoadedState(
          city: city,
          country: country,
          todayTimes: todayTimes,
          tomorrowTimes: tomorrowTimes,
          currentPrayer: prayerState.currentPrayer,
          nextPrayer: prayerState.nextPrayer,
          nextPrayerTime: prayerState.nextPrayerTime,
          countdown: countdown,
          calculationSettings: calcSettings,
          perPrayerAdhan: perPrayerAdhan,
          globalAdhanEnabled: globalAdhan,
        ),
      );

      // Reconcile and schedule OS alarms
      await reconcileSchedules(todayTimes, tomorrowTimes);

      // Start tick timer
      _startCountdownTimer();
    } catch (e, stack) {
      AppLogger.error('Error loading prayer times', e, stack, 'PRAYER_CUBIT');
      emit(PrayerErrorState(e.toString()));
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tick();
    });
  }

  void _tick() {
    final currentState = state;
    if (currentState is! PrayerLoadedState) return;

    final now = DateTime.now();

    // 1. Check for Midnight / Date Transition
    final today = DateTime(now.year, now.month, now.day);
    if (_lastEvaluatedDate != null && !today.isAtSameMomentAs(_lastEvaluatedDate!)) {
      AppLogger.info('Midnight date transition detected. Refreshing prayer times.', 'PRAYER_CUBIT');
      loadPrayerTimes(isRefresh: true);
      return;
    }

    // 2. Check if next prayer target is reached
    final diff = currentState.nextPrayerTime.difference(now);
    if (diff.inSeconds <= 0) {
      _handlePrayerReached(currentState, now);
      return;
    }

    // Update countdown smoothly without full tree rebuilding
    emit(currentState.copyWith(countdown: CountdownTime.fromDuration(diff)));
  }

  Future<void> _handlePrayerReached(PrayerLoadedState currentState, DateTime now) async {
    final reachedPrayer = currentState.nextPrayer;
    final prayerKey = '${reachedPrayer.type.name}_${currentState.nextPrayerTime.day}_${currentState.nextPrayerTime.month}';

    // Prevent duplicate playback in same minute
    if (!_playedPrayers.contains(prayerKey)) {
      _playedPrayers.add(prayerKey);
      AppLogger.info('Prayer time reached for: ${reachedPrayer.nameEn}', 'PRAYER_CUBIT');

      // Check Adhan settings
      final isEnabled = currentState.globalAdhanEnabled &&
          (currentState.perPrayerAdhan[reachedPrayer.type] ?? true);

      // On Android, OS-level AlarmManager and AdhanAlarmReceiver are the authoritative source
      // for scheduled prayer alarms and notifications, ensuring reliable locked-screen/background execution
      // without duplicate audio playback or duplicate notifications.
      // On Windows / other desktop platforms, Flutter in-process handles the active trigger.
      if (isEnabled && reachedPrayer.isObligatory && !Platform.isAndroid) {
        // Mark Adhan active in centralized coordinator
        coordinator.markAdhanStarted(reachedPrayer.nameEn);

        // Trigger In-App Notification and Audio (Windows / Desktop)
        notificationService.showPrayerNotification(
          id: reachedPrayer.type.index,
          title: 'Prayer Time: ${reachedPrayer.nameEn}',
          body: 'It is now time for ${reachedPrayer.nameEn} prayer (${currentState.city.nameEn}).',
          prayerName: reachedPrayer.nameEn,
          onStopPressed: () {
            coordinator.stopCurrentAdhan();
          },
          onBodyTapped: () {
            coordinator.requestShowAdhanDialog(reachedPrayer.nameEn);
          },
        );

        final reciter = await audioRepo.getSelectedReciter();
        final volume = await audioRepo.getAdhanVolume();
        await audioPlayer.setVolume(volume);
        await audioPlayer.playAsset(
          reciter.assetPath,
          context: AudioPlaybackContext.adhan,
        );
      }
    }

    // Advance to next prayer state
    final nextState = PrayerStateEngine.resolvePrayerState(
      todayTimes: currentState.todayTimes,
      tomorrowTimes: currentState.tomorrowTimes,
      now: now,
    );

    final newDiff = nextState.nextPrayerTime.difference(now);
    emit(
      currentState.copyWith(
        currentPrayer: nextState.currentPrayer,
        nextPrayer: nextState.nextPrayer,
        nextPrayerTime: nextState.nextPrayerTime,
        countdown: CountdownTime.fromDuration(newDiff),
      ),
    );
  }

  Future<void> reconcileSchedules(
    DailyPrayerTimes todayTimes,
    DailyPrayerTimes tomorrowTimes,
  ) async {
    try {
      final now = DateTime.now();
      final reciter = await audioRepo.getSelectedReciter();
      final globalAdhan = await prayerRepo.getGlobalAdhanEnabled();
      final perPrayer = await prayerRepo.getPerPrayerAdhanSettings();

      final alarms = <ScheduledPrayerAlarm>[];

      void addIfUpcoming(PrayerItem prayer) {
        if (prayer.isObligatory && prayer.time.isAfter(now)) {
          final isEnabled = globalAdhan && (perPrayer[prayer.type] ?? true);
          alarms.add(
            ScheduledPrayerAlarm(
              id: prayer.time.millisecondsSinceEpoch ~/ 1000,
              prayerName: prayer.nameEn,
              scheduledTime: prayer.time,
              reciterAssetPath: reciter.assetPath,
              isAdhanEnabled: isEnabled,
            ),
          );
        }
      }

      for (final p in todayTimes.toList()) {
        addIfUpcoming(p);
      }
      for (final p in tomorrowTimes.toList()) {
        addIfUpcoming(p);
      }

      await schedulerService.schedulePrayers(alarms);
      AppLogger.info('Reconciled and scheduled ${alarms.length} upcoming alarms', 'PRAYER_CUBIT');
    } catch (e, stack) {
      AppLogger.error('Failed to reconcile schedules', e, stack, 'PRAYER_CUBIT');
    }
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    return super.close();
  }
}
