import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/core/storage/local_storage.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';
import 'package:adhan_and_prayer/features/adhan/domain/entities/reciter.dart';

abstract class AudioRepository {
  Future<List<Reciter>> getReciters();
  Future<Reciter> getSelectedReciter();
  Future<Result<void>> saveSelectedReciter(Reciter reciter);
  Future<double> getAdhanVolume();
  Future<Result<void>> saveAdhanVolume(double volume);
}

class AudioRepositoryImpl implements AudioRepository {
  final LocalStorage _storage;
  static const String _keySelectedReciterId = 'selected_reciter_id';
  static const String keyAdhanVolume = 'adhan_volume';
  static const double defaultAdhanVolume = 1.0;

  static const List<Reciter> defaultReciters = [
    Reciter(
      id: 'abdulbasit',
      nameAr: 'الشيخ عبد الباسط عبد الصمد',
      nameEn: 'Sheikh Abdul Basit Abdul Samad',
      assetPath: 'assets/audio/adhan_abdulbasit.mp3',
      isDefault: true,
    ),
    Reciter(
      id: 'makkah',
      nameAr: 'أذان الحرم المكي (علي ملا)',
      nameEn: 'Makkah Haram (Sheikh Ali Mulla)',
      assetPath: 'assets/audio/adhan_makkah.mp3',
      isDefault: false,
    ),
    Reciter(
      id: 'madinah',
      nameAr: 'أذان المسجد النبوي الشريف',
      nameEn: 'Madinah Prophet Mosque',
      assetPath: 'assets/audio/adhan_madinah.mp3',
      isDefault: false,
    ),
    Reciter(
      id: 'aqsa',
      nameAr: 'أذان المسجد الأقصى المبارك',
      nameEn: 'Al-Aqsa Mosque',
      assetPath: 'assets/audio/adhan_aqsa.mp3',
      isDefault: false,
    ),
  ];

  AudioRepositoryImpl(this._storage);

  @override
  Future<List<Reciter>> getReciters() async {
    return defaultReciters;
  }

  @override
  Future<Reciter> getSelectedReciter() async {
    final id = _storage.getString(_keySelectedReciterId);
    if (id != null) {
      try {
        return defaultReciters.firstWhere((r) => r.id == id);
      } catch (_) {}
    }
    return defaultReciters.firstWhere((r) => r.isDefault);
  }

  @override
  Future<Result<void>> saveSelectedReciter(Reciter reciter) async {
    try {
      await _storage.setString(_keySelectedReciterId, reciter.id);
      AppLogger.info('Saved selected reciter: ${reciter.nameEn}', 'AUDIO_REPO');
      return const Success(null);
    } catch (e, stack) {
      AppLogger.error('Failed to save reciter', e, stack, 'AUDIO_REPO');
      return Failure('Failed to save reciter: $e');
    }
  }

  @override
  Future<double> getAdhanVolume() async {
    final raw = _storage.getDouble(keyAdhanVolume);
    if (raw == null || raw.isNaN || raw.isInfinite) {
      return defaultAdhanVolume;
    }
    return raw.clamp(0.0, 1.0);
  }

  @override
  Future<Result<void>> saveAdhanVolume(double volume) async {
    try {
      final clamped = (volume.isNaN || volume.isInfinite) ? defaultAdhanVolume : volume.clamp(0.0, 1.0);
      await _storage.setDouble(keyAdhanVolume, clamped);
      AppLogger.info('Saved Adhan volume: ${(clamped * 100).toInt()}%', 'AUDIO_REPO');
      return const Success(null);
    } catch (e, stack) {
      AppLogger.error('Failed to save Adhan volume', e, stack, 'AUDIO_REPO');
      return Failure('Failed to save Adhan volume: $e');
    }
  }
}
