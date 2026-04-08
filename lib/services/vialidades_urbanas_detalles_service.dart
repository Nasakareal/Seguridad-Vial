import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/vialidades_urbanas_dispositivo.dart';
import 'auth_service.dart';

class VialidadesUrbanasDetallesService {
  static const int _referenceId = 1;
  static String get _base => '${AuthService.baseUrl}/vialidades-urbanas';

  static Future<Map<String, String>> _headersJson() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesion invalida. Vuelve a iniciar sesion.');
    }

    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String _parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);

      if (raw is Map<String, dynamic>) {
        final errors = raw['errors'];
        if (errors is Map) {
          final buffer = StringBuffer();
          errors.forEach((_, value) {
            if (value is List && value.isNotEmpty) {
              buffer.writeln('• ${value.first}');
            }
          });
          final text = buffer.toString().trim();
          if (text.isNotEmpty) return text;
        }

        final message = (raw['message'] ?? '').toString().trim();
        if (message.isNotEmpty) return message;
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }

  static String _childBase(int dispositivoId) =>
      '$_base/$_referenceId/dispositivos/$dispositivoId';

  static Future<VialidadesUrbanasDispositivo> fetchDispositivo({
    required int dispositivoId,
    bool detailed = true,
  }) async {
    final headers = await _headersJson();
    final path = detailed
        ? '${_childBase(dispositivoId)}/show'
        : _childBase(dispositivoId);

    final resp = await http.get(Uri.parse(path), headers: headers);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('Respuesta invalida del servidor.');
    }

    final data = raw['data'] is Map
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : raw;

    return VialidadesUrbanasDispositivo.fromJson(data);
  }

  static Future<String> fetchWhatsappText({required int dispositivoId}) async {
    final headers = await _headersJson();
    final resp = await http.get(
      Uri.parse('${_childBase(dispositivoId)}/whatsapp'),
      headers: headers,
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('Respuesta invalida del servidor.');
    }

    final texto = (raw['texto'] ?? '').toString().trim();
    if (texto.isEmpty) {
      throw Exception('No hay informacion disponible para compartir.');
    }

    return texto;
  }

  static Future<void> deleteDetalle({
    required int dispositivoId,
    required int detalleId,
  }) async {
    final headers = await _headersJson();
    final resp = await http.delete(
      Uri.parse('${_childBase(dispositivoId)}/$detalleId'),
      headers: headers,
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }
  }
}
