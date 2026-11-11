import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';

/// Stream-based SHA-256 integrity validator.
/// Handles large files efficiently without loading entire binaries into memory.
class Sha256Validator {
  Sha256Validator._();

  /// Computes the SHA-256 hash of [file] in a streaming manner.
  static Future<String> computeFileHash(File file) async {
    if (!await file.exists()) {
      throw FileNotFoundException('File not found for hash calculation: ${file.path}');
    }

    final output = await sha256.bind(file.openRead()).first;
    return output.toString().toLowerCase();
  }

  /// Verifies that [file]'s SHA-256 matches [expectedHash].
  /// Returns `true` if matched, `false` otherwise.
  static Future<bool> verify({
    required File file,
    required String expectedHash,
  }) async {
    final cleanExpected = expectedHash.trim().toLowerCase();
    if (cleanExpected.isEmpty) {
      AppLogger.warning('Expected SHA-256 hash is empty. Verification rejected.', 'SHA256');
      return false;
    }

    try {
      final calculatedHash = await computeFileHash(file);
      final isMatch = calculatedHash == cleanExpected;
      if (isMatch) {
        AppLogger.info('SHA-256 verification passed for: ${file.path}', 'SHA256');
      } else {
        AppLogger.warning(
          'SHA-256 mismatch!\n'
          'Expected:   $cleanExpected\n'
          'Calculated: $calculatedHash\n'
          'File: ${file.path}',
          'SHA256',
        );
      }
      return isMatch;
    } catch (e, stack) {
      AppLogger.error('Error during SHA-256 verification', e, stack, 'SHA256');
      return false;
    }
  }
}

class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);
  @override
  String toString() => 'FileNotFoundException: $message';
}
