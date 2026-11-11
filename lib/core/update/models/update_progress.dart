enum UpdateStep {
  idle,
  downloading,
  verifyingSize,
  verifyingSha256,
  readyToInstall,
  installing,
  failed,
}

class UpdateProgress {
  final UpdateStep step;
  final int receivedBytes;
  final int totalBytes;
  final double percentage;
  final String? message;
  final String? filePath;

  const UpdateProgress({
    required this.step,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.percentage = 0.0,
    this.message,
    this.filePath,
  });

  factory UpdateProgress.idle() =>
      const UpdateProgress(step: UpdateStep.idle);

  factory UpdateProgress.downloading({
    required int receivedBytes,
    required int totalBytes,
  }) {
    final double pct = totalBytes > 0
        ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
        : 0.0;
    return UpdateProgress(
      step: UpdateStep.downloading,
      receivedBytes: receivedBytes,
      totalBytes: totalBytes,
      percentage: pct,
    );
  }

  factory UpdateProgress.verifyingSize() => const UpdateProgress(
        step: UpdateStep.verifyingSize,
        percentage: 1.0,
      );

  factory UpdateProgress.verifyingSha256() => const UpdateProgress(
        step: UpdateStep.verifyingSha256,
        percentage: 1.0,
      );

  factory UpdateProgress.readyToInstall(String path) => UpdateProgress(
        step: UpdateStep.readyToInstall,
        percentage: 1.0,
        filePath: path,
      );

  factory UpdateProgress.installing() => const UpdateProgress(
        step: UpdateStep.installing,
        percentage: 1.0,
      );

  factory UpdateProgress.failed(String errorMessage) => UpdateProgress(
        step: UpdateStep.failed,
        message: errorMessage,
      );
}
