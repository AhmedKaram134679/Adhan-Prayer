import 'dart:io';
import 'package:adhan_and_prayer/core/utils/logger.dart';

/// Centralized utility for dynamic Windows executable and asset path resolution.
/// Ensures all scheduled tasks and background processes dynamically bind to the
/// currently running installed application rather than any hardcoded development paths.
class WindowsPathResolver {
  WindowsPathResolver._();

  /// Gets the full absolute path of the currently executing binary.
  /// Dynamically evaluated at runtime via [Platform.resolvedExecutable].
  /// Example installed: `D:\Adhan & Prayer\adhan_and_prayer.exe`
  static String get resolvedExecutable => Platform.resolvedExecutable;

  /// Gets the parent directory of the currently running executable.
  /// Example installed: `D:\Adhan & Prayer`
  static String get executableDirectory => File(resolvedExecutable).parent.path;

  /// Gets the Flutter bundled assets root directory.
  /// For Windows desktop Flutter apps, assets reside under:
  /// `<executableDirectory>\data\flutter_assets`
  static String get flutterAssetsDirectory {
    final sep = Platform.pathSeparator;
    return '$executableDirectory${sep}data${sep}flutter_assets';
  }

  /// Resolves an asset identifier (e.g. `assets/audio/adhan_makkah.mp3`)
  /// to an absolute filesystem path in the installed application.
  /// 
  /// Checks candidates in order:
  /// 1. `<executableDirectory>\data\flutter_assets\<assetKey>`
  /// 2. If [assetKey] starts with 'assets/', `<executableDirectory>\data\flutter_assets\<subpath>`
  /// 3. `<executableDirectory>\<assetKey>`
  /// 4. Direct filesystem check if already an absolute path.
  static String resolveAssetPath(String assetKey) {
    if (!Platform.isWindows) {
      return assetKey;
    }

    final sep = Platform.pathSeparator;
    final normalizedKey = assetKey.replaceAll('/', sep).replaceAll('\\', sep);

    // Candidate 1: data\flutter_assets\<key>
    final candidate1 = '$flutterAssetsDirectory$sep$normalizedKey';
    if (File(candidate1).existsSync()) {
      return candidate1;
    }

    // Candidate 2: data\flutter_assets\<key without leading 'assets\'>
    if (normalizedKey.toLowerCase().startsWith('assets$sep')) {
      final strippedKey = normalizedKey.substring('assets$sep'.length);
      final candidate2 = '$flutterAssetsDirectory$sep$strippedKey';
      if (File(candidate2).existsSync()) {
        return candidate2;
      }
    }

    // Candidate 3: relative to executable directory
    final candidate3 = '$executableDirectory$sep$normalizedKey';
    if (File(candidate3).existsSync()) {
      return candidate3;
    }

    // Candidate 4: already an absolute path
    if (File(assetKey).existsSync()) {
      return assetKey;
    }

    // Fallback: return default candidate 1
    AppLogger.warning(
      'Asset not physically found on disk during resolution: $assetKey. Falling back to: $candidate1',
      'WINDOWS_PATH',
    );
    return candidate1;
  }

  /// Normalizes a filesystem path for case-insensitive, canonical Windows comparison.
  /// Converts all slashes to backslashes, strips surrounding quotes, trims whitespace,
  /// and converts to lowercase.
  static String normalizePath(String path) {
    if (path.isEmpty) return '';
    var normalized = path.trim();
    if ((normalized.startsWith('"') && normalized.endsWith('"')) ||
        (normalized.startsWith("'") && normalized.endsWith("'"))) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }
    normalized = normalized.replaceAll('/', '\\');
    while (normalized.contains('\\\\')) {
      normalized = normalized.replaceAll('\\\\', '\\');
    }
    return normalized.toLowerCase();
  }

  /// Returns the standard per-user Windows Start Menu shell link created by local_notifier.
  /// Typically: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\<appName>.lnk`
  static String getNotificationShortcutPath({String appName = 'adhan_and_prayer'}) {
    final appData = Platform.environment['APPDATA'] ?? '';
    if (appData.isEmpty) return '';
    return '$appData\\Microsoft\\Windows\\Start Menu\\Programs\\$appName.lnk';
  }

  /// Inspects the application-owned per-user notification shortcut.
  /// If it exists and points to an outdated executable (e.g. a previous development
  /// build path), it repairs/recreates the shortcut so that it points to the currently
  /// executing [resolvedExecutable] with WorkingDirectory set to [executableDirectory].
  ///
  /// This operation is strictly idempotent. If the shortcut already points to the current
  /// executable, no changes are performed.
  static Future<void> repairNotificationShortcutIfNeeded({String appName = 'adhan_and_prayer'}) async {
    if (!Platform.isWindows) return;

    final shortcutPath = getNotificationShortcutPath(appName: appName);
    if (shortcutPath.isEmpty) return;

    final shortcutFile = File(shortcutPath);
    if (!shortcutFile.existsSync()) {
      AppLogger.info(
        'Notification shortcut does not exist yet at: "$shortcutPath". Setup will create it.',
        'WINDOWS_PATH',
      );
      return;
    }

    try {
      final currentExe = resolvedExecutable;
      final currentExeDir = executableDirectory;
      final normalizedCurrentExe = normalizePath(currentExe);

      // Query current shortcut target via WScript.Shell
      final script = '''
\$ws = New-Object -ComObject WScript.Shell
\$s = \$ws.CreateShortcut('$shortcutPath')
Write-Host \$s.TargetPath
''';

      final queryResult = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
      ]);

      if (queryResult.exitCode == 0) {
        final existingTarget = (queryResult.stdout as String).trim();
        final normalizedExisting = normalizePath(existingTarget);

        if (normalizedExisting.isNotEmpty && normalizedExisting == normalizedCurrentExe) {
          AppLogger.info(
            'Notification shortcut is already verified and points to current executable: "$existingTarget"',
            'WINDOWS_PATH',
          );
          return;
        }

        AppLogger.warning(
          'Stale notification shortcut target detected! Existing: "$existingTarget" | Expected: "$currentExe". Repairing...',
          'WINDOWS_PATH',
        );
      } else {
        AppLogger.warning(
          'Failed to inspect shortcut target (exitCode: ${queryResult.exitCode}). Forcing shortcut refresh.',
          'WINDOWS_PATH',
        );
      }

      // Repair or rewrite shortcut pointing to the current executable
      final repairScript = '''
\$ws = New-Object -ComObject WScript.Shell
\$s = \$ws.CreateShortcut('$shortcutPath')
\$s.TargetPath = '$currentExe'
\$s.WorkingDirectory = '$currentExeDir'
\$s.Save()
''';

      final repairResult = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        repairScript,
      ]);

      if (repairResult.exitCode == 0) {
        AppLogger.info(
          'Successfully repaired notification shortcut to point to: "$currentExe"',
          'WINDOWS_PATH',
        );
      } else {
        AppLogger.error(
          'Error repairing notification shortcut: ${repairResult.stderr}',
          null,
          null,
          'WINDOWS_PATH',
        );
      }
    } catch (e, stack) {
      AppLogger.error('Exception during notification shortcut validation/repair', e, stack, 'WINDOWS_PATH');
    }
  }

  /// Inspects the Windows Registry `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
  /// entry for [appName]. If an entry exists and points to an obsolete executable
  /// (such as an old development build path), it updates the registry value to point
  /// to the currently executing [resolvedExecutable].
  ///
  /// Leaves unrelated entries untouched.
  static Future<void> repairLaunchAtStartupIfNeeded({String appName = 'adhan_and_prayer'}) async {
    if (!Platform.isWindows) return;

    try {
      final currentExe = resolvedExecutable;
      final normalizedCurrentExe = normalizePath(currentExe);

      final script = '''
\$val = (Get-ItemProperty -Path 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run' -Name '$appName' -ErrorAction SilentlyContinue).'$appName'
if (\$val) { Write-Host \$val }
''';

      final queryResult = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
      ]);

      if (queryResult.exitCode == 0) {
        final existingValue = (queryResult.stdout as String).trim();
        if (existingValue.isEmpty) {
          // Launch at startup is not registered for this app; nothing to repair.
          return;
        }

        final normalizedExisting = normalizePath(existingValue);
        if (normalizedExisting == normalizedCurrentExe) {
          AppLogger.info(
            'Launch at startup registry entry already matches current executable: "$existingValue"',
            'WINDOWS_PATH',
          );
          return;
        }

        AppLogger.warning(
          'Stale launch at startup registry entry detected! Existing: "$existingValue" | Expected: "$currentExe". Repairing...',
          'WINDOWS_PATH',
        );

        final updateScript = '''
Set-ItemProperty -Path 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run' -Name '$appName' -Value '$currentExe'
''';
        final updateResult = await Process.run('powershell', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          updateScript,
        ]);

        if (updateResult.exitCode == 0) {
          AppLogger.info(
            'Successfully repaired launch at startup registry entry to point to: "$currentExe"',
            'WINDOWS_PATH',
          );
        } else {
          AppLogger.error(
            'Error updating launch at startup registry entry: ${updateResult.stderr}',
            null,
            null,
            'WINDOWS_PATH',
          );
        }
      }
    } catch (e, stack) {
      AppLogger.error('Exception during launch at startup repair', e, stack, 'WINDOWS_PATH');
    }
  }
}


