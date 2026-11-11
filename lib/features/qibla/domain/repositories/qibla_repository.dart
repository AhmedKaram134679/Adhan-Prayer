import '../entities/qibla_direction.dart';

abstract class QiblaRepository {
  /// Fetches Qibla direction for coordinates [latitude] and [longitude].
  /// Tries online API first; if unavailable, falls back cleanly to mathematical calculation.
  Future<QiblaDirection> getQiblaDirection(double latitude, double longitude);
}
