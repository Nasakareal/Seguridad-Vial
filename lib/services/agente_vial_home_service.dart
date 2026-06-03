import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/agente_vial_home_models.dart';
import 'auth_service.dart';

class AgenteVialHomeService {
  static const int defaultWazeHours = 6;
  static const int defaultHistoryDays = 90;
  static const int defaultLimit = 80;
  static const double defaultGridSize = 0.006;

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String _parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map<String, dynamic>) {
        final message = raw['message']?.toString().trim() ?? '';
        if (message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }

  static Future<AgenteVialHomeMapData> fetchMapa({
    required int hour,
    int wazeHours = defaultWazeHours,
    int historyDays = defaultHistoryDays,
    int limit = defaultLimit,
    double gridSize = defaultGridSize,
    String tipo = 'TODOS',
  }) async {
    final uri = Uri.parse('${AuthService.baseUrl}/agente-vial-home/mapa')
        .replace(
          queryParameters: <String, String>{
            'hour': hour.toString(),
            'waze_hours': wazeHours.toString(),
            'history_days': historyDays.toString(),
            'limit': limit.toString(),
            'grid_size': gridSize.toString(),
            'tipo': tipo.trim().toUpperCase(),
          },
        );

    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception(_parseBackendError(res.body, res.statusCode));
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida al cargar home de Agente Vial.');
    }

    return AgenteVialHomeMapData.fromJson(decoded);
  }
}
