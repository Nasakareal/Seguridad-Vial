import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/perito_home_models.dart';
import 'auth_service.dart';

class PeritoHomeService {
  static const int defaultDays = 30;
  static const double defaultGridSize = 0.01;
  static const int defaultMinScore = 3;
  static const int defaultWazeHours = 12;

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
          final lower = message.toLowerCase();
          if (lower.contains("unknown column 'folio'") ||
              lower.contains('unknown column `folio`')) {
            return 'El endpoint perito-home/mapa está consultando la columna '
                '`folio`, pero en la tabla `hechos` la columna correcta es '
                '`folio_c5i`. Hay que corregir el controller del backend.';
          }
          return message;
        }
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }

  static Future<PeritoHomeMapData> fetchMapa({
    int days = defaultDays,
    double gridSize = defaultGridSize,
    int minScore = defaultMinScore,
    int wazeHours = defaultWazeHours,
  }) async {
    final uri = Uri.parse('${AuthService.baseUrl}/perito-home/mapa').replace(
      queryParameters: <String, String>{
        'days': days.toString(),
        'grid_size': gridSize.toString(),
        'min_score': minScore.toString(),
        'waze_hours': wazeHours.toString(),
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
      throw Exception('Respuesta inválida al cargar mapa de perito.');
    }

    return PeritoHomeMapData.fromJson(decoded);
  }

  static Future<PeritoHechoDetail> fetchHecho(int hechoId) async {
    final res = await http
        .get(
          Uri.parse('${AuthService.baseUrl}/perito-home/hechos/$hechoId'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw Exception(_parseBackendError(res.body, res.statusCode));
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida al cargar detalle del hecho.');
    }

    return PeritoHechoDetail.fromJson(decoded);
  }
}
