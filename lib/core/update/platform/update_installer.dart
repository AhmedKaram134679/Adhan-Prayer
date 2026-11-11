import 'dart:io';

class InstallResult {
  final bool success;
  final String? errorMessage;

  const InstallResult.success()
      : success = true,
        errorMessage = null;

  const InstallResult.failure(this.errorMessage) : success = false;

  @override
  String toString() => success ? 'InstallResult.success' : 'InstallResult.failure: $errorMessage';
}

/// Abstract contract for platform-specific update installation.
/// Isolates operating system commands, intents, and elevation mechanics
/// from the core update engine.
abstract class UpdateInstaller {
  /// File extension used on this platform (e.g. '.apk' or '.exe').
  String get fileExtension;

  /// Identifier name of the platform matching `version.json` (e.g. 'android' or 'windows').
  String get platformName;

  /// Executes the verified update file.
  Future<InstallResult> install(File updateFile);
}
