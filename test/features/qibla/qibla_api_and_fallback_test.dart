import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:adhan_and_prayer/features/qibla/data/datasources/qibla_remote_datasource.dart';
import 'package:adhan_and_prayer/features/qibla/data/repositories/qibla_repository_impl.dart';

void main() {
  group('Qibla API & Offline Fallback Tests', () {
    test('Successful API response returns online bearing', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/qibla/30.0444/31.2357')) {
          return http.Response(
            jsonEncode({
              'code': 200,
              'status': 'OK',
              'data': {
                'latitude': 30.0444,
                'longitude': 31.2357,
                'direction': 136.137,
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final remoteSource = QiblaRemoteDataSource(client: mockClient);
      final repo = QiblaRepositoryImpl(remoteDataSource: remoteSource);

      final result = await repo.getQiblaDirection(30.0444, 31.2357);

      expect(result.isOfflineFallback, isFalse);
      expect(result.qiblaBearing, closeTo(136.137, 0.01));
      expect(result.latitude, equals(30.0444));
      expect(result.longitude, equals(31.2357));
    });

    test('HTTP error falls back seamlessly to mathematical calculation without throwing', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final remoteSource = QiblaRemoteDataSource(client: mockClient);
      final repo = QiblaRepositoryImpl(remoteDataSource: remoteSource);

      final result = await repo.getQiblaDirection(30.0444, 31.2357);

      expect(result.isOfflineFallback, isTrue);
      // Mathematical fallback for Cairo
      expect(result.qiblaBearing, closeTo(136.14, 0.2));
    });

    test('Malformed JSON falls back seamlessly to mathematical calculation', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"invalid": json', 200);
      });

      final remoteSource = QiblaRemoteDataSource(client: mockClient);
      final repo = QiblaRepositoryImpl(remoteDataSource: remoteSource);

      final result = await repo.getQiblaDirection(51.5074, -0.1278); // London

      expect(result.isOfflineFallback, isTrue);
      expect(result.qiblaBearing, closeTo(118.98, 0.2));
    });

    test('Network exception falls back seamlessly to mathematical calculation', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection failed');
      });

      final remoteSource = QiblaRemoteDataSource(client: mockClient);
      final repo = QiblaRepositoryImpl(remoteDataSource: remoteSource);

      final result = await repo.getQiblaDirection(40.7128, -74.0060); // New York

      expect(result.isOfflineFallback, isTrue);
      expect(result.qiblaBearing, closeTo(58.48, 0.2));
    });
  });
}
