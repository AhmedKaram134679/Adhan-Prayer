import 'dart:convert';
import 'dart:io';
import 'package:adhan_and_prayer/core/update/engine/update_engine.dart';
import 'package:adhan_and_prayer/core/update/presentation/cubit/update_cubit.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/core/update/config/update_config.dart';
import 'package:adhan_and_prayer/core/update/engine/sha256_validator.dart';
import 'package:adhan_and_prayer/core/update/engine/version_comparator.dart';
import 'package:adhan_and_prayer/core/update/models/update_metadata.dart';
import 'package:adhan_and_prayer/core/update/platform/update_installer.dart';

class MockTestInstaller implements UpdateInstaller {
  bool installed = false;
  File? installedFile;

  @override
  String get fileExtension => '.bin';

  @override
  String get platformName => 'test_os';

  @override
  Future<InstallResult> install(File updateFile) async {
    installed = true;
    installedFile = updateFile;
    return const InstallResult.success();
  }
}

void main() {
  group('VersionComparator Tests', () {
    test('compareSemVer correctly handles standard and multi-digit semantic versions', () {
      expect(VersionComparator.compareSemVer('1.0.1', '1.0.0'), greaterThan(0));
      expect(VersionComparator.compareSemVer('1.0.10', '1.0.9'), greaterThan(0));
      expect(VersionComparator.compareSemVer('1.10.0', '1.9.0'), greaterThan(0));
      expect(VersionComparator.compareSemVer('2.0.0', '1.99.99'), greaterThan(0));
    });

    test('compareSemVer correctly identifies equal versions', () {
      expect(VersionComparator.compareSemVer('1.0.0', '1.0.0'), equals(0));
      expect(VersionComparator.compareSemVer('v1.0.0', '1.0.0'), equals(0));
      expect(VersionComparator.compareSemVer('1.0.0+1', '1.0.0+2'), equals(0));
    });

    test('compareSemVer correctly detects lower versions', () {
      expect(VersionComparator.compareSemVer('1.0.0', '1.0.1'), lessThan(0));
      expect(VersionComparator.compareSemVer('1.0.9', '1.0.10'), lessThan(0));
      expect(VersionComparator.compareSemVer('0.9.0', '1.0.0'), lessThan(0));
    });

    test('Version code is authoritative ordering mechanism', () {
      // Even if version name looks identical or lower, higher version_code triggers update
      expect(
        VersionComparator.compare(
          currentVersion: '1.0.0',
          currentVersionCode: 10,
          remoteVersion: '1.0.0',
          remoteVersionCode: 11,
        ),
        greaterThan(0),
      );

      // Downgrade rejected when remote version_code is lower
      expect(
        VersionComparator.compare(
          currentVersion: '1.0.1',
          currentVersionCode: 11,
          remoteVersion: '1.0.2', // deceptively higher semver, but lower code
          remoteVersionCode: 10,
        ),
        lessThan(0),
      );

      // Same version code and same version name -> 0
      expect(
        VersionComparator.compare(
          currentVersion: '1.0.0',
          currentVersionCode: 11,
          remoteVersion: '1.0.0',
          remoteVersionCode: 11,
        ),
        equals(0),
      );
    });
  });

  group('UpdateMetadata Registry Parsing Tests', () {
    const rawCanonicalJson = '''
    {
      "apps": {
        "app_alpha": {
          "version_name": "1.2.0",
          "version_code": 12,
          "force_update": true,
          "release_notes": [
            "Critical security patch",
            "Stability improvement"
          ],
          "platforms": {
            "android": {
              "url": "https://github.com/org/repo/releases/download/v1.2.0/app-alpha.apk",
              "sha256": "aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222",
              "size": 123456
            },
            "windows": {
              "url": "https://github.com/org/repo/releases/download/v1.2.0/app-alpha-setup.exe",
              "sha256": "bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222cccc3333",
              "size": 654321
            }
          }
        },
        "app_beta": {
          "version_name": "2.0.0",
          "version_code": 20,
          "force_update": false,
          "release_notes": ["Major release"],
          "platforms": {
            "android": {
              "url": "https://example.com/beta.apk",
              "sha256": "123456",
              "size": 500000
            }
          }
        }
      }
    }
    ''';

    test('Parses multi-application canonical registry with force update', () {
      final data = jsonDecode(rawCanonicalJson) as Map<String, dynamic>;
      final registry = VersionRegistry.fromJson(data);

      expect(registry.getApp('non_existent'), isNull);

      final appAlpha = registry.getApp('app_alpha');
      expect(appAlpha, isNotNull);
      expect(appAlpha!.versionName, equals('1.2.0'));
      expect(appAlpha.versionCode, equals(12));
      expect(appAlpha.forceUpdate, isTrue);
      expect(appAlpha.releaseNotes.length, equals(2));

      final androidPlatform = appAlpha.getPlatform('android');
      expect(androidPlatform, isNotNull);
      expect(androidPlatform!.url, contains('app-alpha.apk'));
      expect(androidPlatform.size, equals(123456));

      final windowsPlatform = appAlpha.getPlatform('windows');
      expect(windowsPlatform, isNotNull);
      expect(windowsPlatform!.size, equals(654321));

      final appBeta = registry.getApp('app_beta');
      expect(appBeta, isNotNull);
      expect(appBeta!.forceUpdate, isFalse);
      expect(appBeta.getPlatform('windows'), isNull);
    });

    test('Invalid or empty metadata fails safely without crashing', () {
      final registryEmpty = VersionRegistry.fromJson({});
      expect(registryEmpty.apps.isEmpty, isTrue);
      expect(registryEmpty.getApp('any'), isNull);

      final malformedApp = AppReleaseInfo.fromJson({});
      expect(malformedApp.versionName, isEmpty);
      expect(malformedApp.versionCode, equals(0));
      expect(malformedApp.forceUpdate, isFalse);
      expect(malformedApp.platforms.isEmpty, isTrue);
    });
  });

  group('Sha256Validator Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sha256_audit_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Calculates and validates matching SHA-256 hash', () async {
      final file = File('${tempDir.path}/test.bin');
      const testContent = 'Production Auto-Update Payload Invariant 2026';
      await file.writeAsString(testContent);

      final expectedHash = sha256.convert(utf8.encode(testContent)).toString();

      final isValid = await Sha256Validator.verify(
        file: file,
        expectedHash: expectedHash,
      );

      expect(isValid, isTrue);
    });

    test('Rejects on SHA-256 mismatch', () async {
      final file = File('${tempDir.path}/corrupt.bin');
      await file.writeAsString('Legitimate Content');

      final isValid = await Sha256Validator.verify(
        file: file,
        expectedHash: '0000000000000000000000000000000000000000000000000000000000000000',
      );

      expect(isValid, isFalse);
    });

    test('Rejects on empty or whitespace expected hash', () async {
      final file = File('${tempDir.path}/test.bin');
      await file.writeAsString('Content');

      expect(await Sha256Validator.verify(file: file, expectedHash: ''), isFalse);
      expect(await Sha256Validator.verify(file: file, expectedHash: '   '), isFalse);
    });
  });

  group('Mock Installer Abstraction Test', () {
    test('Installer contract allows safe mocking without spawning native binaries', () async {
      final installer = MockTestInstaller();
      expect(installer.platformName, equals('test_os'));
      expect(installer.fileExtension, equals('.bin'));

      final dummyFile = File('dummy.bin');
      final result = await installer.install(dummyFile);

      expect(result.success, isTrue);
      expect(installer.installed, isTrue);
      expect(installer.installedFile, equals(dummyFile));
    });
  });

  group('AppUpdateConfig Tests', () {
    test('Holds platform-agnostic configuration without hardcoded application identity', () {
      const config1 = AppUpdateConfig(
        appId: 'adhan_and_prayer',
        metadataUrl: 'https://raw.githubusercontent.com/AhmedKaramFathy/adhan_and_prayer/main/version.json',
        currentVersion: '1.0.0',
        currentVersionCode: 1,
      );

      const config2 = AppUpdateConfig(
        appId: 'another_flutter_app',
        metadataUrl: 'https://example.com/version.json',
        currentVersion: '2.5.0',
        currentVersionCode: 25,
      );

      expect(config1.appId, equals('adhan_and_prayer'));
      expect(config2.appId, equals('another_flutter_app'));
      expect(config2.currentVersion, equals('2.5.0'));
      expect(config2.currentVersionCode, equals(25));
    });
  });

  group('UpdateEngine Failure & Distinction Semantics Tests', () {
    test('Non-HTTPS or invalid metadata URL throws AppException and does not return noUpdate', () async {
      const config = AppUpdateConfig(
        appId: 'adhan_and_prayer',
        metadataUrl: 'http://insecure.example.com/version.json',
        currentVersion: '1.2.0',
        currentVersionCode: 3,
      );
      final engine = UpdateEngine(config: config, installer: MockTestInstaller());

      expect(
        () => engine.checkForUpdate(),
        throwsA(isA<Exception>()),
      );
    });

    test('Network failure when reaching metadata URL throws AppException and does not report noUpdate', () async {
      const config = AppUpdateConfig(
        appId: 'adhan_and_prayer',
        metadataUrl: 'https://invalid-non-existent-domain-987654321.org/version.json',
        currentVersion: '1.2.0',
        currentVersionCode: 3,
      );
      final engine = UpdateEngine(config: config, installer: MockTestInstaller());

      expect(
        () => engine.checkForUpdate(),
        throwsA(isA<Exception>()),
      );
    });

    test('UpdateCubit emits UpdateErrorState and NOT UpdateNotAvailableState on network/check failure', () async {
      const config = AppUpdateConfig(
        appId: 'adhan_and_prayer',
        metadataUrl: 'https://invalid-non-existent-domain-987654321.org/version.json',
        currentVersion: '1.2.0',
        currentVersionCode: 3,
      );
      final engine = UpdateEngine(config: config, installer: MockTestInstaller());
      final cubit = UpdateCubit(engine: engine);

      final emittedStates = <UpdateState>[];
      final sub = cubit.stream.listen(emittedStates.add);

      await cubit.checkForUpdates(userInitiated: true);
      await Future<void>.delayed(Duration.zero);

      expect(emittedStates.any((s) => s is UpdateCheckingState), isTrue);
      expect(emittedStates.any((s) => s is UpdateErrorState), isTrue);
      expect(emittedStates.any((s) => s is UpdateNotAvailableState), isFalse);
      await sub.cancel();
    });

    test('Real production metadata detects update when current is 1.2.0+3 and remote is newer (1.4.0+5)', () async {
      // Test platform android
      final androidInstaller = _MockPlatformInstaller('android');
      const config = AppUpdateConfig(
        appId: 'adhan_and_prayer',
        metadataUrl: 'https://raw.githubusercontent.com/AhmedKaram222/ahmed-app-updates/main/Adhan%20&%20Prayer/version.json',
        currentVersion: '1.2.0',
        currentVersionCode: 3,
      );
      final engine = UpdateEngine(config: config, installer: androidInstaller);
      final result = await engine.checkForUpdate();

      expect(result.hasUpdate, isTrue);
      expect(result.targetVersion, equals('1.4.0'));
      expect(result.targetVersionCode, equals(5));
      expect(result.platformRelease, isNotNull);
      expect(result.platformRelease!.url, contains('.apk'));
    });

    test('Real production metadata detects No Update when current matches remote (1.4.0+5)', () async {
      final androidInstaller = _MockPlatformInstaller('android');
      const config = AppUpdateConfig(
        appId: 'adhan_and_prayer',
        metadataUrl: 'https://raw.githubusercontent.com/AhmedKaram222/ahmed-app-updates/main/Adhan%20&%20Prayer/version.json',
        currentVersion: '1.4.0',
        currentVersionCode: 5,
      );
      final engine = UpdateEngine(config: config, installer: androidInstaller);
      final result = await engine.checkForUpdate();

      expect(result.hasUpdate, isFalse);
      expect(result.rejectionReason, equals('Already latest version'));
    });
  });
}

class _MockPlatformInstaller implements UpdateInstaller {
  final String _platform;
  _MockPlatformInstaller(this._platform);

  @override
  String get fileExtension => '.apk';

  @override
  String get platformName => _platform;

  @override
  Future<InstallResult> install(File updateFile) async => const InstallResult.success();
}

