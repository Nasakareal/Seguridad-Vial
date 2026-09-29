import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/licencia_emision.dart';
import 'auth_service.dart';

class LicenciasEmisionService {
  static String get _base => '${AuthService.baseUrl}/licencias-emision';

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

  static Future<LicenciasEmisionPage> index({
    String? buscar,
    int page = 1,
    int perPage = 25,
  }) async {
    final uri = Uri.parse(_base).replace(
      queryParameters: <String, String>{
        'page': '$page',
        'per_page': '$perPage',
        if ((buscar ?? '').trim().isNotEmpty) 'buscar': buscar!.trim(),
      },
    );
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final raw = _decode(response);
    final data = raw['data'];
    final pagination = raw['pagination'] is Map
        ? Map<String, dynamic>.from(raw['pagination'] as Map)
        : const <String, dynamic>{};
    final items = data is List
        ? data
              .whereType<Map>()
              .map(
                (item) =>
                    LicenciaEmision.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <LicenciaEmision>[];
    return LicenciasEmisionPage(
      items: items,
      currentPage: _int(pagination['current_page'], page),
      lastPage: _int(pagination['last_page'], page),
      total: _int(pagination['total'], items.length),
    );
  }

  static Future<LicenciaEmision> create({
    required int constanciaId,
    required File foto,
    required Map<String, String> fields,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(_base));
    request.headers.addAll(await _headers());
    request.fields.addAll(<String, String>{
      ...fields,
      'constancia_id': '$constanciaId',
    });
    request.files.add(await http.MultipartFile.fromPath('foto', foto.path));
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    final raw = _decode(response);
    final data = raw['data'];
    if (data is! Map) throw Exception('Respuesta inválida del servidor.');
    return LicenciaEmision.fromJson(Map<String, dynamic>.from(data));
  }

  static Map<String, dynamic> _decode(http.Response response) {
    dynamic raw;
    try {
      raw = jsonDecode(response.body);
    } catch (_) {
      raw = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (raw is Map) {
        final errors = raw['errors'];
        if (errors is Map) {
          final messages = errors.values
              .whereType<List>()
              .where((item) => item.isNotEmpty)
              .map((item) => item.first.toString())
              .toList();
          if (messages.isNotEmpty) throw Exception(messages.join('\n'));
        }
        final message = (raw['message'] ?? '').toString().trim();
        if (message.isNotEmpty) throw Exception(message);
      }
      throw Exception('Error HTTP ${response.statusCode}.');
    }
    if (raw is! Map) throw Exception('Respuesta inválida del servidor.');
    return Map<String, dynamic>.from(raw);
  }

  static int _int(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  static String cleanError(Object error) =>
      error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
}
