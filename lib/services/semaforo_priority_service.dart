import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/semaforo_priority.dart';
import 'auth_service.dart';

class SemaforoPriorityService {
  static String get _base => '${AuthService.baseUrl}/control-semaforico';
  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('La sesión no está disponible.');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<SemaforoNode>> listNodes() async {
    final response = await http
        .get(Uri.parse('$_base/nodos'), headers: await _headers())
        .timeout(const Duration(seconds: 8));
    final body = _decode(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        _message(body, 'El gateway LoRa todavía no está disponible.'),
      );
    }
    final raw = body['data'] ?? body['nodos'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => SemaforoNode.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty)
        .toList();
  }

  Future<SemaforoPriorityRequest> requestPriority(
    SemaforoNode node,
    int seconds,
    String reason,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_base/prioridades'),
          headers: await _headers(),
          body: jsonEncode({
            'node_id': node.id,
            'ruta': node.route,
            'duracion_segundos': seconds,
            'motivo': reason.trim(),
            'requiere_ack_nodo': true,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final body = _decode(response.body);
    if (![200, 201, 202].contains(response.statusCode)) {
      throw Exception(_message(body, 'El gateway rechazó la solicitud.'));
    }
    final raw = body['data'] ?? body;
    if (raw is! Map) throw Exception('Respuesta inválida del gateway.');
    return SemaforoPriorityRequest.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<SemaforoPriorityRequest> getRequest(String id) async {
    final response = await http
        .get(Uri.parse('$_base/prioridades/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 8));
    final body = _decode(response.body);
    if (response.statusCode != 200) {
      throw Exception('Sin confirmación del nodo.');
    }
    final raw = body['data'] ?? body;
    if (raw is! Map) throw Exception('Respuesta inválida del gateway.');
    return SemaforoPriorityRequest.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> clearPriority(String id) async {
    final response = await http
        .post(
          Uri.parse('$_base/prioridades/$id/cancelar'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 8));
    if (![200, 202].contains(response.statusCode)) {
      throw Exception('No se confirmó la cancelación.');
    }
  }

  static Map<String, dynamic> _decode(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is Map ? Map<String, dynamic>.from(value) : {};
    } catch (_) {
      return {};
    }
  }

  static String _message(Map<String, dynamic> body, String fallback) {
    final value = (body['message'] ?? body['mensaje'] ?? '').toString().trim();
    return value.isEmpty ? fallback : value;
  }
}
