import 'dart:developer' as developer;

class AppLogger {
  static void debug(String message, [String tag = 'APP']) {
    developer.log('[DEBUG] [$tag] $message');
  }

  static void info(String message, [String tag = 'APP']) {
    developer.log('[INFO] [$tag] $message');
  }

  static void warning(String message, [String tag = 'APP']) {
    developer.log('[WARN] [$tag] $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace, String tag = 'APP']) {
    developer.log(
      '[ERROR] [$tag] $message',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
