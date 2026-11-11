import 'dart:io';
import 'package:flutter/services.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';

/// Cross-platform utility to open external URLs on both Windows and Android
/// without requiring extra unpinned external dependencies.
class ExternalLauncher {
  ExternalLauncher._();

  static const MethodChannel _androidChannel =
      MethodChannel('com.example.adhan_and_prayer/alarm');

  /// Opens an external [url] in the system's default browser or handler.
  static Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https'))) {
      AppLogger.warning('Invalid URL format for external launch: $url', 'LAUNCHER');
      return false;
    }

    try {
      if (Platform.isWindows) {
        // Use cmd /c start "" "<url>" which uses ShellExecute in Windows
        final result = await Process.run('cmd', ['/c', 'start', '', url]);
        return result.exitCode == 0;
      } else if (Platform.isAndroid) {
        // Delegate to native Android Intent via MethodChannel
        final success = await _androidChannel.invokeMethod<bool>('openUrl', {'url': url});
        return success ?? false;
      } else if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [url]);
        return result.exitCode == 0;
      } else if (Platform.isMacOS) {
        final result = await Process.run('open', [url]);
        return result.exitCode == 0;
      }
    } catch (e, stack) {
      AppLogger.error('Failed to open external URL $url', e, stack, 'LAUNCHER');
    }
    return false;
  }
}
