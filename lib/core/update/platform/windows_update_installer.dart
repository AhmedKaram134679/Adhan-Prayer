import 'dart:io';
import 'package:flutter/services.dart';
import 'package:adhan_and_prayer/core/update/platform/update_installer.dart';
import 'package:adhan_and_prayer/core/platform/windows_tray_manager.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';

/// Windows update installer executing setup executable with native Win32 ShellExecuteExW
/// and the "runas" verb for UAC elevation, followed by safe application shutdown
/// so files can be cleanly replaced without file locking conflicts.
class WindowsUpdateInstaller implements UpdateInstaller {
  static const MethodChannel _channel =
      MethodChannel('com.example.adhan_and_prayer/windows_updater');

  @override
  String get fileExtension => '.exe';

  @override
  String get platformName => 'windows';

  @override
  Future<InstallResult> install(File updateFile) async {
    if (!await updateFile.exists()) {
      return const InstallResult.failure('Setup executable does not exist on disk.');
    }

    try {
      AppLogger.info('Launching elevated Windows installer via native ShellExecuteW (runas): ${updateFile.path}', 'INSTALLER');

      // 1. First attempt native Win32 ShellExecuteExW with verb "runas" via MethodChannel
      try {
        final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'executeInstaller',
          {
            'filePath': updateFile.path,
            'arguments': '/SILENT /CLOSEAPPLICATIONS',
          },
        );

        final success = result?['success'] as bool? ?? false;
        final isCancelled = result?['cancelled'] as bool? ?? false;
        final errorMsg = result?['error'] as String?;

        if (isCancelled) {
          AppLogger.warning('User cancelled Windows UAC elevation prompt', 'INSTALLER');
          return const InstallResult.failure('Elevation was cancelled by user (UAC declined).');
        }

        if (success) {
          AppLogger.info('Native ShellExecuteW (runas) succeeded. Preparing safe application shutdown.', 'INSTALLER');
          _performSafeApplicationShutdown();
          return const InstallResult.success();
        } else {
          AppLogger.warning('Native ShellExecuteW returned error: $errorMsg. Falling back to native process launcher.', 'INSTALLER');
        }
      } on MissingPluginException {
        AppLogger.info('Windows updater channel not registered (e.g. running in test or minimal host). Using fallback launcher.', 'INSTALLER');
      }

      // 2. Fallback execution using detached Process if native channel was unavailable
      final sanitizedPath = updateFile.path.replaceAll("'", "''");
      final command = "Start-Process -FilePath '$sanitizedPath' -Verb RunAs";

      final process = await Process.start(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', command],
        mode: ProcessStartMode.detached,
      );

      AppLogger.info('Detached fallback installer process started (pid: ${process.pid}). Preparing safe shutdown.', 'INSTALLER');
      _performSafeApplicationShutdown();

      return const InstallResult.success();
    } catch (e, stack) {
      AppLogger.error('Failed to launch Windows installer', e, stack, 'INSTALLER');
      return InstallResult.failure('Windows installer launch failed: $e');
    }
  }

  /// Safely releases tray resources and window locks before terminating process.
  void _performSafeApplicationShutdown() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        if (Platform.isWindows) {
          await WindowsTrayManager().exitApp();
        } else {
          exit(0);
        }
      } catch (_) {
        exit(0);
      }
    });
  }
}
