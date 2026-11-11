import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';

enum AudioPlaybackContext {
  none,
  preview,
  adhan,
}

abstract class AudioPlayerService {
  Future<Result<void>> playAsset(
    String assetPath, {
    AudioPlaybackContext context = AudioPlaybackContext.none,
  });
  Future<Result<void>> playFile(
    String filePath, {
    AudioPlaybackContext context = AudioPlaybackContext.none,
  });
  Future<void> stop();
  Future<void> stopPreview();
  Future<void> setVolume(double volume);
  double get volume;
  AudioPlaybackContext get currentContext;
  Stream<PlayerState> get onPlayerStateChanged;
  bool get isPlaying;
  Future<void> dispose();
}

class AudioPlayerServiceImpl implements AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  double _volume = 1.0;
  AudioPlaybackContext _currentContext = AudioPlaybackContext.none;

  AudioPlayerServiceImpl() {
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      if (!_isPlaying) {
        _currentContext = AudioPlaybackContext.none;
      }
    });
  }

  @override
  bool get isPlaying => _isPlaying;

  @override
  double get volume => _volume;

  @override
  AudioPlaybackContext get currentContext => _currentContext;

  @override
  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;

  @override
  Future<Result<void>> playAsset(
    String assetPath, {
    AudioPlaybackContext context = AudioPlaybackContext.none,
  }) async {
    try {
      await stop();
      _currentContext = context;
      await _player.setVolume(_volume);

      // audioplayers expects path without 'assets/' prefix if using AssetSource
      final cleanPath = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;
      await _player.play(AssetSource(cleanPath));
      _isPlaying = true;
      AppLogger.info('Started playing asset: $assetPath (context: $context, volume: $_volume)', 'AUDIO_PLAYER');
      return const Success(null);
    } catch (e, stack) {
      _currentContext = AudioPlaybackContext.none;
      AppLogger.error('Failed to play asset: $assetPath', e, stack, 'AUDIO_PLAYER');
      return Failure('Audio playback error: $e');
    }
  }

  @override
  Future<Result<void>> playFile(
    String filePath, {
    AudioPlaybackContext context = AudioPlaybackContext.none,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return Failure('Audio file not found at $filePath');
      }
      await stop();
      _currentContext = context;
      await _player.setVolume(_volume);

      await _player.play(DeviceFileSource(filePath));
      _isPlaying = true;
      AppLogger.info('Started playing device file: $filePath (context: $context, volume: $_volume)', 'AUDIO_PLAYER');
      return const Success(null);
    } catch (e, stack) {
      _currentContext = AudioPlaybackContext.none;
      AppLogger.error('Failed to play file: $filePath', e, stack, 'AUDIO_PLAYER');
      return Failure('Device audio playback error: $e');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    _volume = clamped;
    try {
      await _player.setVolume(clamped);
      AppLogger.info('Set audio player volume to: $clamped', 'AUDIO_PLAYER');
    } catch (e, stack) {
      AppLogger.error('Failed to update live player volume: $clamped', e, stack, 'AUDIO_PLAYER');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _currentContext = AudioPlaybackContext.none;
      AppLogger.info('Stopped audio playback', 'AUDIO_PLAYER');
    } catch (e, stack) {
      AppLogger.error('Error stopping audio', e, stack, 'AUDIO_PLAYER');
    }
  }

  @override
  Future<void> stopPreview() async {
    // Only stop if the current active session is a user-initiated preview.
    // NEVER terminate a real background or scheduled Adhan session.
    if (_currentContext == AudioPlaybackContext.preview) {
      AppLogger.info('Stopping active preview session', 'AUDIO_PLAYER');
      await stop();
    } else {
      AppLogger.info('stopPreview called but current context is $_currentContext; skipping stop', 'AUDIO_PLAYER');
    }
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }
}
