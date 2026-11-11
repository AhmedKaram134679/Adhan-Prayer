import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:adhan_and_prayer/core/update/models/update_progress.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';

/// Robust, chunked HTTPS update downloader with size verification and progress emission.
class UpdateDownloader {
  final HttpClient _httpClient;

  UpdateDownloader({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient()
          ..connectionTimeout = const Duration(seconds: 30);

  /// Downloads an update from [downloadUrl] to an isolated cache file.
  /// Reports [UpdateProgress] through the returned stream.
  Stream<UpdateProgress> download({
    required String downloadUrl,
    required String fileExtension,
    int? expectedSize,
  }) async* {
    yield UpdateProgress.idle();

    final uri = Uri.tryParse(downloadUrl);
    if (uri == null || uri.scheme != 'https') {
      yield UpdateProgress.failed(
          'Security policy violation: Only HTTPS download URLs are permitted ($downloadUrl)');
      return;
    }

    File? targetFile;
    File? tempFile;
    IOSink? sink;

    try {
      AppLogger.info('Starting update download from: $downloadUrl', 'DOWNLOADER');

      // 1. Prepare target directory
      final tempDir = await getTemporaryDirectory();
      final updatesDir = Directory('${tempDir.path}${Platform.pathSeparator}updates');
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
      }

      final fileName = 'update_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      targetFile = File('${updatesDir.path}${Platform.pathSeparator}$fileName');
      tempFile = File('${targetFile.path}.tmp');

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      // 2. Initiate HTTPS request
      final request = await _httpClient.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        yield UpdateProgress.failed(
            'Download failed with HTTP status ${response.statusCode}: ${response.reasonPhrase}');
        return;
      }

      final contentLength = response.contentLength;
      final totalBytes = (contentLength > 0)
          ? contentLength
          : (expectedSize != null && expectedSize > 0 ? expectedSize : 0);

      sink = tempFile.openWrite();
      int receivedBytes = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        yield UpdateProgress.downloading(
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // 3. File-size verification if provided
      yield UpdateProgress.verifyingSize();

      final actualSize = await tempFile.length();
      if (expectedSize != null && expectedSize > 0 && actualSize != expectedSize) {
        AppLogger.warning(
          'File size mismatch. Expected: $expectedSize, Received: $actualSize',
          'DOWNLOADER',
        );
        if (await tempFile.exists()) await tempFile.delete();
        yield UpdateProgress.failed(
            'Downloaded file size ($actualSize bytes) does not match expected size ($expectedSize bytes).');
        return;
      }

      // Rename from .tmp to final target file
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);

      AppLogger.info('Download completed successfully: ${targetFile.path}', 'DOWNLOADER');
      yield UpdateProgress.readyToInstall(targetFile.path);
    } catch (e, stack) {
      AppLogger.error('Error during update download', e, stack, 'DOWNLOADER');
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      yield UpdateProgress.failed('Download error: $e');
    }
  }

  void close() {
    _httpClient.close();
  }
}
