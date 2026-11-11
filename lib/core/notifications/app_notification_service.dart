import 'dart:io';
import 'package:adhan_and_prayer/core/platform/windows_path_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/platform/windows_tray_manager.dart';
import 'package:adhan_and_prayer/core/storage/local_storage.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';

abstract class AppNotificationService {
  Future<void> initialize();
  Future<Result<void>> showPrayerNotification({
    required int id,
    required String title,
    required String body,
    String? prayerName,
    VoidCallback? onStopPressed,
    VoidCallback? onBodyTapped,
  });
  Future<void> cancelNotification(int id);
  Future<void> cancelAllNotifications();
}

class AppNotificationServiceImpl implements AppNotificationService {
  final LocalStorage _storage;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Silent channel v2 to match native Android AdhanAlarmReceiver
  static const String prayerChannelId = 'adhan_prayer_channel_v2';
  static const String prayerChannelName = 'Prayer Times & Adhan';
  static const String prayerChannelDesc =
      'Notifications for Islamic daily prayer times and Adhan';

  // Windows notification action constants
  static const String stopActionTextAr = 'إيقاف الأذان';
  static const String stopActionTextEn = 'Stop Adhan';

  VoidCallback? _currentStopCallback;
  VoidCallback? _currentBodyCallback;
  LocalNotification? _activeWindowsNotification;

  AppNotificationServiceImpl(this._storage);

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(
        android: androidSettings,
      );

      try {
        await _notificationsPlugin.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: (details) {
            AppLogger.info(
              'Notification response: actionId=${details.actionId}, payload=${details.payload}',
              'NOTIFICATIONS',
            );
            if (details.actionId == 'stop_adhan') {
              _currentStopCallback?.call();
            } else {
              _currentBodyCallback?.call();
            }
          },
        );

        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          await androidImpl.requestNotificationsPermission();
          await androidImpl.requestExactAlarmsPermission();

          // Delete legacy noisy channel if present
          try {
            await androidImpl.deleteNotificationChannel(channelId: 'adhan_prayer_channel');
          } catch (_) {}

          // Create silent high importance channel
          const channel = AndroidNotificationChannel(
            prayerChannelId,
            prayerChannelName,
            description: prayerChannelDesc,
            importance: Importance.max,
            playSound: false,
            enableVibration: true,
          );
          await androidImpl.createNotificationChannel(channel);
        }

        _initialized = true;
        AppLogger.info(
          'AppNotificationService initialized on Android',
          'NOTIFICATIONS',
        );
      } catch (e, stack) {
        AppLogger.error(
          'Failed to initialize Android notifications',
          e,
          stack,
          'NOTIFICATIONS',
        );
      }
    } else if (Platform.isWindows) {
      try {
        // 1. Setup localNotifier
        await localNotifier.setup(
          appName: 'adhan_and_prayer',
          shortcutPolicy: ShortcutPolicy.requireCreate,
        );

        // 2. Ensure the per-user shell link points strictly to the currently running executable
        await WindowsPathResolver.repairNotificationShortcutIfNeeded(appName: 'adhan_and_prayer');

        _initialized = true;
        AppLogger.info(
          'AppNotificationService initialized and verified for Windows desktop',
          'NOTIFICATIONS',
        );
      } catch (e, stack) {
        AppLogger.error(
          'Failed to initialize local_notifier on Windows',
          e,
          stack,
          'NOTIFICATIONS',
        );
      }
    } else {
      _initialized = true;
      AppLogger.info(
        'AppNotificationService initialized for desktop',
        'NOTIFICATIONS',
      );
    }
  }

  @override
  Future<Result<void>> showPrayerNotification({
    required int id,
    required String title,
    required String body,
    String? prayerName,
    VoidCallback? onStopPressed,
    VoidCallback? onBodyTapped,
  }) async {
    try {
      _currentStopCallback = onStopPressed;
      _currentBodyCallback = onBodyTapped;

      // Determine language
      final savedLocale = _storage.getString('app_locale') ?? 'ar';
      final isArabic = savedLocale.startsWith('ar');
      final stopActionLabel = isArabic ? stopActionTextAr : stopActionTextEn;

      if (Platform.isWindows) {
        // Destroy previous active windows notification if any
        try {
          await _activeWindowsNotification?.destroy();
        } catch (_) {}

        final notification = LocalNotification(
          identifier: id.toString(),
          title: title,
          body: body,
          actions: [
            LocalNotificationAction(text: stopActionLabel),
          ],
        );

        notification.onClickAction = (actionIndex) {
          AppLogger.info(
            'Windows notification action clicked: index=$actionIndex (Stop Adhan)',
            'NOTIFICATIONS',
          );
          _currentStopCallback?.call();
        };

        notification.onClick = () async {
          AppLogger.info(
            'Windows notification body clicked: restoring window and showing dialog',
            'NOTIFICATIONS',
          );
          // Restore and bring window to foreground from Tray or minimized state
          await WindowsTrayManager().restoreWindow();
          _currentBodyCallback?.call();
        };

        _activeWindowsNotification = notification;
        await notification.show();
      } else if (Platform.isAndroid) {
        // Note: When scheduled alarms fire in the background on Android,
        // AdhanAlarmReceiver natively builds and displays the notification with "إيقاف الأذان".
        // This in-app path is used when triggered in foreground or from Flutter directly.
        final androidDetails = AndroidNotificationDetails(
          prayerChannelId,
          prayerChannelName,
          channelDescription: prayerChannelDesc,
          importance: Importance.max,
          priority: Priority.high,
          playSound: false,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          actions: [
            AndroidNotificationAction(
              'stop_adhan',
              stopActionLabel,
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        );

        final notificationDetails = NotificationDetails(
          android: androidDetails,
        );

        await _notificationsPlugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: notificationDetails,
          payload: prayerName,
        );
      }

      AppLogger.info('Shown prayer notification: $title - $body', 'NOTIFICATIONS');
      return const Success(null);
    } catch (e, stack) {
      AppLogger.error('Error showing notification', e, stack, 'NOTIFICATIONS');
      return Failure('Notification error: $e');
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    try {
      if (Platform.isWindows) {
        await _activeWindowsNotification?.destroy();
        _activeWindowsNotification = null;
      } else {
        await _notificationsPlugin.cancel(id: id);
      }
    } catch (e, stack) {
      AppLogger.error('Error cancelling notification: $id', e, stack, 'NOTIFICATIONS');
    }
  }

  @override
  Future<void> cancelAllNotifications() async {
    try {
      if (Platform.isWindows) {
        await _activeWindowsNotification?.destroy();
        _activeWindowsNotification = null;
      } else {
        await _notificationsPlugin.cancelAll();
      }
    } catch (e, stack) {
      AppLogger.error('Error cancelling all notifications', e, stack, 'NOTIFICATIONS');
    }
  }
}
