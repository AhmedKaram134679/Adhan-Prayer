import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:adhan_and_prayer/core/audio/audio_player_service.dart';
import 'package:adhan_and_prayer/core/notifications/app_notification_service.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';

/// Centralized coordinator for managing active Adhan playback state,
/// handling notification interaction events, and performing the centralized
/// idempotent `stopCurrentAdhan()` operation across Flutter in-process audio
/// and native Android MediaPlayer.
abstract class AdhanPlaybackCoordinator {
  /// Whether an Adhan is currently playing/active
  bool get isAdhanActive;

  /// The active prayer name for the currently playing Adhan, if any
  String? get activePrayerName;

  /// Stream emitting active Adhan state changes (true = playing, false = stopped/ended)
  Stream<bool> get onAdhanActiveChanged;

  /// Stream emitting notification body tap events requesting to show the Adhan dialog
  Stream<String> get onShowAdhanDialogRequested;

  /// Marks an Adhan session as started with the given prayer name
  void markAdhanStarted(String prayerName);

  /// Marks an Adhan session as completed/finished naturally
  void markAdhanFinished();

  /// Requests the UI to display the Adhan Dialog (e.g. upon notification body click)
  void requestShowAdhanDialog(String prayerName);

  /// Centralized, idempotent stop operation.
  /// Stops the currently active Adhan without stopping unrelated Preview playback.
  /// Works across Android native MediaPlayer and Flutter audio players.
  Future<void> stopCurrentAdhan();
}

class AdhanPlaybackCoordinatorImpl implements AdhanPlaybackCoordinator {
  final AudioPlayerService audioPlayer;
  final AppNotificationService notificationService;

  static const MethodChannel _alarmChannel =
      MethodChannel('com.example.adhan_and_prayer/alarm');

  bool _isAdhanActive = false;
  String? _activePrayerName;

  final StreamController<bool> _activeChangedController =
      StreamController<bool>.broadcast();
  final StreamController<String> _showDialogController =
      StreamController<String>.broadcast();

  AdhanPlaybackCoordinatorImpl({
    required this.audioPlayer,
    required this.notificationService,
  }) {
    // Listen to in-process audio player state changes
    audioPlayer.onPlayerStateChanged.listen((state) {
      if (audioPlayer.currentContext == AudioPlaybackContext.adhan) {
        if (state.name == 'completed' || state.name == 'stopped') {
          if (_isAdhanActive) {
            markAdhanFinished();
          }
        }
      }
    });
  }

  @override
  bool get isAdhanActive => _isAdhanActive;

  @override
  String? get activePrayerName => _activePrayerName;

  @override
  Stream<bool> get onAdhanActiveChanged => _activeChangedController.stream;

  @override
  Stream<String> get onShowAdhanDialogRequested =>
      _showDialogController.stream;

  @override
  void markAdhanStarted(String prayerName) {
    _isAdhanActive = true;
    _activePrayerName = prayerName;
    _activeChangedController.add(true);
    AppLogger.info(
      'AdhanPlaybackCoordinator: Adhan started for $prayerName',
      'COORDINATOR',
    );
  }

  @override
  void markAdhanFinished() {
    if (!_isAdhanActive && _activePrayerName == null) return;
    _isAdhanActive = false;
    _activePrayerName = null;
    _activeChangedController.add(false);
    AppLogger.info(
      'AdhanPlaybackCoordinator: Adhan finished / cleared',
      'COORDINATOR',
    );
  }

  @override
  void requestShowAdhanDialog(String prayerName) {
    AppLogger.info(
      'AdhanPlaybackCoordinator: show Adhan Dialog requested for $prayerName',
      'COORDINATOR',
    );
    _showDialogController.add(prayerName);
  }

  @override
  Future<void> stopCurrentAdhan() async {
    AppLogger.info(
      'AdhanPlaybackCoordinator: stopCurrentAdhan() invoked (active: $_isAdhanActive)',
      'COORDINATOR',
    );

    // 1. Android Native MediaPlayer Stop
    if (Platform.isAndroid) {
      try {
        await _alarmChannel.invokeMethod('stopAdhan');
        AppLogger.info(
          'AdhanPlaybackCoordinator: Sent stopAdhan to Android native channel',
          'COORDINATOR',
        );
      } catch (e, stack) {
        AppLogger.error(
          'AdhanPlaybackCoordinator: Error invoking native stopAdhan',
          e,
          stack,
          'COORDINATOR',
        );
      }
    }

    // 2. Flutter in-process AudioPlayer Stop
    // CRITICAL: Only stop if current context is adhan. NEVER terminate preview!
    if (audioPlayer.currentContext == AudioPlaybackContext.adhan) {
      await audioPlayer.stop();
      AppLogger.info(
        'AdhanPlaybackCoordinator: Stopped Flutter in-process Adhan playback',
        'COORDINATOR',
      );
    }

    // 3. Clear active state idempotently
    markAdhanFinished();

    // 4. Clean up notifications so notification does not outlive stopped playback
    try {
      await notificationService.cancelAllNotifications();
    } catch (e) {
      AppLogger.warning(
        'AdhanPlaybackCoordinator: Failed to cancel notifications on stop: $e',
        'COORDINATOR',
      );
    }
  }
}
