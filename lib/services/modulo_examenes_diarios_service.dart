import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/modulo_examen_diario.dart';
import 'auth_service.dart';

class ModuloExamenesDiariosService {
  static String get _base => '${AuthService.baseUrl}/modulo-examenes-diarios';

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sesion invalida. Vuelve a iniciar sesion.');
    }

    return <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<ModuloExamenDiarioPage> index({
    int page = 1,
    int perPage = 50,
    String? buscar,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      if ((buscar ?? '').trim().isNotEmpty) 'buscar': buscar!.trim(),
    };

    final uri = Uri.parse(_base).replace(queryParameters: query);
    final resp = await http
        .get(uri, headers: await _headers(json: false))
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_backendError(resp));
    }

    final raw = jsonDecode(resp.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('Respuesta invalida del servidor.');
    }

    final list = raw['data'];
    final items = list is List
        ? list
              .whereType<Map>()
              .map(
                (item) => ModuloExamenDiario.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <ModuloExamenDiario>[];

    final pagination = raw['pagination'] is Map
        ? Map<String, dynamic>.from(raw['pagination'] as Map)
        : <String, dynamic>{};

    return ModuloExamenDiarioPage(
      items: items,
      currentPage: _readInt(pagination['current_page']) ?? page,
      lastPage: _readInt(pagination['last_page']) ?? page,
      total: _readInt(pagination['total']) ?? items.length,
    );
  }

  static Future<ModuloExamenDiario> save({
    int? id,
    required Map<String, dynamic> data,
  }) async {
    final uri = Uri.parse(id == null ? _base : '$_base/$id');
    final headers = await _headers();
    final body = jsonEncode(data);
    final resp = id == null
        ? await http
              .post(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 15))
        : await http
              .put(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 15));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_backendError(resp));
    }

    final raw = jsonDecode(resp.body);
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is Map) {
        return ModuloExamenDiario.fromJson(Map<String, dynamic>.from(data));
      }
    }

    throw Exception('Respuesta invalida del servidor.');
  }

  static Future<void> delete(int id) async {
    final resp = await http
        .delete(Uri.parse('$_base/$id'), headers: await _headers(json: false))
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_backendError(resp));
    }
  }

  static String cleanExceptionMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Ocurrio un error inesperado.';
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  static String _backendError(http.Response resp) {
    try {
      final raw = jsonDecode(resp.body);
      if (raw is Map<String, dynamic>) {
        final errors = raw['errors'];
        if (errors is Map) {
          final messages = <String>[];
          errors.forEach((_, value) {
            if (value is List && value.isNotEmpty) {
              messages.add(value.first.toString());
            }
          });
          if (messages.isNotEmpty) return messages.join('\n');
        }

        final message = (raw['message'] ?? '').toString().trim();
        if (message.isNotEmpty) return message;
      }
    } catch (_) {}

    return 'Error HTTP ${resp.statusCode}';
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString());
  }
}
