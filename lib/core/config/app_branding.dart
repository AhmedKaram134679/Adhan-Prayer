import 'package:adhan_and_prayer/core/config/app_version.dart';

/// Centralized source of truth for application branding, developer attribution,
/// academy institution, and social media connectivity.
class AppBranding {
  AppBranding._();

  // 1. Application Branding
  static const String appLogoAsset = 'assets/app_icon.png';
  static String get appVersion => AppVersion.versionName;

  // 2. Developer Profile
  /// Path to the developer's personal photo. Place the image at this path:
  /// `assets/developer/developer_photo.png`
  static const String developerPhotoAsset =
      'assets/developer/developer_photo.jpg';

  /// Developer name requested by the course instructor
  static const String developerName = 'Ahmed Karam';

  // 3. Academy Attribution
  static const String academyNameEn = 'Smart Academy';
  static const String academyNameAr = 'أكاديمية سمارت';

  // 4. Social Media / Contact Link
  /// Configured social link URL to be opened when tapped
  static const String socialMediaUrl =
      'https://www.facebook.com/AhmedKaramFathy/';

  /// Friendly display handle or text for the social link
  static const String socialMediaDisplay = 'AhmedKaramFathy';
}
