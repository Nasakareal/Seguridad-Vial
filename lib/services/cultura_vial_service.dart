import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/cultura_vial.dart';
import 'auth_service.dart';

class CulturaVialService {
  static String get _base => '${AuthService.baseUrl}/cultura-vial';

  static Future<Map<String, String>> authHeaders({bool json = true}) async {
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

  static Map<String, String> publicHeaders() {
    return const <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  static String cleanExceptionMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Ocurrió un error inesperado.';
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  static String parseJoinCode(String raw) {
    var code = raw.trim().toUpperCase();
    if (code.contains('SV-CULTURA:')) {
      code = code.split('SV-CULTURA:').last;
    }
    final uri = Uri.tryParse(code);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last.trim();
      if (last.isNotEmpty) code = last.toUpperCase();
    }
    return code.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static String qrUrlFor(int salaId) => '$_base/salas/$salaId/qr';

  static Future<List<CulturaVialSala>> fetchSalas() async {
    final resp = await http.get(
      Uri.parse('$_base/salas'),
      headers: await authHeaders(json: false),
    );

    _throwIfError(resp);
    final raw = jsonDecode(resp.body);
    final list = raw is Map && raw['data'] is List
        ? raw['data'] as List
        : const [];

    return list
        .whereType<Map>()
        .map(
          (item) => CulturaVialSala.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  static Future<CulturaVialSala> createSala({required String nombre}) async {
    final resp = await http.post(
      Uri.parse('$_base/salas'),
      headers: await authHeaders(),
      body: jsonEncode(<String, String>{
        'nombre': nombre.trim().isEmpty ? 'Clase de Cultura Vial' : nombre,
        'juego_slug': 'ciudad_segura',
      }),
    );

    _throwIfError(resp);
    return _decodeSala(resp.body);
  }

  static Future<CulturaVialSala> fetchSala(int salaId) async {
    final resp = await http.get(
      Uri.parse('$_base/salas/$salaId'),
      headers: await authHeaders(json: false),
    );

    _throwIfError(resp);
    return _decodeSala(resp.body);
  }

  static Future<CulturaVialSala> closeSala(int salaId) async {
    final resp = await http.post(
      Uri.parse('$_base/salas/$salaId/cerrar'),
      headers: await authHeaders(),
    );

    _throwIfError(resp);
    return _decodeSala(resp.body);
  }

  static Future<CulturaVialSala> fetchPublicSala(String code) async {
    final clean = parseJoinCode(code);
    final resp = await http.get(
      Uri.parse('$_base/public/salas/$clean'),
      headers: const <String, String>{'Accept': 'application/json'},
    );

    _throwIfError(resp);
    return _decodeSala(resp.body);
  }

  static Future<CulturaVialJoinResult> joinSala({
    required String code,
    required String nombre,
  }) async {
    final clean = parseJoinCode(code);
    final resp = await http.post(
      Uri.parse('$_base/public/salas/$clean/participantes'),
      headers: publicHeaders(),
      body: jsonEncode(<String, String>{'nombre': nombre.trim()}),
    );

    _throwIfError(resp);
    return CulturaVialJoinResult.fromJson(
      Map<String, dynamic>.from(jsonDecode(resp.body) as Map),
    );
  }

  static Future<void> submitAttempt({
    required int participanteId,
    required String joinToken,
    required int puntaje,
    required int aciertos,
    required int errores,
    required int duracionSegundos,
    required List<Map<String, dynamic>> decisiones,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/public/participantes/$participanteId/intentos'),
      headers: publicHeaders(),
      body: jsonEncode(<String, dynamic>{
        'join_token': joinToken,
        'juego_slug': 'ciudad_segura',
        'puntaje': puntaje,
        'aciertos': aciertos,
        'errores': errores,
        'duracion_segundos': duracionSegundos,
        'decisiones': decisiones,
      }),
    );

    _throwIfError(resp);
  }

  static CulturaVialSala _decodeSala(String body) {
    final raw = jsonDecode(body);
    if (raw is Map<String, dynamic> && raw['data'] is Map) {
      return CulturaVialSala.fromJson(
        Map<String, dynamic>.from(raw['data'] as Map),
      );
    }
    if (raw is Map<String, dynamic>) {
      return CulturaVialSala.fromJson(raw);
    }
    throw Exception('Respuesta invalida del servidor.');
  }

  static void _throwIfError(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    throw Exception(_parseBackendError(resp.body, resp.statusCode));
  }

  static String _parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);
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

    return 'Error HTTP $statusCode';
  }
}
