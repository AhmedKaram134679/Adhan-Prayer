import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android Background Adhan Foreground Service Verification', () {
    test('AndroidManifest registers AdhanPlaybackService with mediaPlayback type and no background location', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

      expect(manifest, contains('android:name=".AdhanPlaybackService"'));
      expect(manifest, contains('android:foregroundServiceType="mediaPlayback"'));
      expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
      expect(manifest, contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'));
      expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    });

    test('AdhanAlarmReceiver is lightweight and delegates to AdhanPlaybackService', () {
      final receiver = File(
        'android/app/src/main/kotlin/com/example/adhan_and_prayer/AdhanAlarmReceiver.kt',
      ).readAsStringSync();

      expect(receiver, contains('ContextCompat.startForegroundService'));
      expect(receiver, contains('AdhanPlaybackService::class.java'));
      expect(receiver, contains('AdhanPlaybackService.stopPlayback(context)'));
      expect(receiver, contains('AdhanPlaybackService.isValidAudioAssetPath'));
      // Receiver must NOT own MediaPlayer directly
      expect(receiver, isNot(contains('MediaPlayer()')));
    });

    test('AdhanPlaybackService manages foreground lifecycle, validation, stop, and cleanup', () {
      final service = File(
        'android/app/src/main/kotlin/com/example/adhan_and_prayer/AdhanPlaybackService.kt',
      ).readAsStringSync();

      expect(service, contains('class AdhanPlaybackService : Service()'));
      expect(service, contains('FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK'));
      expect(service, contains('ACTION_START_ADHAN'));
      expect(service, contains('ACTION_STOP_ADHAN'));
      expect(service, contains('isValidAudioAssetPath'));
      expect(service, contains('setOnCompletionListener'));
      expect(service, contains('setOnErrorListener'));
      expect(service, contains('releaseMediaPlayer()'));
      expect(service, contains('releaseWakeLock()'));
      expect(service, contains('START_NOT_STICKY'));
    });
  });
}
