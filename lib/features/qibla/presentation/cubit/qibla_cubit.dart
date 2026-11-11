import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../../data/datasources/qibla_local_calculator.dart';
import '../../domain/entities/qibla_direction.dart';
import '../../domain/repositories/qibla_repository.dart';
import 'qibla_state.dart';

class QiblaCubit extends Cubit<QiblaState> {
  final QiblaRepository repository;
  StreamSubscription<CompassEvent>? _compassSubscription;

  // Smoothing parameter for sensor heading
  double? _lastSmoothedHeading;
  static const double _smoothingAlpha = 0.25;

  QiblaCubit({required this.repository})
      : super(const QiblaInitial());

  /// Initializes Qibla direction acquisition: checks permissions and location services.
  Future<void> initQibla() async {
    if (Platform.isWindows) {
      emit(const QiblaError('compass_unavailable'));
      return;
    }

    emit(const QiblaLoadingLocation());

    try {
      // 1. Check if location services are enabled
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        emit(const QiblaLocationServiceDisabled());
        return;
      }

      // 2. Check permission status
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Prompt user for permission when opening Qibla
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          emit(const QiblaPermissionDenied(isPermanent: false));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        emit(const QiblaPermissionDenied(isPermanent: true));
        return;
      }

      // 3. Obtain current device location
      await _fetchLocationAndBearing();
    } catch (_) {
      emit(const QiblaError('error'));
    }
  }

  /// Refreshes current GPS location and recalculates bearing.
  Future<void> refreshLocation() async {
    await initQibla();
  }

  Future<void> _fetchLocationAndBearing() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      emit(QiblaCalculating(
        latitude: position.latitude,
        longitude: position.longitude,
      ));

      // Calculate Qibla bearing (API primary -> Math fallback)
      final direction = await repository.getQiblaDirection(
        position.latitude,
        position.longitude,
      );

      // Start compass subscription
      _startCompass(direction);
    } catch (_) {
      // If position lookup failed or timed out, try last known position as a fallback
      try {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          final direction = await repository.getQiblaDirection(
            lastPosition.latitude,
            lastPosition.longitude,
          );
          _startCompass(direction);
          return;
        }
      } catch (_) {}

      emit(const QiblaError('location_required_desc'));
    }
  }

  void _startCompass(QiblaDirection baseDirection) {
    _compassSubscription?.cancel();

    final compassStream = FlutterCompass.events;
    if (compassStream == null) {
      // Device does not have compass sensors
      emit(QiblaLoaded(
        direction: baseDirection.copyWith(hasCompassSensor: false),
        isCompassAvailable: false,
      ));
      return;
    }

    bool hasReceivedFirstEvent = false;

    _compassSubscription = compassStream.listen(
      (CompassEvent event) {
        hasReceivedFirstEvent = true;
        final rawHeading = event.heading;

        if (rawHeading == null) {
          // Sensor available but no heading data currently reported
          if (state is! QiblaLoaded) {
            emit(QiblaLoaded(
              direction: baseDirection.copyWith(hasCompassSensor: false),
              isCompassAvailable: false,
            ));
          }
          return;
        }

        // Normalize raw heading to [0, 360)
        final normalizedHeading = QiblaLocalCalculator.normalizeAngle(rawHeading);

        // Apply low-pass filter smoothing for heading jitter
        final smoothedHeading = _smoothHeading(normalizedHeading);

        // Calculate relative angle to Kaaba
        final relativeAngle = QiblaLocalCalculator.calculateRelativeAngle(
          baseDirection.qiblaBearing,
          smoothedHeading,
        );

        // Check calibration accuracy (accuracy < 15 is considered good/reliable on android sensors)
        final accuracy = event.accuracy;
        final isCalibrating = accuracy != null && accuracy > 35; // high variance suggests calibration needed

        final updatedDirection = baseDirection.copyWith(
          deviceHeading: smoothedHeading,
          relativeAngle: relativeAngle,
          hasCompassSensor: true,
          sensorAccuracy: accuracy,
        );

        emit(QiblaLoaded(
          direction: updatedDirection,
          isCompassAvailable: true,
          isCalibrating: isCalibrating,
        ));
      },
      onError: (_) {
        emit(QiblaLoaded(
          direction: baseDirection.copyWith(hasCompassSensor: false),
          isCompassAvailable: false,
        ));
      },
      cancelOnError: false,
    );

    // Timeout safety if no compass event is fired after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (!isClosed && !hasReceivedFirstEvent && state is! QiblaLoaded) {
        emit(QiblaLoaded(
          direction: baseDirection.copyWith(hasCompassSensor: false),
          isCompassAvailable: false,
        ));
      }
    });
  }

  /// Low-pass filter smoothing to eliminate sensor noise and UI jitter.
  double _smoothHeading(double newHeading) {
    if (_lastSmoothedHeading == null) {
      _lastSmoothedHeading = newHeading;
      return newHeading;
    }

    // Handle wrap-around across 0° / 360° boundary
    var diff = newHeading - _lastSmoothedHeading!;
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }

    final smoothed = _lastSmoothedHeading! + (_smoothingAlpha * diff);
    _lastSmoothedHeading = QiblaLocalCalculator.normalizeAngle(smoothed);
    return _lastSmoothedHeading!;
  }

  @override
  Future<void> close() {
    _compassSubscription?.cancel();
    _compassSubscription = null;
    return super.close();
  }
}
