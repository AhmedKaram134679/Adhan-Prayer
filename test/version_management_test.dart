import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/core/config/app_branding.dart';
import 'package:adhan_and_prayer/core/config/app_version.dart';
import 'package:adhan_and_prayer/core/update/config/update_config.dart';

void main() {
  group('Centralized Application Version Management Tests', () {
    test('AppBranding.appVersion matches AppVersion.versionName', () {
      expect(AppBranding.appVersion, equals(AppVersion.versionName));
      expect(AppBranding.appVersion, isNotEmpty);
    });

    test('AppVersion matches pubspec.yaml authoritative version', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue,
          reason: 'pubspec.yaml must exist at project root');

      final lines = pubspecFile.readAsLinesSync();
      final versionRegex =
          RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?$');

      String? pubspecVersionName;
      int? pubspecVersionCode;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('version:')) {
          final match = versionRegex.firstMatch(trimmed);
          expect(match, isNotNull,
              reason: 'pubspec.yaml version must match semantic pattern X.Y.Z or X.Y.Z+N');
          pubspecVersionName = match!.group(1);
          pubspecVersionCode = int.parse(match.group(2) ?? '1');
          break;
        }
      }

      expect(pubspecVersionName, isNotNull,
          reason: 'pubspec.yaml must define a version');
      expect(AppVersion.versionName, equals(pubspecVersionName));
      expect(AppVersion.versionCode, equals(pubspecVersionCode));
      expect(AppVersion.fullVersion,
          equals('$pubspecVersionName+$pubspecVersionCode'));
    });

    test('AppUpdateConfig receives synchronized AppVersion parameters', () {
      const config = AppUpdateConfig(
        appId: 'adhan_and_prayer',
        metadataUrl: 'https://example.com/version.json',
        currentVersion: AppVersion.versionName,
        currentVersionCode: AppVersion.versionCode,
      );

      expect(config.currentVersion, equals(AppVersion.versionName));
      expect(config.currentVersionCode, equals(AppVersion.versionCode));
      expect(config.currentVersion, equals(AppBranding.appVersion));
    });

    test('AppVersion format is valid and non-zero', () {
      expect(AppVersion.versionName, matches(RegExp(r'^\d+\.\d+\.\d+$')));
      expect(AppVersion.versionCode, isPositive);
      expect(AppVersion.fullVersion,
          equals('${AppVersion.versionName}+${AppVersion.versionCode}'));
    });
  });
}
