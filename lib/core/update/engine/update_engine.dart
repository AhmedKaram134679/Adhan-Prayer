import 'dart:convert';
import 'dart:io';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/update/config/update_config.dart';
import 'package:adhan_and_prayer/core/update/engine/sha256_validator.dart';
import 'package:adhan_and_prayer/core/update/engine/update_downloader.dart';
import 'package:adhan_and_prayer/core/update/engine/version_comparator.dart';
import 'package:adhan_and_prayer/core/update/models/update_info.dart';
import 'package:adhan_and_prayer/core/update/models/update_metadata.dart';
import 'package:adhan_and_prayer/core/update/models/update_progress.dart';
import 'package:adhan_and_prayer/core/update/platform/android_update_installer.dart';
import 'package:adhan_and_prayer/core/update/platform/update_installer.dart';
import 'package:adhan_and_prayer/core/update/platform/windows_update_installer.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';

/// Central, application-agnostic Update Engine.
/// Coordinates checking, downloading, verifying, and executing updates.
class UpdateEngine {
  final AppUpdateConfig config;
  final UpdateInstaller? _installer;
  final UpdateDownloader _downloader;
  final HttpClient _httpClient;

  UpdateEngine({
    required this.config,
    UpdateInstaller? installer,
    UpdateDownloader? downloader,
    HttpClient? httpClient,
  })  : _installer = installer ?? _resolveDefaultInstaller(),
        _downloader = downloader ?? UpdateDownloader(),
        _httpClient = httpClient ?? HttpClient()
          ..connectionTimeout = const Duration(seconds: 20);

  static UpdateInstaller? _resolveDefaultInstaller() {
    if (Platform.isAndroid) {
      return AndroidUpdateInstaller();
    } else if (Platform.isWindows) {
      return WindowsUpdateInstaller();
    }
    return null;
  }

  /// Platform installer active on this runtime.
  UpdateInstaller? get installer => _installer;

  /// Fetches and evaluates the centralized `version.json` for update availability.
  Future<UpdateInfo> checkForUpdate() async {
    final installer = _installer;
    if (installer == null) {
      AppLogger.info('Auto-update is not supported on current platform: ${Platform.operatingSystem}', 'UPDATE');
      return UpdateInfo.noUpdate(
        currentVersion: config.currentVersion,
        currentVersionCode: config.currentVersionCode,
        reason: 'Unsupported platform',
      );
    }

    final metadataUri = Uri.tryParse(config.metadataUrl);
    if (metadataUri == null || metadataUri.scheme != 'https') {
      AppLogger.warning('Invalid or non-HTTPS metadata URL: ${config.metadataUrl}', 'UPDATE');
      throw const AppException('Invalid metadata URL (HTTPS required)');
    }

    try {
      AppLogger.info('Checking for updates from: ${config.metadataUrl}', 'UPDATE');
      final request = await _httpClient.getUrl(metadataUri);
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        AppLogger.warning('Metadata check failed with HTTP ${response.statusCode}', 'UPDATE');
        throw AppException('HTTP ${response.statusCode}');
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> json = jsonDecode(responseBody) as Map<String, dynamic>;
      final registry = VersionRegistry.fromJson(json);

      final appRelease = registry.getApp(config.appId);
      if (appRelease == null) {
        AppLogger.warning('App ID "${config.appId}" not found in version.json registry', 'UPDATE');
        return UpdateInfo.noUpdate(
          currentVersion: config.currentVersion,
          currentVersionCode: config.currentVersionCode,
          reason: 'App ID not registered',
        );
      }

      final platformRelease = appRelease.getPlatform(installer.platformName);
      if (platformRelease == null || platformRelease.url.isEmpty) {
        AppLogger.info('No release binary available for platform: ${installer.platformName}', 'UPDATE');
        return UpdateInfo.noUpdate(
          currentVersion: config.currentVersion,
          currentVersionCode: config.currentVersionCode,
          reason: 'No release binary for this platform',
        );
      }

      // Version comparison & downgrade protection
      final comparison = VersionComparator.compare(
        currentVersion: config.currentVersion,
        currentVersionCode: config.currentVersionCode,
        remoteVersion: appRelease.versionName,
        remoteVersionCode: appRelease.versionCode,
      );

      if (comparison > 0) {
        AppLogger.info('Update available: ${config.currentVersion} -> ${appRelease.versionName}', 'UPDATE');
        return UpdateInfo(
          hasUpdate: true,
          isForced: appRelease.forceUpdate,
          currentVersion: config.currentVersion,
          currentVersionCode: config.currentVersionCode,
          targetVersion: appRelease.versionName,
          targetVersionCode: appRelease.versionCode,
          releaseNotes: appRelease.releaseNotes,
          platformRelease: platformRelease,
        );
      } else if (comparison < 0) {
        AppLogger.info('Downgrade rejected: remote ${appRelease.versionName} < current ${config.currentVersion}', 'UPDATE');
        return UpdateInfo.noUpdate(
          currentVersion: config.currentVersion,
          currentVersionCode: config.currentVersionCode,
          reason: 'Remote version is older than installed version (downgrade prevented)',
        );
      } else {
        AppLogger.info('Application is up to date: ${config.currentVersion}', 'UPDATE');
        return UpdateInfo.noUpdate(
          currentVersion: config.currentVersion,
          currentVersionCode: config.currentVersionCode,
          reason: 'Already latest version',
        );
      }
    } catch (e, stack) {
      AppLogger.error('Failed to check for updates', e, stack, 'UPDATE');
      if (e is AppException) rethrow;
      throw AppException('Update check failed: $e');
    }
  }

  /// Downloads, verifies SHA-256 and size, and yields progress states.
  Stream<UpdateProgress> downloadAndVerify(UpdateInfo updateInfo) async* {
    final platform = updateInfo.platformRelease;
    final installer = _installer;

    if (platform == null || installer == null) {
      yield UpdateProgress.failed('Invalid update configuration or unsupported platform.');
      return;
    }

    String? targetFilePath;

    await for (final progress in _downloader.download(
      downloadUrl: platform.url,
      fileExtension: installer.fileExtension,
      expectedSize: platform.size,
    )) {
      yield progress;
      if (progress.step == UpdateStep.readyToInstall) {
        targetFilePath = progress.filePath;
      } else if (progress.step == UpdateStep.failed) {
        return;
      }
    }

    if (targetFilePath == null) {
      yield UpdateProgress.failed('Downloaded file path was not returned.');
      return;
    }

    final targetFile = File(targetFilePath);
    if (!await targetFile.exists()) {
      yield UpdateProgress.failed('Downloaded file could not be found on disk.');
      return;
    }

    // SHA-256 Verification Step
    yield UpdateProgress.verifyingSha256();

    final isHashValid = await Sha256Validator.verify(
      file: targetFile,
      expectedHash: platform.sha256,
    );

    if (!isHashValid) {
      // PURGE Corrupted / Mismatched file immediately
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
      yield UpdateProgress.failed(
          'Security check failed: SHA-256 integrity mismatch. The update file was deleted for your safety.');
      return;
    }

    AppLogger.info('Update verified and ready to install: ${targetFile.path}', 'UPDATE');
    yield UpdateProgress.readyToInstall(targetFile.path);
  }

  /// Invokes platform installer for a verified update file.
  Future<InstallResult> install(String filePath) async {
    final installer = _installer;
    if (installer == null) {
      return const InstallResult.failure('No installer available for current platform.');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return const InstallResult.failure('Update file does not exist.');
    }

    return await installer.install(file);
  }

  void dispose() {
    _downloader.close();
    _httpClient.close();
  }
}
