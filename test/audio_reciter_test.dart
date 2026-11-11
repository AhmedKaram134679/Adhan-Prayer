import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/features/adhan/data/repositories/audio_repository_impl.dart';

void main() {
  group('Audio & Reciters Catalog Tests', () {
    test('Reciter catalog provides valid audio assets and distinct IDs', () {
      final reciters = AudioRepositoryImpl.defaultReciters;

      expect(reciters.isNotEmpty, isTrue);
      final ids = reciters.map((r) => r.id).toSet();
      expect(ids.length, equals(reciters.length), reason: 'All reciter IDs must be unique');

      for (final r in reciters) {
        expect(r.assetPath.endsWith('.mp3'), isTrue);
        expect(r.nameAr.isNotEmpty, isTrue);
        expect(r.nameEn.isNotEmpty, isTrue);
        final file = File(r.assetPath);
        expect(file.existsSync(), isTrue, reason: 'Asset file must exist at ${r.assetPath}');
      }

      expect(reciters.any((r) => r.isDefault), isTrue);
    });
  });
}
