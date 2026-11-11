import '../../domain/entities/qibla_direction.dart';

abstract class QiblaState {
  const QiblaState();
}

class QiblaInitial extends QiblaState {
  const QiblaInitial();
}

class QiblaLoadingLocation extends QiblaState {
  const QiblaLoadingLocation();
}

class QiblaPermissionRequired extends QiblaState {
  const QiblaPermissionRequired();
}

class QiblaPermissionDenied extends QiblaState {
  final bool isPermanent;
  const QiblaPermissionDenied({this.isPermanent = false});
}

class QiblaLocationServiceDisabled extends QiblaState {
  const QiblaLocationServiceDisabled();
}

class QiblaCalculating extends QiblaState {
  final double latitude;
  final double longitude;
  const QiblaCalculating({required this.latitude, required this.longitude});
}

class QiblaLoaded extends QiblaState {
  final QiblaDirection direction;
  final bool isCompassAvailable;
  final bool isCalibrating;

  const QiblaLoaded({
    required this.direction,
    required this.isCompassAvailable,
    this.isCalibrating = false,
  });

  QiblaLoaded copyWith({
    QiblaDirection? direction,
    bool? isCompassAvailable,
    bool? isCalibrating,
  }) {
    return QiblaLoaded(
      direction: direction ?? this.direction,
      isCompassAvailable: isCompassAvailable ?? this.isCompassAvailable,
      isCalibrating: isCalibrating ?? this.isCalibrating,
    );
  }
}

class QiblaError extends QiblaState {
  final String messageKey;
  const QiblaError(this.messageKey);
}
