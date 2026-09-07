import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/calea.dart';
import 'auth_service.dart';

class CaleaService {
  static String get _base => '${AuthService.baseUrl}/calea';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }
    return {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
  }

  static Future<CaleaMeta> meta() async {
    final response = await http
        .get(Uri.parse('$_base/meta'), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    return CaleaMeta.fromJson(_decode(response));
  }

  static Future<List<CaleaDirectiva>> index({String? categoria}) async {
    final response = await http
        .get(_uri('', categoria: categoria), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    return _directivas(_decode(response)['data']);
  }

  static Future<List<CaleaDirectiva>> buscar({
    required String texto,
    String? categoria,
  }) async {
    final response = await http
        .get(
          _uri('/buscar', texto: texto, categoria: categoria),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 25));
    return _directivas(_decode(response)['data']);
  }

  static Future<List<CaleaEstudioGrupo>> estudio({String? categoria}) async {
    final response = await http
        .get(_uri('/estudio', categoria: categoria), headers: await _headers())
        .timeout(const Duration(seconds: 30));
    return _maps(
      _decode(response)['data'],
    ).map(CaleaEstudioGrupo.fromJson).toList(growable: false);
  }

  static Future<CaleaDirectiva> show(int id) async {
    final response = await http
        .get(Uri.parse('$_base/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 25));
    final data = _map(_decode(response)['data']);
    if (data == null) throw Exception('La directiva no contiene datos.');
    return CaleaDirectiva.fromJson(data);
  }

  static Uri _uri(String path, {String? texto, String? categoria}) {
    final query = <String, String>{
      if ((texto ?? '').trim().isNotEmpty) 'q': texto!.trim(),
      if ((categoria ?? '').trim().isNotEmpty) 'categoria': categoria!.trim(),
    };
    return Uri.parse(
      '$_base$path',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }

  static List<CaleaDirectiva> _directivas(dynamic value) =>
      _maps(value).map(CaleaDirectiva.fromJson).toList(growable: false);

  static List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value
            .map(_map)
            .whereType<Map<String, dynamic>>()
            .toList(growable: false)
      : const [];

  static Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_backendError(response));
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final map = _map(decoded);
    if (map == null) throw Exception('Respuesta inválida del servidor.');
    return map;
  }

  static String _backendError(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final map = _map(decoded);
      final message = map?['message']?.toString().trim() ?? '';
      if (message.isNotEmpty) return message;
    } catch (_) {}
    if (response.statusCode == 401) {
      return 'Tu sesión expiró. Vuelve a iniciar sesión.';
    }
    if (response.statusCode == 403) {
      return 'No tienes permiso para consultar CALEA.';
    }
    if (response.statusCode == 404) return 'No se encontró la directiva.';
    return 'Error HTTP ${response.statusCode}';
  }

  static String cleanError(Object error) =>
      error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
