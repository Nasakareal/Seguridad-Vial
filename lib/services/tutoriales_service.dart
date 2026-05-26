import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/tutorial.dart';
import 'auth_service.dart';

class TutorialesService {
  static Future<List<TutorialCategory>> fetchCategorias() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No autenticado (token vacio).');
    }

    final response = await http
        .get(
          Uri.parse('${AuthService.baseUrl}/tutoriales'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 401) {
      throw Exception('No autorizado (401).');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error HTTP ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final raw = decoded is Map ? decoded['data'] : decoded;
    if (raw is! List) {
      return const <TutorialCategory>[];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => TutorialCategory.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((category) => category.tutoriales.isNotEmpty)
        .toList();
  }
}
