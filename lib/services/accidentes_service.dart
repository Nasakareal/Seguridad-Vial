import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AccidentesService {
  static Future<List<Map<String, dynamic>>> fetchHechos({
    required String fecha,
    int perPage = 100,
  }) async {
    final token = await AuthService.getToken();

    final uri = Uri.parse(
      '${AuthService.baseUrl}/hechos',
    ).replace(queryParameters: {'per_page': '$perPage', 'fecha': fecha});

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception(_parseBackendError(response.body, response.statusCode));
    }

    final raw = jsonDecode(response.body);
    List<dynamic> datos;

    if (raw is List) {
      datos = raw;
    } else if (raw is Map<String, dynamic> && raw['data'] is List) {
      datos = raw['data'] as List<dynamic>;
    } else if (raw is Map<String, dynamic> && raw['hechos'] is List) {
      datos = raw['hechos'] as List<dynamic>;
    } else {
      datos = [];
    }

    return datos
        .where((e) => e is Map)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<Uint8List> downloadReporteDoc({required int hechoId}) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    final uri = Uri.parse('${AuthService.baseUrl}/hechos/$hechoId/reporte-doc');

    final headers = <String, String>{
      'Accept': 'application/octet-stream',
      'Authorization': 'Bearer $token',
    };

    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode != 200) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    return resp.bodyBytes;
  }

  static Future<String> enviarWhatsapp({required int hechoId}) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    final uri = Uri.parse('${AuthService.baseUrl}/hechos/$hechoId/whatsapp');

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final resp = await http.post(uri, headers: headers);

    if (resp.statusCode != 200) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    String message = 'Hecho compartido por WhatsApp.';
    try {
      final raw = jsonDecode(resp.body);
      if (raw is Map && raw['message'] is String) {
        final m = (raw['message'] as String).trim();
        if (m.isNotEmpty) message = m;
      }
    } catch (_) {}

    return message;
  }

  static String _parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);

      if (raw is Map<String, dynamic>) {
        if (raw['message'] is String) {
          final msg = (raw['message'] as String).trim();
          if (msg.isNotEmpty) return msg;
        }

        final errors = raw['errors'];
        if (errors is Map) {
          final sb = StringBuffer();
          errors.forEach((_, v) {
            if (v is List && v.isNotEmpty) {
              sb.writeln('• ${v.first}');
            }
          });
          final out = sb.toString().trim();
          if (out.isNotEmpty) return out;
        }
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }
}
