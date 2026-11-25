import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/core/audio/audio_player_service.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/notifications/app_notification_service.dart';
import 'package:adhan_and_prayer/core/platform/adhan_activation_payload.dart';
import 'package:adhan_and_prayer/core/platform/windows_headless_adhan_ipc.dart';
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
  int cancelAllCalls = 0;

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
  Future<void> cancelAllNotifications() async {
    cancelAllCalls++;
  }
}

void main() {
  group('Windows Headless Adhan Stop IPC Tests', () {
    test('1. Stop command from GUI stops the targeted headless playback session and updates coordinator', () async {
      var headlessStopCount = 0;
      final server = HeadlessAdhanControlServer(
        sessionId: 'headless_Dhuhr_1001',
        onStopRequested: () async {
          headlessStopCount++;
        },
      );
      final port = await server.start();

      try {
        final coordinator = AdhanPlaybackCoordinatorImpl(
          audioPlayer: _StubAudioPlayer(),
          notificationService: _StubNotificationService(),
        );

        final payload = AdhanActivationPayload.create(
          source: 'windows_headless_notification',
          prayerName: 'Dhuhr',
          eventId: 'evt_dhuhr_ipc_1',
          sessionId: 'headless_Dhuhr_1001',
          controlPort: port,
        );

        coordinator.enqueueActivation(payload);
        expect(coordinator.isAdhanActive, isTrue);
        expect(coordinator.activePrayerName, equals('Dhuhr'));

        await coordinator.stopCurrentAdhan();

        expect(headlessStopCount, equals(1));
        expect(server.isStopped, isTrue);
        expect(coordinator.isAdhanActive, isFalse);
        expect(coordinator.activePrayerName, isNull);
      } finally {
        await server.close();
      }
    });

    test('2. Duplicate Stop commands are idempotent and only invoke stop handler once', () async {
      var headlessStopCount = 0;
      final server = HeadlessAdhanControlServer(
        sessionId: 'headless_Asr_2002',
        onStopRequested: () async {
          headlessStopCount++;
        },
      );
      final port = await server.start();

      try {
        final first = await HeadlessAdhanControlClient.sendStop(
          port: port,
          sessionId: 'headless_Asr_2002',
        );
        final second = await HeadlessAdhanControlClient.sendStop(
          port: port,
          sessionId: 'headless_Asr_2002',
        );

        expect(first.status, equals(HeadlessStopStatus.stopped));
        expect(second.status, equals(HeadlessStopStatus.alreadyStopped));
        expect(headlessStopCount, equals(1));
      } finally {
        await server.close();
      }
    });

    test('3. Stale or mismatched sessionId is rejected and does NOT stop active playback', () async {
      var headlessStopCount = 0;
      final server = HeadlessAdhanControlServer(
        sessionId: 'headless_Maghrib_3003',
        onStopRequested: () async {
          headlessStopCount++;
        },
      );
      final port = await server.start();

      try {
        final result = await HeadlessAdhanControlClient.sendStop(
          port: port,
          sessionId: 'headless_Fajr_STALE',
        );

        expect(result.status, equals(HeadlessStopStatus.rejectedSessionMismatch));
        expect(result.isStoppedOrGone, isFalse);
        expect(headlessStopCount, equals(0));
        expect(server.isStopped, isFalse);
      } finally {
        await server.close();
      }
    });

    test('4. IPC disconnection / already terminated headless process is handled safely', () async {
      final server = HeadlessAdhanControlServer(
        sessionId: 'headless_Isha_4004',
        onStopRequested: () async {},
      );
      final port = await server.start();
      // Simulate headless process already exited before Stop was clicked
      await server.close();

      final result = await HeadlessAdhanControlClient.sendStop(
        port: port,
        sessionId: 'headless_Isha_4004',
      );

      expect(result.status, equals(HeadlessStopStatus.unreachable));
      expect(result.isStoppedOrGone, isTrue);
    });

    test('5. Normal playback completion closes server cleanly without a Stop command', () async {
      var headlessStopCount = 0;
      final server = HeadlessAdhanControlServer(
        sessionId: 'headless_Fajr_5005',
        onStopRequested: () async {
          headlessStopCount++;
        },
      );
      await server.start();
      expect(server.isRunning, isTrue);

      await server.close();
      expect(server.isRunning, isFalse);
      expect(server.isStopped, isFalse);
      expect(headlessStopCount, equals(0));
    });

    test('6. Stop command for Session A does not affect unrelated Session B', () async {
      var stopCountA = 0;
      var stopCountB = 0;

      final serverA = HeadlessAdhanControlServer(
        sessionId: 'headless_Dhuhr_A',
        onStopRequested: () async {
          stopCountA++;
        },
      );
      final serverB = HeadlessAdhanControlServer(
        sessionId: 'headless_Asr_B',
        onStopRequested: () async {
          stopCountB++;
        },
      );

      final portA = await serverA.start();
      await serverB.start();

      try {
        final resultA = await HeadlessAdhanControlClient.sendStop(
          port: portA,
          sessionId: 'headless_Dhuhr_A',
        );

        expect(resultA.status, equals(HeadlessStopStatus.stopped));
        expect(stopCountA, equals(1));
        expect(stopCountB, equals(0));
        expect(serverB.isStopped, isFalse);
      } finally {
        await serverA.close();
        await serverB.close();
      }
    });

    test('7. AdhanActivationPayload preserves sessionId and controlPort through CLI args', () {
      final original = AdhanActivationPayload.create(
        source: 'windows_headless_notification',
        prayerName: 'Fajr',
        eventId: 'evt_fajr_7007',
        sessionId: 'headless_Fajr_7007',
        controlPort: 54321,
      );

      final parsed = AdhanActivationPayload.fromCliArgs(original.toCliArgs());
      expect(parsed, equals(original));
      expect(parsed?.hasHeadlessControl, isTrue);
      expect(parsed?.sessionId, equals('headless_Fajr_7007'));
      expect(parsed?.controlPort, equals(54321));
    });
  });
}
