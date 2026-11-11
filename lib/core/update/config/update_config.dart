/// Configuration contract for the generic Auto-Update System.
/// Applications provide their own instance to the update engine.
class AppUpdateConfig {
  /// Unique identifier of the application inside `version.json` (e.g. 'adhan_and_prayer').
  final String appId;

  /// HTTPS URL pointing to the centralized `version.json` registry.
  final String metadataUrl;

  /// Current semantic version name of the application (e.g. '1.0.0').
  final String currentVersion;

  /// Current build/version code of the application (e.g. 1).
  final int currentVersionCode;

  const AppUpdateConfig({
    required this.appId,
    required this.metadataUrl,
    required this.currentVersion,
    required this.currentVersionCode,
  });

  @override
  String toString() =>
      'AppUpdateConfig(appId: $appId, version: $currentVersion, code: $currentVersionCode, url: $metadataUrl)';
}
