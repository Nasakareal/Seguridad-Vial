import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/riesgo_cell.dart';
import 'auth_service.dart';

class RiesgoService {
  static String get baseUrl =>
      AuthService.baseUrl; // https://seguridadvial-mich.com/api

  static Future<List<RiesgoCell>> fetchRiesgoCells({
    required int precision,
    required int
    ventanaMin, // se manda como "ventana" (aunque tu backend ahorita no lo usa)
    required int wazeHoras,
    required int top,
    required double minScore,
  }) async {
    final token = await AuthService.getToken();

    if (token == null || token.trim().isEmpty) {
      throw Exception('No token (sesión no iniciada).');
    }

    // 👇 OJO: aquí cambiamos el endpoint
    final uri = Uri.parse('$baseUrl/home/perito').replace(
      queryParameters: {
        'precision': precision.toString(),
        'desde': DateTime.now()
            .subtract(const Duration(days: 30))
            .toIso8601String()
            .substring(0, 10),
        'hasta': DateTime.now().toIso8601String().substring(0, 10),
        'waze_horas': wazeHoras.toString(),
        'ventana': ventanaMin.toString(),
      },
    );

    final res = await http
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 12));

    if (res.statusCode == 401) {
      throw Exception(
        '401 No autorizado: token inválido/expirado. Body: ${res.body}',
      );
    }
    if (res.statusCode == 403) {
      throw Exception(
        '403 Prohibido: permiso/rol/middleware. Body: ${res.body}',
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final decoded = json.decode(res.body);
    final Map<String, dynamic> map = (decoded as Map).cast<String, dynamic>();

    // Tu controller regresa esto:
    // return response()->json([
    //   'kpis' => ...,
    //   'hechos_cells' => ...,
    //   'waze_points' => ...,
    //   'matches' => ...,
    //   'riesgo_cells' => ...
    // ]);
    final List<dynamic> raw =
        (map['riesgo_cells'] as List<dynamic>? ?? const []);

    final cells = raw
        .map((e) => RiesgoCell.fromJson((e as Map).cast<String, dynamic>()))
        .where((c) => c.score >= minScore)
        .toList();

    cells.sort((a, b) => b.score.compareTo(a.score));
    return cells.take(top).toList();
  }
}
