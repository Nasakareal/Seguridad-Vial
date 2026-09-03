import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/traffic_controller.dart';

class TrafficControllerConnection {
  final String endpoint;
  final String accessKey;

  const TrafficControllerConnection({
    required this.endpoint,
    required this.accessKey,
  });
}

class TrafficControllerService {
  static const _endpointKey = 'traffic_controller_endpoint_v1';
  static const _accessKey = 'traffic_controller_access_key_v1';
  static const defaultEndpoint = 'http://192.168.4.1';
  static const defaultAccessKey = 'fomento6';

  final http.Client _client;

  TrafficControllerService({http.Client? client})
    : _client = client ?? http.Client();

  Future<TrafficControllerConnection> loadConnection() async {
    final prefs = await SharedPreferences.getInstance();
    return TrafficControllerConnection(
      endpoint: _normalizeEndpoint(
        prefs.getString(_endpointKey) ?? defaultEndpoint,
      ),
      accessKey: defaultAccessKey,
    );
  }

  Future<void> saveConnection(TrafficControllerConnection value) async {
    final endpoint = _normalizeEndpoint(value.endpoint);
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw Exception('La dirección del controlador no es válida.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_endpointKey, endpoint);
    await prefs.setString(_accessKey, defaultAccessKey);
  }

  Future<TrafficControllerStatus> getStatus() async {
    final connection = await loadConnection();
    late http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('${connection.endpoint}/api/status'),
            headers: _headers(connection),
          )
          .timeout(const Duration(seconds: 4));
    } on TimeoutException {
      throw Exception(
        'No se encontró el maestro. Conecta el teléfono al Wi-Fi '
        'SV-SEMAFORO-MAESTRO y vuelve a intentar.',
      );
    } on http.ClientException {
      throw Exception(
        'No se pudo abrir 192.168.4.1. Verifica que el teléfono esté '
        'conectado al Wi-Fi SV-SEMAFORO-MAESTRO.',
      );
    }
    final body = _decode(response.body);
    _requireSuccess(response.statusCode, body);
    return TrafficControllerStatus.fromJson(body);
  }

  Future<TrafficControllerStatus> applyPlan(TrafficControllerPlan plan) async {
    final error = plan.validate();
    if (error != null) throw Exception(error);
    return _send('PUT', '/api/plan', plan.toJson());
  }

  Future<TrafficControllerStatus> start() =>
      _send('POST', '/api/start', const {});

  Future<TrafficControllerStatus> stop() =>
      _send('POST', '/api/stop', const {});

  Future<TrafficControllerStatus> emergencyAllRed() =>
      _send('POST', '/api/emergency-red', const {});

  Future<TrafficControllerStatus> _send(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final connection = await loadConnection();
    final request =
        http.Request(method, Uri.parse('${connection.endpoint}$path'))
          ..headers.addAll(_headers(connection))
          ..body = jsonEncode(body);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 5));
    final response = await http.Response.fromStream(streamed);
    final decoded = _decode(response.body);
    _requireSuccess(response.statusCode, decoded);
    return TrafficControllerStatus.fromJson(decoded);
  }

  Map<String, String> _headers(TrafficControllerConnection connection) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-SV-Controller-Key': connection.accessKey,
  };

  static Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const {};
  }

  static void _requireSuccess(int statusCode, Map<String, dynamic> body) {
    if (statusCode >= 200 && statusCode < 300) return;
    final message = (body['message'] ?? body['error'] ?? '').toString().trim();
    throw Exception(
      message.isEmpty
          ? 'El controlador respondió con error $statusCode.'
          : message,
    );
  }

  static String _normalizeEndpoint(String raw) {
    var value = raw.trim();
    if (value.isEmpty) value = defaultEndpoint;
    if (!value.contains('://')) value = 'http://$value';
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  void dispose() => _client.close();
}
