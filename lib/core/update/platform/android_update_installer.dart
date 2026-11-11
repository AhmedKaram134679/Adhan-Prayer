import 'dart:io';
import 'package:flutter/services.dart';
import 'package:adhan_and_prayer/core/update/platform/update_installer.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';

/// Android update installer that delegates to native Android PackageInstaller
/// via FileProvider and Intent.ACTION_VIEW.
class AndroidUpdateInstaller implements UpdateInstaller {
  static const MethodChannel _channel =
      MethodChannel('com.example.adhan_and_prayer/alarm');

  @override
  String get fileExtension => '.apk';

  @override
  String get platformName => 'android';

  @override
  Future<InstallResult> install(File updateFile) async {
    if (!await updateFile.exists()) {
      return const InstallResult.failure('APK file does not exist on disk.');
    }

    try {
      AppLogger.info('Invoking Android native package installer for: ${updateFile.path}', 'INSTALLER');
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'installApk',
        {'filePath': updateFile.path},
      );

      final success = result?['success'] as bool? ?? false;
      final error = result?['error'] as String?;

      if (success) {
        return const InstallResult.success();
      } else {
        return InstallResult.failure(error ?? 'Failed to launch Android package installer.');
      }
    } catch (e, stack) {
      AppLogger.error('Failed to launch Android APK installer', e, stack, 'INSTALLER');
      return InstallResult.failure('Android installation exception: $e');
    }
  }
}
