import 'dart:io';
import 'package:flutter/services.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/platform/windows_path_resolver.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';

class ScheduledPrayerAlarm {
  final int id;
  final String prayerName;
  final DateTime scheduledTime;
  final String reciterAssetPath;
  final bool isAdhanEnabled;

  const ScheduledPrayerAlarm({
    required this.id,
    required this.prayerName,
    required this.scheduledTime,
    required this.reciterAssetPath,
    required this.isAdhanEnabled,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'prayerName': prayerName,
    'timestampMillis': scheduledTime.millisecondsSinceEpoch,
    'reciterAssetPath': reciterAssetPath,
    'isAdhanEnabled': isAdhanEnabled,
  };
}

abstract class AdhanSchedulerService {
  Future<Result<void>> schedulePrayers(List<ScheduledPrayerAlarm> alarms);
  Future<Result<void>> cancelAll();
}

class AdhanSchedulerServiceImpl implements AdhanSchedulerService {
  static const MethodChannel _channel = MethodChannel('com.example.adhan_and_prayer/alarm');
  static const String _windowsTaskPrefix = 'Adhan_Prayer_';

  @override
  Future<Result<void>> schedulePrayers(List<ScheduledPrayerAlarm> alarms) async {
    try {
      if (Platform.isAndroid) {
        final alarmsData = alarms.map((a) => a.toMap()).toList();
        await _channel.invokeMethod('scheduleAlarms', {'alarms': alarmsData});
        AppLogger.info('Sent ${alarms.length} alarms to Android native AlarmManager', 'SCHEDULER');
      } else if (Platform.isWindows) {
        await _reconcileWindowsTasks(alarms);
      }
      return const Success(null);
    } catch (e, stack) {
      AppLogger.error('Failed to schedule prayers', e, stack, 'SCHEDULER');
      return Failure('Failed to schedule prayers: $e');
    }
  }

  @override
  Future<Result<void>> cancelAll() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('cancelAllAlarms');
        AppLogger.info('Android native alarms cancelled', 'SCHEDULER');
      } else if (Platform.isWindows) {
        await _cancelAllWindowsTasks();
      }
      return const Success(null);
    } catch (e, stack) {
      AppLogger.error('Failed to cancel alarms', e, stack, 'SCHEDULER');
      return Failure('Failed to cancel alarms: $e');
    }
  }

  /// Windows OS-level Task Scheduler integration
  Future<void> _reconcileWindowsTasks(List<ScheduledPrayerAlarm> alarms) async {
    try {
      // 1. Query existing Adhan tasks in Windows Task Scheduler
      final existingTasks = await _getExistingWindowsTasks();
      final desiredTasks = <String, ScheduledPrayerAlarm>{};

      for (final alarm in alarms) {
        if (!alarm.isAdhanEnabled) continue;
        // Deterministic unique task ID: Adhan_Prayer_YYYYMMDD_PrayerName
        final dateStr = '${alarm.scheduledTime.year}'
            '${alarm.scheduledTime.month.toString().padLeft(2, '0')}'
            '${alarm.scheduledTime.day.toString().padLeft(2, '0')}';
        final taskName = '$_windowsTaskPrefix${dateStr}_${alarm.prayerName}';
        desiredTasks[taskName] = alarm;
      }

      // 2. Remove obsolete or outdated tasks
      for (final existingTask in existingTasks) {
        if (!desiredTasks.containsKey(existingTask)) {
          await _deleteWindowsTask(existingTask);
        }
      }

      // 3. Register or update desired upcoming prayer tasks
      final exePath = WindowsPathResolver.resolvedExecutable;
      final exeDir = WindowsPathResolver.executableDirectory;
      final assetsRoot = WindowsPathResolver.flutterAssetsDirectory;

      AppLogger.info(
        'Reconciling Windows tasks with executable: "$exePath", working dir: "$exeDir", assets root: "$assetsRoot"',
        'SCHEDULER',
      );

      for (final entry in desiredTasks.entries) {
        final taskName = entry.key;
        final alarm = entry.value;

        // Formatted for system schtasks (M/d/yyyy or d/M/yyyy, schtasks accepts MM/dd/yyyy in Windows US locale)
        final month = alarm.scheduledTime.month.toString().padLeft(2, '0');
        final day = alarm.scheduledTime.day.toString().padLeft(2, '0');
        final year = alarm.scheduledTime.year.toString();
        final hour = alarm.scheduledTime.hour.toString().padLeft(2, '0');
        final minute = alarm.scheduledTime.minute.toString().padLeft(2, '0');

        final timeStr = '$hour:$minute';
        final dateStr = '$month/$day/$year';

        final trCommand = '"$exePath" --play-adhan "${alarm.prayerName}" "${alarm.reciterAssetPath}"';

        AppLogger.info(
          'Scheduling Task: "$taskName" | Time: $dateStr $timeStr | Reciter: ${alarm.reciterAssetPath} | Command: $trCommand',
          'SCHEDULER',
        );

        final result = await Process.run('schtasks', [
          '/create',
          '/tn', taskName,
          '/tr', trCommand,
          '/sc', 'once',
          '/sd', dateStr,
          '/st', timeStr,
          '/f',
        ]);

        if (result.exitCode == 0) {
          AppLogger.info('Windows Task Scheduler successfully registered/updated $taskName', 'SCHEDULER');
        } else {
          AppLogger.warning('schtasks create warning for $taskName: ${result.stderr} (stdout: ${result.stdout})', 'SCHEDULER');
        }
      }
    } catch (e, stack) {
      AppLogger.error('Error reconciling Windows tasks', e, stack, 'SCHEDULER');
    }
  }

  Future<List<String>> _getExistingWindowsTasks() async {
    final tasks = <String>[];
    try {
      final result = await Process.run('schtasks', ['/query', '/fo', 'LIST']);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split(RegExp(r'\r?\n'));
        for (final line in lines) {
          if (line.trim().startsWith('TaskName:')) {
            // TaskName: \Adhan_Prayer_...
            final name = line.replaceFirst(RegExp(r'^TaskName:\s*\\?'), '').trim();
            if (name.startsWith(_windowsTaskPrefix)) {
              tasks.add(name);
            }
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Error querying existing Windows tasks: $e', 'SCHEDULER');
    }
    return tasks;
  }

  Future<void> _deleteWindowsTask(String taskName) async {
    try {
      await Process.run('schtasks', ['/delete', '/tn', taskName, '/f']);
      AppLogger.info('Deleted obsolete Windows task: $taskName', 'SCHEDULER');
    } catch (e) {
      AppLogger.warning('Error deleting Windows task $taskName: $e', 'SCHEDULER');
    }
  }

  Future<void> _cancelAllWindowsTasks() async {
    try {
      final existingTasks = await _getExistingWindowsTasks();
      for (final task in existingTasks) {
        await _deleteWindowsTask(task);
      }
      AppLogger.info('Cancelled all (${existingTasks.length}) Windows Adhan tasks', 'SCHEDULER');
    } catch (e, stack) {
      AppLogger.error('Error cancelling all Windows tasks', e, stack, 'SCHEDULER');
    }
  }
}
