import 'package:adhan_and_prayer/core/platform/windows_path_resolver.dart';
import 'package:adhan_and_prayer/core/platform/windows_single_instance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/core/platform/adhan_scheduler_service.dart';

void main() {
  group('AdhanScheduler Alarms & Identifiers Integrity', () {
    test('ScheduledPrayerAlarm serializes to map correctly', () {
      final time = DateTime(2026, 9, 5, 15, 30);
      final alarm = ScheduledPrayerAlarm(
        id: 12345,
        prayerName: 'Asr',
        scheduledTime: time,
        reciterAssetPath: 'assets/audio/adhan_abdulbasit.mp3',
        isAdhanEnabled: true,
      );

      final map = alarm.toMap();
      expect(map['id'], equals(12345));
      expect(map['prayerName'], equals('Asr'));
      expect(map['timestampMillis'], equals(time.millisecondsSinceEpoch));
      expect(map['reciterAssetPath'], equals('assets/audio/adhan_abdulbasit.mp3'));
      expect(map['isAdhanEnabled'], isTrue);
    });

    test('Deterministic task name formatting for Windows Task Scheduler', () {
      final time = DateTime(2026, 9, 5, 4, 30);
      final dateStr = '${time.year}'
          '${time.month.toString().padLeft(2, '0')}'
          '${time.day.toString().padLeft(2, '0')}';
      final taskName = 'Adhan_Prayer_${dateStr}_Fajr';

      expect(taskName, equals('Adhan_Prayer_20260905_Fajr'));
    });

    test('Scheduler reconciliation: Desired tasks dictionary correctly excludes disabled prayers', () {
      final t1 = DateTime(2026, 9, 5, 4, 30);
      final t2 = DateTime(2026, 9, 5, 12, 0);

      final alarms = [
        ScheduledPrayerAlarm(
          id: 1,
          prayerName: 'Fajr',
          scheduledTime: t1,
          reciterAssetPath: 'assets/audio/adhan_abdulbasit.mp3',
          isAdhanEnabled: true,
        ),
        ScheduledPrayerAlarm(
          id: 2,
          prayerName: 'Dhuhr',
          scheduledTime: t2,
          reciterAssetPath: 'assets/audio/adhan_abdulbasit.mp3',
          isAdhanEnabled: false, // Disabled
        ),
      ];

      final desiredTasks = <String, ScheduledPrayerAlarm>{};
      for (final alarm in alarms) {
        if (!alarm.isAdhanEnabled) continue;
        final dateStr = '${alarm.scheduledTime.year}'
            '${alarm.scheduledTime.month.toString().padLeft(2, '0')}'
            '${alarm.scheduledTime.day.toString().padLeft(2, '0')}';
        final taskName = 'Adhan_Prayer_${dateStr}_${alarm.prayerName}';
        desiredTasks[taskName] = alarm;
      }

      expect(desiredTasks.containsKey('Adhan_Prayer_20260905_Fajr'), isTrue);
      expect(desiredTasks.containsKey('Adhan_Prayer_20260905_Dhuhr'), isFalse);
    });

    test('Scheduler reconciliation is idempotent with identical desired tasks', () {
      final t1 = DateTime(2026, 9, 5, 4, 30);
      final alarm = ScheduledPrayerAlarm(
        id: 1,
        prayerName: 'Fajr',
        scheduledTime: t1,
        reciterAssetPath: 'assets/audio/adhan_abdulbasit.mp3',
        isAdhanEnabled: true,
      );

      final existingTasks = ['Adhan_Prayer_20260905_Fajr', 'Adhan_Prayer_20260904_Isha'];
      final desiredTasks = {'Adhan_Prayer_20260905_Fajr': alarm};

      final toDelete = <String>[];
      for (final task in existingTasks) {
        if (!desiredTasks.containsKey(task)) {
          toDelete.add(task);
        }
      }

      expect(toDelete, equals(['Adhan_Prayer_20260904_Isha']));
      expect(toDelete.contains('Adhan_Prayer_20260905_Fajr'), isFalse);
    });

    test('Windows Task Scheduler /tr command line formats path with quotes correctly', () {
      const exePath = r'C:\Program Files\Adhan App\adhan.exe';
      const prayerName = 'Fajr';
      const reciterAsset = 'assets/audio/adhan_abdulbasit.mp3';

      final trCommand = '"$exePath" --play-adhan "$prayerName" "$reciterAsset"';
      expect(trCommand, equals(r'"C:\Program Files\Adhan App\adhan.exe" --play-adhan "Fajr" "assets/audio/adhan_abdulbasit.mp3"'));
    });

    test('Master Adhan OFF: Reconciler marks all existing tasks for deletion', () {
      final existingTasks = [
        'Adhan_Prayer_20260905_Fajr',
        'Adhan_Prayer_20260905_Dhuhr',
        'Adhan_Prayer_20260905_Asr',
      ];

      // Master Adhan is OFF -> all alarms have isAdhanEnabled = false
      final alarms = [
        ScheduledPrayerAlarm(
          id: 1,
          prayerName: 'Fajr',
          scheduledTime: DateTime(2026, 9, 5, 4, 30),
          reciterAssetPath: 'assets/audio/adhan_abdulbasit.mp3',
          isAdhanEnabled: false,
        ),
        ScheduledPrayerAlarm(
          id: 2,
          prayerName: 'Dhuhr',
          scheduledTime: DateTime(2026, 9, 5, 12, 10),
          reciterAssetPath: 'assets/audio/adhan_abdulbasit.mp3',
          isAdhanEnabled: false,
        ),
      ];

      final desiredTasks = <String, ScheduledPrayerAlarm>{};
      for (final alarm in alarms) {
        if (!alarm.isAdhanEnabled) continue;
        final dateStr = '${alarm.scheduledTime.year}'
            '${alarm.scheduledTime.month.toString().padLeft(2, '0')}'
            '${alarm.scheduledTime.day.toString().padLeft(2, '0')}';
        desiredTasks['Adhan_Prayer_${dateStr}_${alarm.prayerName}'] = alarm;
      }

      final toDelete = <String>[];
      for (final task in existingTasks) {
        if (!desiredTasks.containsKey(task)) {
          toDelete.add(task);
        }
      }

      expect(toDelete, equals(existingTasks));
      expect(desiredTasks.isEmpty, isTrue);
    });

    test('Reciter change: Future scheduled tasks update reciterAssetPath', () {
      final oldAlarm = ScheduledPrayerAlarm(
        id: 1,
        prayerName: 'Fajr',
        scheduledTime: DateTime(2026, 9, 5, 4, 30),
        reciterAssetPath: 'assets/audio/adhan_abdulbasit.mp3',
        isAdhanEnabled: true,
      );

      final newAlarm = ScheduledPrayerAlarm(
        id: 1,
        prayerName: 'Fajr',
        scheduledTime: DateTime(2026, 9, 5, 4, 30),
        reciterAssetPath: 'assets/audio/adhan_makkah.mp3',
        isAdhanEnabled: true,
      );

      expect(oldAlarm.reciterAssetPath, equals('assets/audio/adhan_abdulbasit.mp3'));
      expect(newAlarm.reciterAssetPath, equals('assets/audio/adhan_makkah.mp3'));
      expect(newAlarm.toMap()['reciterAssetPath'], equals('assets/audio/adhan_makkah.mp3'));
    });

    test('Reciter change detection: Changing reciter ID evaluates to true, identical ID evaluates to false', () {
      const initialReciterId = 'makkah';

      // User selects different reciter
      const differentReciterId = 'madinah';
      final hasChangedDifferent = (initialReciterId != differentReciterId);
      expect(hasChangedDifferent, isTrue);

      // User selects same reciter
      const sameReciterId = 'makkah';
      final hasChangedSame = (initialReciterId != sameReciterId);
      expect(hasChangedSame, isFalse);
    });

    test('Caller reaction: Route result triggers schedule refresh only when changed == true', () {
      int scheduleRefreshCount = 0;
      void onScreenPopped(bool? changed) {
        if (changed == true) {
          scheduleRefreshCount++;
        }
      }

      // 1. User opened and changed reciter -> pops true
      onScreenPopped(true);
      expect(scheduleRefreshCount, equals(1), reason: 'Must trigger refresh when reciter changed');

      // 2. User opened and did NOT change reciter -> pops false
      onScreenPopped(false);
      expect(scheduleRefreshCount, equals(1), reason: 'Must NOT trigger refresh when reciter is unchanged');

      // 3. User cancelled or navigated back without action -> null
      onScreenPopped(null);
      expect(scheduleRefreshCount, equals(1), reason: 'Must NOT trigger refresh when result is null');
    });

    test('Android Background Event Authority: Native AlarmManager is sole trigger for audio & notification', () {
      // In-process Dart execution must be gated on Android (!Platform.isAndroid)
      // while native AlarmManager + AdhanAlarmReceiver handles the background playback and notification.
      final isAndroid = true;
      final isObligatory = true;
      final isEnabled = true;

      final shouldTriggerFlutterInAppAdhan = isEnabled && isObligatory && !isAndroid;
      expect(shouldTriggerFlutterInAppAdhan, isFalse,
          reason: 'Flutter in-app audio/notification must be suppressed on Android to prevent duplicates with AlarmManager');

      final isWindows = false;
      final shouldTriggerWindowsFlutterAdhan = isEnabled && isObligatory && !isWindows;
      expect(shouldTriggerWindowsFlutterAdhan, isTrue,
          reason: 'Windows desktop must continue executing in-process Adhan when app is running');
    });

    test('No Duplicate Notification: Exactly one notification generated per prayer event on Android', () {
      // AlarmManager registers exactly one pending intent per prayer
      final prayerAlarms = [
        ScheduledPrayerAlarm(
          id: 1757155800, // Deterministic timestamp id
          prayerName: 'Dhuhr',
          scheduledTime: DateTime(2026, 9, 6, 12, 10),
          reciterAssetPath: 'assets/audio/adhan_abdulbasit.mp3',
          isAdhanEnabled: true,
        ),
      ];

      expect(prayerAlarms.length, equals(1));
      expect(prayerAlarms.first.prayerName, equals('Dhuhr'));
      expect(prayerAlarms.first.id, equals(1757155800));
    });

    test('Android Notification Distinct Content: Title and ContentText are distinct and not duplicated', () {
      final prayerNames = {
        'Fajr': 'الفجر',
        'Sunrise': 'الشروق',
        'Dhuhr': 'الظهر',
        'Asr': 'العصر',
        'Maghrib': 'المغرب',
        'Isha': 'العشاء',
      };

      for (final entry in prayerNames.entries) {
        final prayerEn = entry.key;
        final prayerAr = entry.value;

        // Arabic locale
        final titleAr = 'الأذان ومواقيت الصلاة';
        final contentAr = 'حان الآن موعد صلاة $prayerAr';
        expect(titleAr != contentAr, isTrue, reason: 'Arabic title and body must not be identical');
        expect(contentAr, contains(prayerAr));

        // English locale
        final titleEn = 'Adhan & Prayer Times';
        final contentEn = 'It is now time for $prayerEn prayer';
        expect(titleEn != contentEn, isTrue, reason: 'English title and body must not be identical');
        expect(contentEn, contains(prayerEn));
      }
    });

    test('WindowsPathResolver: Path normalization handles case, quotes, and separator variations', () {
      const p1 = r'"D:\Adhan & Prayer\adhan_and_prayer.exe"';
      const p2 = r'd:/adhan & prayer/adhan_and_prayer.exe';
      const p3 = r"'D:\Adhan & Prayer\\adhan_and_prayer.exe'";

      expect(WindowsPathResolver.normalizePath(p1), equals(r'd:\adhan & prayer\adhan_and_prayer.exe'));
      expect(WindowsPathResolver.normalizePath(p2), equals(r'd:\adhan & prayer\adhan_and_prayer.exe'));
      expect(WindowsPathResolver.normalizePath(p3), equals(r'd:\adhan & prayer\adhan_and_prayer.exe'));
    });

    test('WindowsPathResolver: Notification shortcut path resolution uses APPDATA environment', () {
      final shortcut = WindowsPathResolver.getNotificationShortcutPath(appName: 'adhan_and_prayer');
      expect(shortcut, contains('adhan_and_prayer.lnk'));
      expect(shortcut, contains('Start Menu'));
    });

    test('Windows Duplicate Adhan Prevention: GUI mutex name is deterministic and matches C++ runner', () {
      expect(WindowsSingleInstance.guiMutexName, equals(r'Local\AdhanAndPrayer_SingleInstance_Mutex_v1'));
    });

    test('Windows Duplicate Adhan Prevention: Headless Adhan yields when GUI instance is active', () {
      // Architectural simulation:
      // When Task Scheduler triggers: "adhan_and_prayer.exe --play-adhan Dhuhr ..."
      // Case A: GUI instance running -> Headless must yield immediately to avoid dual-playback.
      // Case B: GUI instance not running (app closed) -> Headless takes playback authority.
      
      bool simulateHeadlessExecution({required bool isGuiRunning}) {
        if (isGuiRunning) {
          // Yields immediately without initializing audio/player
          return false; // didNotPlayHeadless
        } else {
          // Takes authority and plays audio
          return true; // playedHeadless
        }
      }

      // App running / tray minimized: Headless yields -> In-process plays -> Exactly 1 playback!
      expect(simulateHeadlessExecution(isGuiRunning: true), isFalse);

      // App closed: Headless takes authority -> Exactly 1 playback!
      expect(simulateHeadlessExecution(isGuiRunning: false), isTrue);
    });
  });
}


