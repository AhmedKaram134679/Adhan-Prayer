import 'dart:math' as math;

/// Mathematically calculates the great-circle initial bearing from any point on Earth to the Kaaba.
///
/// Kaaba Coordinates:
/// Latitude: 21.422487° N
/// Longitude: 39.826206° E
///
/// Formula:
/// λK = Kaaba Longitude in radians, φK = Kaaba Latitude in radians
/// λ = Location Longitude in radians, φ = Location Latitude in radians
/// Δλ = λK - λ
/// θ = atan2(sin(Δλ), cos(φ)*tan(φK) - sin(φ)*cos(Δλ))
/// bearing = (toDegrees(θ) + 360) % 360
class QiblaLocalCalculator {
  static const double kaabaLatitude = 21.422487;
  static const double kaabaLongitude = 39.826206;

  static const double _degToRad = math.pi / 180.0;
  static const double _radToDeg = 180.0 / math.pi;

  /// Calculates the initial great-circle bearing to Kaaba from [latitude] and [longitude].
  ///
  /// Returns bearing in degrees normalized to [0.0, 360.0).
  /// 0° = North, 90° = East, 180° = South, 270° = West.
  static double calculateBearing(double latitude, double longitude) {
    final phi1 = latitude * _degToRad;
    final lambda1 = longitude * _degToRad;
    final phi2 = kaabaLatitude * _degToRad;
    final lambda2 = kaabaLongitude * _degToRad;

    final deltaLambda = lambda2 - lambda1;

    final y = math.sin(deltaLambda);
    final x = math.cos(phi1) * math.tan(phi2) - math.sin(phi1) * math.cos(deltaLambda);

    final bearingRad = math.atan2(y, x);
    final bearingDeg = bearingRad * _radToDeg;

    return normalizeAngle(bearingDeg);
  }

  /// Normalizes an angle in degrees into [0.0, 360.0).
  static double normalizeAngle(double angle) {
    var normalized = angle % 360.0;
    if (normalized < 0) {
      normalized += 360.0;
    }
    return normalized;
  }

  /// Calculates the relative angle of the Kaaba with respect to device heading.
  /// Result is normalized to [0.0, 360.0).
  /// When relative angle is near 0° (or 360°), device is pointing directly towards the Kaaba.
  static double calculateRelativeAngle(double qiblaBearing, double deviceHeading) {
    return normalizeAngle(qiblaBearing - deviceHeading);
  }
}
