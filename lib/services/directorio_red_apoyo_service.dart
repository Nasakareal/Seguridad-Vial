import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/red_apoyo.dart';
import 'auth_service.dart';

class DirectorioRedApoyoService {
  static String get _base => '${AuthService.baseUrl}/directorio-red-apoyo';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sesion invalida. Vuelve a iniciar sesion.');
    }

    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<DirectorioRedApoyoMeta> meta() async {
    final response = await http
        .get(Uri.parse('$_base/meta'), headers: await _headers())
        .timeout(const Duration(seconds: 15));

    return DirectorioRedApoyoMeta.fromJson(_decodeMap(response));
  }

  static Future<DirectorioRedApoyoPage> index({
    String? q,
    int? regionId,
    int? delegacionId,
    String? nivelGobierno,
    String? tipoApoyo,
    int limit = 250,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      if ((q ?? '').trim().isNotEmpty) 'q': q!.trim(),
      if (regionId != null && regionId > 0) 'region_id': '$regionId',
      if (delegacionId != null && delegacionId > 0)
        'delegacion_id': '$delegacionId',
      if ((nivelGobierno ?? '').trim().isNotEmpty)
        'nivel_gobierno': nivelGobierno!.trim(),
      if ((tipoApoyo ?? '').trim().isNotEmpty) 'tipo_apoyo': tipoApoyo!.trim(),
    };

    final response = await http
        .get(
          Uri.parse(_base).replace(queryParameters: query),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));

    return DirectorioRedApoyoPage.fromJson(_decodeMap(response));
  }

  static Future<RedApoyoContact> show(int id) async {
    final response = await http
        .get(Uri.parse('$_base/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 15));

    final raw = _decodeMap(response);
    final data = raw['data'];
    if (data is Map<String, dynamic>) return RedApoyoContact.fromJson(data);
    if (data is Map) {
      return RedApoyoContact.fromJson(Map<String, dynamic>.from(data));
    }

    return RedApoyoContact.fromJson(raw);
  }

  static String cleanExceptionMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Ocurrio un error inesperado.';
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  static Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseBackendError(response));
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception('Respuesta invalida del servidor.');
  }

  static String _parseBackendError(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString().trim() ?? '';
        if (message.isNotEmpty) return message;

        final errors = decoded['errors'];
        if (errors is Map) {
          final messages = <String>[];
          errors.forEach((_, value) {
            if (value is List && value.isNotEmpty) {
              messages.add(value.first.toString());
            }
          });
          if (messages.isNotEmpty) return messages.join('\n');
        }
      }
    } catch (_) {}

    if (response.statusCode == 401) {
      return 'Sesion expirada. Vuelve a iniciar sesion.';
    }
    if (response.statusCode == 403) {
      return 'No tienes permiso para ver la red de apoyo.';
    }

    return 'Error HTTP ${response.statusCode}';
  }
}
