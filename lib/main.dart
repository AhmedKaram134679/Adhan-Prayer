import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:adhan_and_prayer/core/audio/audio_player_service.dart';
import 'package:adhan_and_prayer/core/di/injection.dart';
import 'package:adhan_and_prayer/core/localization/app_localizations.dart';
import 'package:adhan_and_prayer/core/notifications/app_notification_service.dart';
import 'package:adhan_and_prayer/core/platform/adhan_activation_payload.dart';
import 'package:adhan_and_prayer/core/platform/windows_headless_adhan_ipc.dart';
import 'package:adhan_and_prayer/core/platform/windows_path_resolver.dart';
import 'package:adhan_and_prayer/core/platform/windows_single_instance.dart';
import 'package:adhan_and_prayer/core/platform/windows_tray_manager.dart';
import 'package:adhan_and_prayer/core/theme/app_theme.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';
import 'package:adhan_and_prayer/features/adhan/data/repositories/audio_repository_impl.dart';
import 'package:adhan_and_prayer/features/adhan/domain/services/adhan_playback_coordinator.dart';
import 'package:adhan_and_prayer/features/adhan/presentation/cubit/audio_cubit.dart';
import 'package:adhan_and_prayer/features/location/presentation/cubit/location_cubit.dart';
import 'package:adhan_and_prayer/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:adhan_and_prayer/features/prayer_times/presentation/cubit/prayer_cubit.dart';
import 'package:adhan_and_prayer/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:adhan_and_prayer/core/update/presentation/cubit/update_cubit.dart';
import 'package:adhan_and_prayer/features/splash/presentation/screens/splash_screen.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup DI
  await setupDependencyInjection();

  // Initialize notifications
  await getIt<AppNotificationService>().initialize();

  // Check if launched by Windows Task Scheduler in background headless mode
  if (Platform.isWindows && args.contains('--play-adhan')) {
    final prayerIndex = args.indexOf('--play-adhan');
    final prayerName = (prayerIndex + 1 < args.length) ? args[prayerIndex + 1] : 'Prayer';
    final reciterAsset = (prayerIndex + 2 < args.length) ? args[prayerIndex + 2] : 'assets/audio/adhan_abdulbasit.mp3';

    // Check if GUI application is currently running (in foreground or minimized to tray)
    if (WindowsSingleInstance.isGuiInstanceRunning()) {
      AppLogger.info(
        'Headless Adhan invoked for $prayerName, but GUI application instance is active. Yielding playback authority to GUI instance.',
        'HEADLESS_MAIN',
      );
      exit(0);
    }

    // Resolve physical Adhan audio asset path in installed application
    final resolvedAudioPath = WindowsPathResolver.resolveAssetPath(reciterAsset);
    AppLogger.info(
      'Headless Adhan launch for $prayerName | requested: $reciterAsset | resolved: $resolvedAudioPath',
      'HEADLESS_MAIN',
    );

    final player = getIt<AudioPlayerService>();
    final sessionId =
        'headless_${prayerName}_${DateTime.now().millisecondsSinceEpoch}_$pid';

    // Start event-driven loopback IPC server so the interactive GUI process can
    // reliably stop this exact playback session when the user clicks Stop in AdhanDialog.
    final controlServer = HeadlessAdhanControlServer(
      sessionId: sessionId,
      onStopRequested: () async {
        AppLogger.info(
          'Headless IPC: Stop confirmed for session $sessionId',
          'HEADLESS_MAIN',
        );
        await player.stop();
        await getIt<AppNotificationService>().cancelAllNotifications();
      },
    );
    final controlPort = await controlServer.start();

    // Show native desktop notification with Stop action and Body click handler.
    // restoreWindowOnClick is false so this headless playback process never shows
    // its own empty FlutterWindow when the user clicks the notification body.
    await getIt<AppNotificationService>().showPrayerNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'حان الآن موعد صلاة $prayerName',
      body: 'It is now time for $prayerName prayer.',
      prayerName: prayerName,
      restoreWindowOnClick: false,
      onStopPressed: () async {
        AppLogger.info('Headless notification: Stop Adhan pressed', 'HEADLESS_MAIN');
        await player.stop();
        await getIt<AppNotificationService>().cancelAllNotifications();
        await controlServer.close();
        exit(0);
      },
      onBodyTapped: () async {
        AppLogger.info('Headless notification: Body tapped, activating GUI instance', 'HEADLESS_MAIN');
        // Launch GUI executable with structured activation payload including
        // sessionId and controlPort so Stop in AdhanDialog stops this exact session.
        final activationPayload = AdhanActivationPayload.create(
          source: 'windows_headless_notification',
          prayerName: prayerName,
          sessionId: sessionId,
          controlPort: controlPort,
        );
        try {
          await Process.start(
            Platform.resolvedExecutable,
            activationPayload.toCliArgs(),
          );
        } catch (e) {
          AppLogger.warning('Error activating GUI from headless mode: $e', 'HEADLESS_MAIN');
        }
      },
    );

    // Load persisted Adhan volume
    final audioRepo = getIt<AudioRepository>();
    final adhanVolume = await audioRepo.getAdhanVolume();
    await player.setVolume(adhanVolume);

    AppLogger.info(
      'Playing headless Adhan with volume: ${(adhanVolume * 100).toInt()}%',
      'HEADLESS_MAIN',
    );

    // Play Adhan audio: if physical file exists on disk, play directly via playFile;
    // otherwise fallback to playAsset. Explicitly mark context as AudioPlaybackContext.adhan.
    if (File(resolvedAudioPath).existsSync()) {
      await player.playFile(resolvedAudioPath, context: AudioPlaybackContext.adhan);
    } else {
      await player.playAsset(reciterAsset, context: AudioPlaybackContext.adhan);
    }

    // Wait until playback completes naturally, IPC Stop is confirmed, or 4-minute safety cap
    await Future.any([
      player.onPlayerStateChanged
          .firstWhere((s) => s.name == 'completed' || s.name == 'stopped'),
      controlServer.onStopped,
      Future.delayed(const Duration(seconds: 240)),
    ]);
    await controlServer.close();
    exit(0);
  }

  // Capture any cold-start activation payload before runApp so it is retained
  // until HomeScreen mounts and consumes it.
  final coordinator = getIt<AdhanPlaybackCoordinator>();
  final initialActivation = AdhanActivationPayload.fromCliArgs(args);
  if (initialActivation != null) {
    AppLogger.info('Captured cold-start activation payload: $initialActivation', 'MAIN');
    coordinator.enqueueActivation(initialActivation);
  }

  // Normal GUI Desktop initialization (without showing native window prematurely)
  if (Platform.isWindows) {
    await WindowsTrayManager().initialize(
      onActivation: (payload) {
        coordinator.enqueueActivation(payload);
      },
    );
  }

  runApp(const AdhanApp());

  // Show and focus the Windows native window only after Flutter's first frame
  // has been scheduled/painted to prevent an intermittent blank white window.
  if (Platform.isWindows) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WindowsTrayManager().showWhenReady();
    });
  }
}

class AdhanApp extends StatelessWidget {
  const AdhanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<OnboardingCubit>(
          create: (_) => getIt<OnboardingCubit>(),
        ),
        BlocProvider<SettingsCubit>(
          create: (_) => getIt<SettingsCubit>()..initialize(),
        ),
        BlocProvider<LocationCubit>(
          create: (_) => getIt<LocationCubit>()..initialize(),
        ),
        BlocProvider<AudioCubit>(
          create: (_) => getIt<AudioCubit>()..initialize(),
        ),
        BlocProvider<PrayerCubit>(
          create: (_) => getIt<PrayerCubit>(),
        ),
        BlocProvider<UpdateCubit>(
          create: (_) => getIt<UpdateCubit>(),
        ),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          return MaterialApp(
            title: 'Adhan & Prayer Times',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            locale: settings.locale,
            supportedLocales: const [
              Locale('en', ''),
              Locale('ar', ''),
            ],
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
