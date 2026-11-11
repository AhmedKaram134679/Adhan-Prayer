import 'dart:convert';
import 'package:http/http.dart' as http;

/// Remote data source calling AlAdhan Qibla API over HTTPS.
/// Endpoint: https://api.aladhan.com/v1/qibla/{latitude}/{longitude}
class QiblaRemoteDataSource {
  final http.Client _client;
  static const Duration defaultTimeout = Duration(seconds: 5);

  QiblaRemoteDataSource({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches Qibla bearing from the online API.
  /// Throws an [Exception] if network fails, times out, or response format is invalid.
  Future<double> getQiblaBearing(double latitude, double longitude) async {
    final uri = Uri.parse('https://api.aladhan.com/v1/qibla/$latitude/$longitude');

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(defaultTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data['code'] == 200) {
        final payload = data['data'];
        if (payload is Map<String, dynamic> && payload.containsKey('direction')) {
          final direction = payload['direction'];
          if (direction is num) {
            return direction.toDouble();
          }
        }
      }
      throw FormatException('Unexpected API response format: ${response.body}');
    } else {
      throw http.ClientException(
        'Qibla API returned status code ${response.statusCode}',
        uri,
      );
    }
  }
}
