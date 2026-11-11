import 'package:adhan_and_prayer/core/update/models/update_metadata.dart';

/// The evaluated update result presented to the application.
class UpdateInfo {
  final bool hasUpdate;
  final bool isForced;
  final String currentVersion;
  final int currentVersionCode;
  final String targetVersion;
  final int targetVersionCode;
  final List<String> releaseNotes;
  final PlatformReleaseInfo? platformRelease;
  final String? rejectionReason;

  const UpdateInfo({
    required this.hasUpdate,
    required this.isForced,
    required this.currentVersion,
    required this.currentVersionCode,
    required this.targetVersion,
    required this.targetVersionCode,
    required this.releaseNotes,
    this.platformRelease,
    this.rejectionReason,
  });

  factory UpdateInfo.noUpdate({
    required String currentVersion,
    required int currentVersionCode,
    String? reason,
  }) {
    return UpdateInfo(
      hasUpdate: false,
      isForced: false,
      currentVersion: currentVersion,
      currentVersionCode: currentVersionCode,
      targetVersion: currentVersion,
      targetVersionCode: currentVersionCode,
      releaseNotes: const [],
      rejectionReason: reason,
    );
  }

  @override
  String toString() =>
      'UpdateInfo(hasUpdate: $hasUpdate, forced: $isForced, current: $currentVersion($currentVersionCode), target: $targetVersion($targetVersionCode))';
}
