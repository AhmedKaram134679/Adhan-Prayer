import '../datasources/qibla_local_calculator.dart';
import '../datasources/qibla_remote_datasource.dart';
import '../../domain/entities/qibla_direction.dart';
import '../../domain/repositories/qibla_repository.dart';

class QiblaRepositoryImpl implements QiblaRepository {
  final QiblaRemoteDataSource _remoteDataSource;

  QiblaRepositoryImpl({QiblaRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? QiblaRemoteDataSource();

  @override
  Future<QiblaDirection> getQiblaDirection(double latitude, double longitude) async {
    double bearing;
    bool isFallback = false;

    try {
      bearing = await _remoteDataSource.getQiblaBearing(latitude, longitude);
      bearing = QiblaLocalCalculator.normalizeAngle(bearing);
    } catch (_) {
      // Graceful fallback to spherical mathematical calculation when offline, timed out, or API error
      bearing = QiblaLocalCalculator.calculateBearing(latitude, longitude);
      isFallback = true;
    }

    return QiblaDirection(
      qiblaBearing: bearing,
      latitude: latitude,
      longitude: longitude,
      isOfflineFallback: isFallback,
      hasCompassSensor: false, // Updated dynamically by presentation cubit
    );
  }
}
