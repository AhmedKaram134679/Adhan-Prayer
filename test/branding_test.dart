import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/core/config/app_branding.dart';

import 'package:adhan_and_prayer/core/config/app_version.dart';

void main() {
  group('AppBranding Constants & Integrity Tests', () {
    test('Branding attributes are configured with real values', () {
      expect(AppBranding.appLogoAsset, equals('assets/app_icon.png'));
      expect(AppBranding.appVersion, equals(AppVersion.versionName));
      expect(AppBranding.appVersion.isNotEmpty, isTrue);
      expect(AppBranding.developerName, equals('Ahmed Karam'));
      expect(AppBranding.academyNameEn, equals('Smart Academy'));
      expect(AppBranding.academyNameAr, equals('أكاديمية سمارت'));
      expect(AppBranding.socialMediaUrl, equals('https://www.facebook.com/AhmedKaramFathy/'));
      expect(AppBranding.socialMediaDisplay, equals('AhmedKaramFathy'));
      expect(AppBranding.developerPhotoAsset, equals('assets/developer/developer_photo.jpg'));
    });
  });
}
