import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/core/audio/audio_player_service.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/storage/local_storage.dart';
import 'package:adhan_and_prayer/features/adhan/data/repositories/audio_repository_impl.dart';
import 'package:adhan_and_prayer/features/adhan/domain/entities/reciter.dart';
import 'package:adhan_and_prayer/features/adhan/presentation/cubit/audio_cubit.dart';

class MockLocalStorage implements LocalStorage {
  final Map<String, dynamic> data = {};

  @override
  String? getString(String key) => data[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    data[key] = value;
    return true;
  }

  @override
  double? getDouble(String key) => data[key] as double?;

  @override
  Future<bool> setDouble(String key, double value) async {
    data[key] = value;
    return true;
  }

  @override
  bool? getBool(String key) => data[key] as bool?;

  @override
  Future<bool> setBool(String key, bool value) async {
    data[key] = value;
    return true;
  }

  @override
  int? getInt(String key) => data[key] as int?;

  @override
  Future<bool> setInt(String key, int value) async {
    data[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    data.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    data.clear;
    return true;
  }
}

class MockAudioPlayerService implements AudioPlayerService {
  bool _isPlaying = false;
  double _volume = 1.0;
  AudioPlaybackContext _currentContext = AudioPlaybackContext.none;
  String? lastPlayedAsset;

  @override
  bool get isPlaying => _isPlaying;

  @override
  double get volume => _volume;

  @override
  AudioPlaybackContext get currentContext => _currentContext;

  @override
  Stream<PlayerState> get onPlayerStateChanged => const Stream.empty();

  @override
  Future<Result<void>> playAsset(
    String assetPath, {
    AudioPlaybackContext context = AudioPlaybackContext.none,
  }) async {
    _isPlaying = true;
    _currentContext = context;
    lastPlayedAsset = assetPath;
    return const Success(null);
  }

  @override
  Future<Result<void>> playFile(
    String filePath, {
    AudioPlaybackContext context = AudioPlaybackContext.none,
  }) async {
    _isPlaying = true;
    _currentContext = context;
    return const Success(null);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _currentContext = AudioPlaybackContext.none;
  }

  @override
  Future<void> stopPreview() async {
    if (_currentContext == AudioPlaybackContext.preview) {
      await stop();
    }
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('v1.1.0 Audio Control & Preview Lifecycle Tests', () {
    late MockLocalStorage mockStorage;
    late AudioRepositoryImpl audioRepo;
    late MockAudioPlayerService mockPlayer;
    late AudioCubit audioCubit;

    setUp(() {
      mockStorage = MockLocalStorage();
      audioRepo = AudioRepositoryImpl(mockStorage);
      mockPlayer = MockAudioPlayerService();
      audioCubit = AudioCubit(
        audioRepo: audioRepo,
        audioPlayer: mockPlayer,
      );
    });

    tearDown(() {
      audioCubit.close();
    });

    test('Default Adhan volume is 1.0 (100%)', () async {
      final vol = await audioRepo.getAdhanVolume();
      expect(vol, equals(1.0));
    });

    test('Adhan volume persists and clamps correctly between 0.0 and 1.0', () async {
      await audioRepo.saveAdhanVolume(0.7);
      expect(await audioRepo.getAdhanVolume(), equals(0.7));

      await audioRepo.saveAdhanVolume(1.5);
      expect(await audioRepo.getAdhanVolume(), equals(1.0));

      await audioRepo.saveAdhanVolume(-0.2);
      expect(await audioRepo.getAdhanVolume(), equals(0.0));
    });

    test('Zero volume does not prevent playback but sets volume to 0.0', () async {
      await audioRepo.saveAdhanVolume(0.0);
      final r1 = Reciter(
        id: 'r1',
        nameAr: 'Reciter 1',
        nameEn: 'Reciter 1',
        assetPath: 'assets/audio/r1.mp3',
        isDefault: true,
      );
      await audioCubit.initialize();
      await audioCubit.togglePreview(r1);

      expect(mockPlayer.isPlaying, isTrue);
      expect(mockPlayer.volume, equals(0.0));
      expect(mockPlayer.currentContext, equals(AudioPlaybackContext.preview));
    });

    test('Preview session plays with AudioPlaybackContext.preview and user volume', () async {
      await audioRepo.saveAdhanVolume(0.45);
      final r1 = Reciter(
        id: 'r1',
        nameAr: 'Reciter 1',
        nameEn: 'Reciter 1',
        assetPath: 'assets/audio/r1.mp3',
        isDefault: true,
      );
      await audioCubit.initialize();
      await audioCubit.togglePreview(r1);

      expect(mockPlayer.isPlaying, isTrue);
      expect(mockPlayer.volume, equals(0.45));
      expect(mockPlayer.currentContext, equals(AudioPlaybackContext.preview));
    });

    test('Changing reciter selection immediately stops ongoing preview', () async {
      final r1 = Reciter(
        id: 'r1',
        nameAr: 'Reciter 1',
        nameEn: 'Reciter 1',
        assetPath: 'assets/audio/r1.mp3',
        isDefault: true,
      );
      final r2 = Reciter(
        id: 'r2',
        nameAr: 'Reciter 2',
        nameEn: 'Reciter 2',
        assetPath: 'assets/audio/r2.mp3',
        isDefault: false,
      );

      await audioCubit.initialize();
      await audioCubit.togglePreview(r1);
      expect(mockPlayer.isPlaying, isTrue);

      // User selects r2 while r1 is previewing
      await audioCubit.selectReciter(r2);
      expect(mockPlayer.isPlaying, isFalse);
      expect(mockPlayer.currentContext, equals(AudioPlaybackContext.none));
    });

    test('Leaving reciter selection (stopPreview) stops preview session', () async {
      final r1 = Reciter(
        id: 'r1',
        nameAr: 'Reciter 1',
        nameEn: 'Reciter 1',
        assetPath: 'assets/audio/r1.mp3',
        isDefault: true,
      );

      await audioCubit.initialize();
      await audioCubit.togglePreview(r1);
      expect(mockPlayer.isPlaying, isTrue);

      await audioCubit.stopPreview();
      expect(mockPlayer.isPlaying, isFalse);
      expect(mockPlayer.currentContext, equals(AudioPlaybackContext.none));
    });

    test('stopPreview NEVER stops background or scheduled real Adhan playback', () async {
      // Simulate real Adhan starting
      await mockPlayer.playAsset('assets/audio/adhan_makkah.mp3', context: AudioPlaybackContext.adhan);
      expect(mockPlayer.isPlaying, isTrue);
      expect(mockPlayer.currentContext, equals(AudioPlaybackContext.adhan));

      // User navigates away or leaves reciter screen
      await audioCubit.stopPreview();

      // Real Adhan MUST remain playing!
      expect(mockPlayer.isPlaying, isTrue);
      expect(mockPlayer.currentContext, equals(AudioPlaybackContext.adhan));
    });
  });
}
