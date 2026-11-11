/// Platform binary details from `version.json`.
class PlatformReleaseInfo {
  final String url;
  final String sha256;
  final int? size;

  const PlatformReleaseInfo({
    required this.url,
    required this.sha256,
    this.size,
  });

  factory PlatformReleaseInfo.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['url'] ?? json['download_url'] as String? ?? '';
    final rawSha256 = json['sha256'] as String? ?? '';
    final rawSize = json['size'] ?? json['file_size_bytes'];

    int? parsedSize;
    if (rawSize is int) {
      parsedSize = rawSize;
    } else if (rawSize is String) {
      parsedSize = int.tryParse(rawSize);
    }

    return PlatformReleaseInfo(
      url: (rawUrl as String).trim(),
      sha256: rawSha256.trim().toLowerCase(),
      size: parsedSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'sha256': sha256,
        if (size != null) 'size': size,
      };
}

/// Release metadata for a specific application in `version.json`.
class AppReleaseInfo {
  final String versionName;
  final int versionCode;
  final bool forceUpdate;
  final List<String> releaseNotes;
  final Map<String, PlatformReleaseInfo> platforms;

  const AppReleaseInfo({
    required this.versionName,
    required this.versionCode,
    required this.forceUpdate,
    required this.releaseNotes,
    required this.platforms,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final versionName = json['version_name'] ?? json['latest_version'] as String? ?? '';
    final rawVersionCode = json['version_code'] ?? json['latest_version_code'];
    final versionCode = rawVersionCode is int
        ? rawVersionCode
        : int.tryParse(rawVersionCode?.toString() ?? '') ?? 0;

    final forceUpdate = json['force_update'] ?? json['critical_update'] as bool? ?? false;

    final rawNotes = json['release_notes'];
    final List<String> releaseNotes = [];
    if (rawNotes is List) {
      for (final item in rawNotes) {
        if (item != null) releaseNotes.add(item.toString());
      }
    } else if (rawNotes is String && rawNotes.isNotEmpty) {
      releaseNotes.add(rawNotes);
    }

    final Map<String, PlatformReleaseInfo> platforms = {};
    final rawPlatforms = json['platforms'];
    if (rawPlatforms is Map<String, dynamic>) {
      for (final entry in rawPlatforms.entries) {
        if (entry.value is Map<String, dynamic>) {
          platforms[entry.key.toLowerCase()] =
              PlatformReleaseInfo.fromJson(entry.value as Map<String, dynamic>);
        }
      }
    }

    return AppReleaseInfo(
      versionName: versionName.trim(),
      versionCode: versionCode,
      forceUpdate: forceUpdate,
      releaseNotes: releaseNotes,
      platforms: platforms,
    );
  }

  PlatformReleaseInfo? getPlatform(String platformName) {
    return platforms[platformName.toLowerCase()];
  }
}

/// Root multi-application metadata parsed from `version.json`.
class VersionRegistry {
  final Map<String, AppReleaseInfo> apps;

  const VersionRegistry({required this.apps});

  factory VersionRegistry.fromJson(Map<String, dynamic> json) {
    final Map<String, AppReleaseInfo> apps = {};
    final rawApps = json['apps'] ?? json['applications'];
    if (rawApps is Map<String, dynamic>) {
      for (final entry in rawApps.entries) {
        if (entry.value is Map<String, dynamic>) {
          apps[entry.key] =
              AppReleaseInfo.fromJson(entry.value as Map<String, dynamic>);
        }
      }
    }
    return VersionRegistry(apps: apps);
  }

  AppReleaseInfo? getApp(String appId) {
    return apps[appId];
  }
}
