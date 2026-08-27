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

  Future<List<SemaforoNode>> listNodes({String query = ''}) async {
    final uri = Uri.parse('$_base/nodos').replace(
      queryParameters: query.trim().isEmpty ? null : {'q': query.trim()},
    );
    final response = await http
        .get(uri, headers: await _headers())
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

  Future<SemaforoNode> syncNodeConfiguration({
    required Map<String, String> configuration,
    SemaforoNode? catalogNode,
  }) async {
    final nodeId = (configuration['node'] ?? catalogNode?.id ?? '').trim();
    final route = (configuration['route'] ?? catalogNode?.route ?? '').trim();
    if (nodeId.isEmpty || route.isEmpty) {
      throw Exception(
        'La respuesta LoRa no contiene identidad y ruta válidas.',
      );
    }

    final response = await http
        .post(
          Uri.parse('$_base/nodos/sincronizar'),
          headers: await _headers(),
          body: jsonEncode({
            'node_id': nodeId,
            'ruta': route,
            'nombre': configuration['name'] ?? catalogNode?.name ?? route,
            'ubicacion': catalogNode?.location,
            'vialidad_principal':
                configuration['street1'] ?? catalogNode?.primaryStreet,
            'vialidad_transversal':
                configuration['street2'] ?? catalogNode?.secondaryStreet,
            'latitud': catalogNode?.latitude,
            'longitud': catalogNode?.longitude,
            'plan_activo': configuration['mode'] ?? catalogNode?.activePlan,
            'horario_inicio':
                configuration['start'] ?? catalogNode?.scheduleStart,
            'horario_fin': configuration['end'] ?? catalogNode?.scheduleEnd,
            'horario_estado':
                configuration['schedule'] ?? catalogNode?.scheduleStatus,
            'estado_operativo': 'online',
            'configuracion': configuration,
          }),
        )
        .timeout(const Duration(seconds: 8));
    final body = _decode(response.body);
    if (![200, 201].contains(response.statusCode)) {
      throw Exception(_message(body, 'No se pudo sincronizar el crucero.'));
    }
    final raw = body['data'];
    if (raw is! Map) throw Exception('Respuesta inválida del catálogo.');
    return SemaforoNode.fromJson(Map<String, dynamic>.from(raw));
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
