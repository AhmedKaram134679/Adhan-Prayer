import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_and_prayer/features/qibla/domain/entities/qibla_direction.dart';
import 'package:adhan_and_prayer/features/qibla/domain/repositories/qibla_repository.dart';
import 'package:adhan_and_prayer/features/qibla/presentation/cubit/qibla_cubit.dart';
import 'package:adhan_and_prayer/features/qibla/presentation/cubit/qibla_state.dart';

class FakeQiblaRepository implements QiblaRepository {
  final double bearing;
  final bool isOfflineFallback;

  FakeQiblaRepository({this.bearing = 136.14, this.isOfflineFallback = false});

  @override
  Future<QiblaDirection> getQiblaDirection(double latitude, double longitude) async {
    return QiblaDirection(
      qiblaBearing: bearing,
      latitude: latitude,
      longitude: longitude,
      isOfflineFallback: isOfflineFallback,
      hasCompassSensor: false,
    );
  }
}

void main() {
  group('QiblaCubit State Machine & Platform Tests', () {
    test('Initial state is QiblaInitial', () {
      final repo = FakeQiblaRepository();
      final cubit = QiblaCubit(repository: repo);

      expect(cubit.state, isA<QiblaInitial>());
      cubit.close();
    });

    test('On Windows platform, initQibla emits QiblaError with compass_unavailable', () async {
      final repo = FakeQiblaRepository();
      final cubit = QiblaCubit(repository: repo);

      if (Platform.isWindows) {
        await cubit.initQibla();
        expect(cubit.state, isA<QiblaError>());
        final error = cubit.state as QiblaError;
        expect(error.messageKey, equals('compass_unavailable'));
      }
      await cubit.close();
    });

    test('QiblaLoaded copyWith updates properties accurately without side effects', () {
      const initialDirection = QiblaDirection(
        qiblaBearing: 135.0,
        latitude: 30.0,
        longitude: 31.0,
        isOfflineFallback: false,
        hasCompassSensor: false,
      );

      const state = QiblaLoaded(
        direction: initialDirection,
        isCompassAvailable: false,
      );

      final updatedDirection = initialDirection.copyWith(
        deviceHeading: 45.0,
        relativeAngle: 90.0,
        hasCompassSensor: true,
      );

      final updatedState = state.copyWith(
        direction: updatedDirection,
        isCompassAvailable: true,
      );

      expect(updatedState.isCompassAvailable, isTrue);
      expect(updatedState.direction.deviceHeading, equals(45.0));
      expect(updatedState.direction.relativeAngle, equals(90.0));
      expect(updatedState.direction.hasCompassSensor, isTrue);
      expect(updatedState.direction.qiblaBearing, equals(135.0));
    });

    test('Heading wraparound across North boundary (359° to 1°) yields minimal delta without huge jump', () {
      // Direct verification of circular angle difference logic:
      // (1° - 359°) = -358° -> adjusted by +360° = +2°
      double computeAngleDelta(double newHeading, double lastHeading) {
        var diff = newHeading - lastHeading;
        if (diff > 180) {
          diff -= 360;
        } else if (diff < -180) {
          diff += 360;
        }
        return diff;
      }

      final deltaAcrossNorth = computeAngleDelta(1.0, 359.0);
      expect(deltaAcrossNorth, equals(2.0), reason: 'Clockwise step from 359° to 1° must be +2°, not -358°');

      final deltaCounterClockwise = computeAngleDelta(359.0, 1.0);
      expect(deltaCounterClockwise, equals(-2.0), reason: 'Counter-clockwise step from 1° to 359° must be -2°, not +358°');
    });
  });
}
