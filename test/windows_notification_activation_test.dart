import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/core/audio/audio_player_service.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/notifications/app_notification_service.dart';
import 'package:adhan_and_prayer/core/platform/adhan_activation_payload.dart';
import 'package:adhan_and_prayer/features/adhan/domain/services/adhan_playback_coordinator.dart';

class _StubAudioPlayer implements AudioPlayerService {
  @override
  bool get isPlaying => false;
  @override
  double get volume => 1.0;
  @override
  AudioPlaybackContext get currentContext => AudioPlaybackContext.none;
  @override
  Stream<PlayerState> get onPlayerStateChanged => const Stream.empty();
  @override
  Future<Result<void>> playAsset(String assetPath,
          {AudioPlaybackContext context = AudioPlaybackContext.none}) async =>
      const Success(null);
  @override
  Future<Result<void>> playFile(String filePath,
          {AudioPlaybackContext context = AudioPlaybackContext.none}) async =>
      const Success(null);
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> stopPreview() async {}
  @override
  Future<void> dispose() async {}
}

class _StubNotificationService implements AppNotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<Result<void>> showPrayerNotification({
    required int id,
    required String title,
    required String body,
    String? prayerName,
    dynamic onStopPressed,
    dynamic onBodyTapped,
    bool restoreWindowOnClick = true,
  }) async =>
      const Success(null);
  @override
  Future<void> cancelNotification(int id) async {}
  @override
  Future<void> cancelAllNotifications() async {}
}

void main() {
  group('Windows Notification Activation Payload & Coordinator Tests', () {
    test('Structured payload serializes and deserializes through CLI args', () {
      final original = AdhanActivationPayload.create(
        source: 'windows_headless_notification',
        prayerName: 'Fajr',
        eventId: 'evt_fajr_1001',
      );

      final cliArgs = original.toCliArgs();
      expect(cliArgs.length, equals(2));
      expect(cliArgs[0], equals(AdhanActivationPayload.cliFlag));

      final parsed = AdhanActivationPayload.fromCliArgs(cliArgs);
      expect(parsed, equals(original));
      expect(parsed?.prayerName, equals('Fajr'));
      expect(parsed?.source, equals('windows_headless_notification'));
      expect(parsed?.eventId, equals('evt_fajr_1001'));
    });

    test('Invalid or missing CLI args return null without throwing', () {
      expect(AdhanActivationPayload.fromCliArgs([]), isNull);
      expect(
        AdhanActivationPayload.fromCliArgs(['--activate-adhan']),
        isNull,
      );
      expect(
        AdhanActivationPayload.fromCliArgs(['--activate-adhan', 'not-json']),
        isNull,
      );
      expect(
        AdhanActivationPayload.fromCliArgs(['--activate-adhan', '{}']),
        isNull,
      );
    });

    test('Cold-start pending activation is retained until acknowledged', () {
      final coordinator = AdhanPlaybackCoordinatorImpl(
        audioPlayer: _StubAudioPlayer(),
        notificationService: _StubNotificationService(),
      );

      final payload = AdhanActivationPayload.create(
        source: 'windows_headless_notification',
        prayerName: 'Dhuhr',
        eventId: 'evt_dhuhr_cold_1',
      );

      // Enqueue before any UI listener subscribes (simulating cold start before HomeScreen mounts)
      coordinator.enqueueActivation(payload);

      expect(coordinator.pendingActivation, equals(payload));

      // HomeScreen mounts and acknowledges the pending activation
      final newlyConsumed = coordinator.acknowledgeActivation(payload.eventId);
      expect(newlyConsumed, isTrue);
      expect(coordinator.pendingActivation, isNull);

      // Acknowledging the same eventId again returns false (prevents duplicate dialog)
      expect(coordinator.acknowledgeActivation(payload.eventId), isFalse);
    });

    test('Duplicate activation events with same eventId are ignored', () async {
      final coordinator = AdhanPlaybackCoordinatorImpl(
        audioPlayer: _StubAudioPlayer(),
        notificationService: _StubNotificationService(),
      );

      final received = <AdhanActivationPayload>[];
      final sub = coordinator.onActivationRequested.listen(received.add);

      final payload = AdhanActivationPayload.create(
        source: 'windows_single_instance',
        prayerName: 'Asr',
        eventId: 'evt_asr_dup_1',
      );

      coordinator.enqueueActivation(payload);
      coordinator.enqueueActivation(payload); // Duplicate while pending

      await Future<void>.delayed(Duration.zero);
      expect(received.length, equals(1));
      expect(received.first.prayerName, equals('Asr'));

      // Acknowledge and re-send the same eventId (must still be ignored)
      expect(coordinator.acknowledgeActivation(payload.eventId), isTrue);
      coordinator.enqueueActivation(payload);

      await Future<void>.delayed(Duration.zero);
      expect(received.length, equals(1));
      expect(coordinator.pendingActivation, isNull);

      await sub.cancel();
    });

    test('Existing-instance activation delivers prayer identity to active listener', () async {
      final coordinator = AdhanPlaybackCoordinatorImpl(
        audioPlayer: _StubAudioPlayer(),
        notificationService: _StubNotificationService(),
      );

      final received = <AdhanActivationPayload>[];
      final sub = coordinator.onActivationRequested.listen(received.add);

      final payload = AdhanActivationPayload.create(
        source: 'windows_single_instance',
        prayerName: 'Maghrib',
        eventId: 'evt_maghrib_live_1',
      );

      coordinator.enqueueActivation(payload);
      await Future<void>.delayed(Duration.zero);

      expect(received.length, equals(1));
      expect(received.first.prayerName, equals('Maghrib'));
      expect(coordinator.acknowledgeActivation(received.first.eventId), isTrue);

      await sub.cancel();
    });

    test('Headless Windows playback never restores its own empty window on notification click', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      final notifSource =
          File('lib/core/notifications/app_notification_service.dart').readAsStringSync();
      final flutterWindowCpp = File('windows/runner/flutter_window.cpp').readAsStringSync();
      final mainCpp = File('windows/runner/main.cpp').readAsStringSync();

      expect(mainSource, contains('restoreWindowOnClick: false'));
      expect(notifSource, contains('if (restoreWindowOnClick)'));
      expect(flutterWindowCpp, contains('if (is_headless_)'));
      expect(flutterWindowCpp, contains('if (!is_headless_)'));
      expect(mainCpp, contains('FlutterWindow window(project, is_headless_adhan)'));
      expect(mainCpp, contains('adhan_and_prayer_headless'));
    });
  });
}
