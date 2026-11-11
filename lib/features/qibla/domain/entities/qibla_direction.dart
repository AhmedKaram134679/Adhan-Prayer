class QiblaDirection {
  /// Geographic bearing toward the Kaaba (0° to 360° from True North).
  final double qiblaBearing;

  /// Physical heading of the device (0° to 360° from Magnetic/True North), or null if sensor unavailable.
  final double? deviceHeading;

  /// Relative direction to Kaaba relative to the top of device (-180° to 180° or 0° to 360°).
  /// (qiblaBearing - deviceHeading) normalized to [0, 360).
  final double? relativeAngle;

  /// Device latitude used for this calculation.
  final double latitude;

  /// Device longitude used for this calculation.
  final double longitude;

  /// True if calculated via local mathematical formula (due to offline / API failure).
  final bool isOfflineFallback;

  /// True if device compass sensor is available and active.
  final bool hasCompassSensor;

  /// Compass sensor accuracy (if provided by sensor API: 0 = uncalibrated/unreliable, 1 = low, 2 = medium, 3 = high).
  final double? sensorAccuracy;

  const QiblaDirection({
    required this.qiblaBearing,
    this.deviceHeading,
    this.relativeAngle,
    required this.latitude,
    required this.longitude,
    required this.isOfflineFallback,
    required this.hasCompassSensor,
    this.sensorAccuracy,
  });

  QiblaDirection copyWith({
    double? qiblaBearing,
    double? deviceHeading,
    double? relativeAngle,
    double? latitude,
    double? longitude,
    bool? isOfflineFallback,
    bool? hasCompassSensor,
    double? sensorAccuracy,
  }) {
    return QiblaDirection(
      qiblaBearing: qiblaBearing ?? this.qiblaBearing,
      deviceHeading: deviceHeading ?? this.deviceHeading,
      relativeAngle: relativeAngle ?? this.relativeAngle,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isOfflineFallback: isOfflineFallback ?? this.isOfflineFallback,
      hasCompassSensor: hasCompassSensor ?? this.hasCompassSensor,
      sensorAccuracy: sensorAccuracy ?? this.sensorAccuracy,
    );
  }
}
