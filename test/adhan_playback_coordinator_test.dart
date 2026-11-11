import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/core/audio/audio_player_service.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/notifications/app_notification_service.dart';
import 'package:adhan_and_prayer/features/adhan/domain/services/adhan_playback_coordinator.dart';
import 'package:audioplayers/audioplayers.dart';

class MockAudioPlayerService implements AudioPlayerService {
  AudioPlaybackContext _context = AudioPlaybackContext.none;
  bool _isPlaying = false;
  double _volume = 1.0;
  final StreamController<PlayerState> _stateController =
      StreamController<PlayerState>.broadcast();

  int stopCallCount = 0;
  int stopPreviewCallCount = 0;

  @override
  AudioPlaybackContext get currentContext => _context;

  @override
  bool get isPlaying => _isPlaying;

  @override
  double get volume => _volume;

  @override
  Stream<PlayerState> get onPlayerStateChanged => _stateController.stream;

  @override
  Future<Result<void>> playAsset(String assetPath,
      {AudioPlaybackContext context = AudioPlaybackContext.none}) async {
    _context = context;
    _isPlaying = true;
    _stateController.add(PlayerState.playing);
    return const Success(null);
  }

  @override
  Future<Result<void>> playFile(String filePath,
      {AudioPlaybackContext context = AudioPlaybackContext.none}) async {
    _context = context;
    _isPlaying = true;
    _stateController.add(PlayerState.playing);
    return const Success(null);
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    _isPlaying = false;
    _context = AudioPlaybackContext.none;
    _stateController.add(PlayerState.stopped);
  }

  @override
  Future<void> stopPreview() async {
    stopPreviewCallCount++;
    if (_context == AudioPlaybackContext.preview) {
      await stop();
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }

  void simulateNaturalCompletion() {
    _isPlaying = false;
    _stateController.add(PlayerState.completed);
  }
}

class MockAppNotificationService implements AppNotificationService {
  int cancelAllCount = 0;

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
  }) async {
    return const Success(null);
  }

  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<void> cancelAllNotifications() async {
    cancelAllCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioPlayerService mockAudioPlayer;
  late MockAppNotificationService mockNotificationService;
  late AdhanPlaybackCoordinatorImpl coordinator;

  setUp(() {
    mockAudioPlayer = MockAudioPlayerService();
    mockNotificationService = MockAppNotificationService();
    coordinator = AdhanPlaybackCoordinatorImpl(
      audioPlayer: mockAudioPlayer,
      notificationService: mockNotificationService,
    );
  });

  tearDown(() async {
    await mockAudioPlayer.dispose();
  });

  group('AdhanPlaybackCoordinator & Centralized Stop Semantics', () {
    test('1. Initial state is inactive with no active prayer', () {
      expect(coordinator.isAdhanActive, isFalse);
      expect(coordinator.activePrayerName, isNull);
    });

    test('2. markAdhanStarted activates state and updates activePrayerName', () {
      coordinator.markAdhanStarted('Dhuhr');
      expect(coordinator.isAdhanActive, isTrue);
      expect(coordinator.activePrayerName, equals('Dhuhr'));
    });

    test('3. stopCurrentAdhan stops active Adhan and clears active state', () async {
      await mockAudioPlayer.playAsset('assets/audio/adhan.mp3',
          context: AudioPlaybackContext.adhan);
      coordinator.markAdhanStarted('Asr');

      expect(coordinator.isAdhanActive, isTrue);

      await coordinator.stopCurrentAdhan();

      expect(coordinator.isAdhanActive, isFalse);
      expect(coordinator.activePrayerName, isNull);
      expect(mockAudioPlayer.stopCallCount, equals(1));
      expect(mockNotificationService.cancelAllCount, equals(1));
    });

    test('4. Idempotence: Calling stopCurrentAdhan when no Adhan is active does not crash and does not stop audio', () async {
      expect(coordinator.isAdhanActive, isFalse);

      await coordinator.stopCurrentAdhan();

      expect(coordinator.isAdhanActive, isFalse);
      expect(mockAudioPlayer.stopCallCount, equals(0));
    });

    test('5. Repeated Stop calls are idempotent', () async {
      await mockAudioPlayer.playAsset('assets/audio/adhan.mp3',
          context: AudioPlaybackContext.adhan);
      coordinator.markAdhanStarted('Maghrib');

      await coordinator.stopCurrentAdhan();
      await coordinator.stopCurrentAdhan();
      await coordinator.stopCurrentAdhan();

      expect(coordinator.isAdhanActive, isFalse);
      expect(mockAudioPlayer.stopCallCount, equals(1));
    });

    test('6. Preview Safety: stopCurrentAdhan NEVER stops AudioPlaybackContext.preview', () async {
      await mockAudioPlayer.playAsset('assets/audio/adhan.mp3',
          context: AudioPlaybackContext.preview);

      expect(mockAudioPlayer.currentContext, equals(AudioPlaybackContext.preview));
      expect(coordinator.isAdhanActive, isFalse);

      await coordinator.stopCurrentAdhan();

      // Audio player stop must NOT be called for preview
      expect(mockAudioPlayer.stopCallCount, equals(0));
      expect(mockAudioPlayer.isPlaying, isTrue);
    });

    test('7. Natural Completion clears active Adhan state automatically', () async {
      await mockAudioPlayer.playAsset('assets/audio/adhan.mp3',
          context: AudioPlaybackContext.adhan);
      coordinator.markAdhanStarted('Isha');

      expect(coordinator.isAdhanActive, isTrue);

      // Simulate player completed event
      mockAudioPlayer.simulateNaturalCompletion();
      await Future.delayed(const Duration(milliseconds: 20));

      expect(coordinator.isAdhanActive, isFalse);
      expect(coordinator.activePrayerName, isNull);
    });

    test('8. requestShowAdhanDialog emits event on stream with prayerName', () async {
      String? receivedPrayer;
      final sub = coordinator.onShowAdhanDialogRequested.listen((name) {
        receivedPrayer = name;
      });

      coordinator.requestShowAdhanDialog('Fajr');
      await Future.delayed(const Duration(milliseconds: 20));

      expect(receivedPrayer, equals('Fajr'));
      await sub.cancel();
    });
  });
}
