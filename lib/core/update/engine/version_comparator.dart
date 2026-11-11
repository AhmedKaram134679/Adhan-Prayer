/// Semantic version and version_code comparator with strict downgrade protection.
class VersionComparator {
  VersionComparator._();

  /// Compares local and remote version information.
  /// Returns:
  /// - `1` if remote is strictly newer than current (Update available)
  /// - `0` if remote equals current (Same version)
  /// - `-1` if remote is strictly older than current (Downgrade rejected)
  static int compare({
    required String currentVersion,
    required int currentVersionCode,
    required String remoteVersion,
    required int remoteVersionCode,
  }) {
    // 1. Authoritative check: If version codes are both provided and valid (> 0),
    // version code comparison is the primary ordering mechanism.
    if (currentVersionCode > 0 && remoteVersionCode > 0) {
      if (remoteVersionCode > currentVersionCode) return 1;
      if (remoteVersionCode < currentVersionCode) return -1;
      // If version codes are identical, check semantic version strings as tie-breaker
      return compareSemVer(remoteVersion, currentVersion);
    }

    // 2. Fallback to Semantic Version string comparison
    return compareSemVer(remoteVersion, currentVersion);
  }

  /// Compares two semantic version strings (e.g. "1.10.0" vs "1.9.0").
  /// Returns 1 if v1 > v2, 0 if v1 == v2, -1 if v1 < v2.
  static int compareSemVer(String v1, String v2) {
    final cleanV1 = _cleanVersion(v1);
    final cleanV2 = _cleanVersion(v2);

    final parts1 = cleanV1.map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = cleanV2.map((p) => int.tryParse(p) ?? 0).toList();

    final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;

    for (int i = 0; i < maxLength; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;

      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }

    return 0;
  }

  static List<String> _cleanVersion(String version) {
    // Strip leading 'v' or 'V' (e.g. 'v1.2.3' -> '1.2.3')
    String v = version.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }

    // Strip build metadata after '+' or pre-release after '-'
    final plusIndex = v.indexOf('+');
    if (plusIndex != -1) {
      v = v.substring(0, plusIndex);
    }
    final dashIndex = v.indexOf('-');
    if (dashIndex != -1) {
      v = v.substring(0, dashIndex);
    }

    return v.split('.').where((s) => s.isNotEmpty).toList();
  }
}
