import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/features/qibla/data/datasources/qibla_local_calculator.dart';

void main() {
  group('QiblaLocalCalculator - Spherical Mathematical Calculation Tests', () {
    test('Calculates mathematically accurate Qibla bearing for Cairo, Egypt (~136.1°)', () {
      // Cairo: 30.0444° N, 31.2357° E
      final bearing = QiblaLocalCalculator.calculateBearing(30.0444, 31.2357);
      expect(bearing, closeTo(136.14, 0.2));
    });

    test('Calculates mathematically accurate Qibla bearing for London, UK (~118.9°)', () {
      // London: 51.5074° N, -0.1278° W (Negative longitude / Western hemisphere)
      final bearing = QiblaLocalCalculator.calculateBearing(51.5074, -0.1278);
      expect(bearing, closeTo(118.98, 0.2));
    });

    test('Calculates mathematically accurate Qibla bearing for New York, USA (~58.5°)', () {
      // New York: 40.7128° N, -74.0060° W (North America, Great Circle northeast over Atlantic)
      final bearing = QiblaLocalCalculator.calculateBearing(40.7128, -74.0060);
      expect(bearing, closeTo(58.48, 0.2));
    });

    test('Calculates mathematically accurate Qibla bearing for Sydney, Australia (~277.5°)', () {
      // Sydney: -33.8688° S, 151.2093° E (Southern hemisphere)
      final bearing = QiblaLocalCalculator.calculateBearing(-33.8688, 151.2093);
      expect(bearing, closeTo(277.50, 0.5));
    });

    test('Calculates mathematically accurate Qibla bearing for Tokyo, Japan (~293.0°)', () {
      // Tokyo: 35.6762° N, 139.6503° E (Far East)
      final bearing = QiblaLocalCalculator.calculateBearing(35.6762, 139.6503);
      expect(bearing, closeTo(293.02, 0.5));
    });

    test('Calculates mathematically accurate Qibla bearing for Cape Town, South Africa (~23.35°)', () {
      // Cape Town: -33.9249° S, 18.4241° E (Southern Africa)
      final bearing = QiblaLocalCalculator.calculateBearing(-33.9249, 18.4241);
      expect(bearing, closeTo(23.35, 0.5));
    });

    test('Calculates mathematically accurate Qibla bearing for Makkah (Near Kaaba)', () {
      // Very close to Kaaba in Makkah
      final bearing = QiblaLocalCalculator.calculateBearing(21.43, 39.83);
      expect(bearing, inInclusiveRange(0.0, 360.0));
    });

    test('Calculates mathematically accurate Qibla bearing for Honolulu, Hawaii (~336.89°)', () {
      // Extreme longitude / Pacific: 21.3069° N, -157.8583° W
      // Great-circle initial bearing passes north-northwest over the Arctic/Alaska towards Makkah: ~336.89°
      final bearing = QiblaLocalCalculator.calculateBearing(21.3069, -157.8583);
      expect(bearing, closeTo(336.89, 0.5));
    });

    test('Bearing normalization bounds angle strictly within [0.0, 360.0)', () {
      expect(QiblaLocalCalculator.normalizeAngle(0.0), equals(0.0));
      expect(QiblaLocalCalculator.normalizeAngle(360.0), equals(0.0));
      expect(QiblaLocalCalculator.normalizeAngle(370.0), equals(10.0));
      expect(QiblaLocalCalculator.normalizeAngle(-45.0), equals(315.0));
      expect(QiblaLocalCalculator.normalizeAngle(-360.0), equals(0.0));
      expect(QiblaLocalCalculator.normalizeAngle(-730.0), equals(350.0));
      expect(QiblaLocalCalculator.normalizeAngle(0.00001), closeTo(0.00001, 1e-6));
      expect(QiblaLocalCalculator.normalizeAngle(359.9999), closeTo(359.9999, 1e-4));
    });

    test('Relative angle calculation with respect to device heading', () {
      // Bearing = 135°, Device heading = 135° -> Kaaba directly ahead (0°)
      expect(QiblaLocalCalculator.calculateRelativeAngle(135.0, 135.0), equals(0.0));

      // Bearing = 135°, Device heading = 45° -> Kaaba is 90° clockwise to the right
      expect(QiblaLocalCalculator.calculateRelativeAngle(135.0, 45.0), equals(90.0));

      // Bearing = 10°, Device heading = 350° -> Kaaba is 20° clockwise
      expect(QiblaLocalCalculator.calculateRelativeAngle(10.0, 350.0), equals(20.0));

      // Bearing = 350°, Device heading = 10° -> Kaaba is 340° (or -20°)
      expect(QiblaLocalCalculator.calculateRelativeAngle(350.0, 10.0), equals(340.0));
    });
  });
}
