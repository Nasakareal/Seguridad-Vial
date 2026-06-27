import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/conduce_legalidad.dart';
import 'auth_service.dart';
import 'offline_sync_service.dart';

class ConduceLegalidadService {
  static const String _path = '/conduce-legalidad';

  static Future<ConduceLegalidadMeta> fetchMeta() async {
    final res = await http.get(
      Uri.parse('${AuthService.baseUrl}$_path/meta'),
      headers: await _headers(),
    );
    final body = _decodeJson(res);
    _throwIfNotOk(res, body, 'No se pudo cargar el modulo.');
    return ConduceLegalidadMeta.fromJson(body);
  }

  static Future<List<ConduceLegalidadOperativo>> fetchOperativos({
    bool incluirCerrados = false,
  }) async {
    final uri = Uri.parse('${AuthService.baseUrl}$_path/operativos').replace(
      queryParameters: incluirCerrados
          ? const <String, String>{'incluir_cerrados': '1'}
          : null,
    );
    final res = await http.get(uri, headers: await _headers());
    final body = _decodeJson(res);
    _throwIfNotOk(res, body, 'No se pudieron cargar los operativos.');
    final list = body['data'] is List ? body['data'] as List : const [];
    return list
        .whereType<Map>()
        .map((item) => ConduceLegalidadOperativo.fromJson(_map(item)))
        .toList();
  }

  static Future<ConduceLegalidadOperativo> fetchOperativo(int id) async {
    final res = await http.get(
      Uri.parse('${AuthService.baseUrl}$_path/operativos/$id'),
      headers: await _headers(),
    );
    final body = _decodeJson(res);
    _throwIfNotOk(res, body, 'No se pudo cargar el operativo.');
    return ConduceLegalidadOperativo.fromJson(_map(body['data']));
  }

  static Future<ConduceLegalidadOperativo> createOperativo(
    Map<String, dynamic> payload,
  ) async {
    final res = await http.post(
      Uri.parse('${AuthService.baseUrl}$_path/operativos'),
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final body = _decodeJson(res);
    _throwIfNotOk(res, body, 'No se pudo crear el operativo.');
    return ConduceLegalidadOperativo.fromJson(_map(body['data']));
  }

  static Future<ConduceLegalidadOperativo> updateOperativo(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final res = await http.put(
      Uri.parse('${AuthService.baseUrl}$_path/operativos/$id'),
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final body = _decodeJson(res);
    _throwIfNotOk(res, body, 'No se pudo actualizar el operativo.');
    return ConduceLegalidadOperativo.fromJson(_map(body['data']));
  }

  static Future<void> destroyOperativo(int id) async {
    final res = await http.delete(
      Uri.parse('${AuthService.baseUrl}$_path/operativos/$id'),
      headers: await _headers(),
    );
    final body = _decodeJson(res);
    _throwIfNotOk(res, body, 'No se pudo eliminar el operativo.');
  }

  static Future<OfflineActionResult> storeCaptura({
    required int operativoId,
    required Map<String, dynamic> payload,
    List<File> fotos = const <File>[],
  }) async {
    final body = Map<String, dynamic>.from(payload);
    final clientUuid = (body['client_uuid'] ?? '').toString().trim().isNotEmpty
        ? body['client_uuid'].toString().trim()
        : OfflineSyncService.newClientUuid();
    body['client_uuid'] = clientUuid;
    final uri = Uri.parse(
      '${AuthService.baseUrl}$_path/operativos/$operativoId/capturas',
    );

    if (fotos.isNotEmpty) {
      return OfflineSyncService.submitMultipart(
        label: 'Captura Conduce Legalidad',
        method: 'POST',
        uri: uri,
        fields: _flattenMultipartFields(body),
        files: [
          for (final foto in fotos)
            OfflineUploadFile(field: 'fotos[]', path: foto.path),
        ],
        requestId: clientUuid,
        successCodes: const <int>{200, 201},
        errorParser: _errorTextFromRawBody,
      );
    }

    return OfflineSyncService.submitJson(
      label: 'Captura Conduce Legalidad',
      method: 'POST',
      uri: uri,
      body: body,
      requestId: clientUuid,
      successCodes: const <int>{200, 201},
      errorParser: _errorTextFromRawBody,
    );
  }

  static Future<OfflineActionResult> updateCaptura({
    required int operativoId,
    required int capturaId,
    required Map<String, dynamic> payload,
    List<File> fotos = const <File>[],
  }) async {
    final body = Map<String, dynamic>.from(payload);
    final requestId = OfflineSyncService.newClientUuid();
    final uri = Uri.parse(
      '${AuthService.baseUrl}$_path/operativos/$operativoId/capturas/$capturaId',
    );

    if (fotos.isNotEmpty) {
      final fields = _flattenMultipartFields(body);
      fields['_method'] = 'PUT';
      return OfflineSyncService.submitMultipart(
        label: 'Captura Conduce Legalidad',
        method: 'POST',
        uri: uri,
        fields: fields,
        files: [
          for (final foto in fotos)
            OfflineUploadFile(field: 'fotos[]', path: foto.path),
        ],
        requestId: requestId,
        successCodes: const <int>{200},
        errorParser: _errorTextFromRawBody,
      );
    }

    return OfflineSyncService.submitJson(
      label: 'Captura Conduce Legalidad',
      method: 'PUT',
      uri: uri,
      body: body,
      requestId: requestId,
      successCodes: const <int>{200},
      errorParser: _errorTextFromRawBody,
    );
  }

  static Future<void> destroyCaptura({
    required int operativoId,
    required int capturaId,
  }) async {
    final res = await http.delete(
      Uri.parse(
        '${AuthService.baseUrl}$_path/operativos/$operativoId/capturas/$capturaId',
      ),
      headers: await _headers(),
    );
    final body = _decodeJson(res);
    _throwIfNotOk(res, body, 'No se pudo eliminar la captura.');
  }

  static Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sin token. Inicia sesion otra vez.');
    }

    return <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      ...await AuthService.mobileSessionHeaders(),
    };
  }

  static Map<String, dynamic> _decodeJson(http.Response res) {
    final text = _decodeBody(res);
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return _map(decoded);
    } catch (_) {}
    return <String, dynamic>{'message': text};
  }

  static String _decodeBody(http.Response res) {
    try {
      return utf8.decode(res.bodyBytes);
    } catch (_) {
      return res.body;
    }
  }

  static void _throwIfNotOk(
    http.Response res,
    Map<String, dynamic> body,
    String fallback,
  ) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    final message = _messageFromBody(body).trim();
    if (message.isNotEmpty) {
      throw Exception(message);
    }
    throw Exception('$fallback HTTP ${res.statusCode}.');
  }

  static String _messageFromBody(Map<String, dynamic> body) {
    final message = (body['message'] ?? '').toString().trim();
    if (message.isNotEmpty) return message;

    final errors = body['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
    }

    return '';
  }

  static String _errorTextFromRawBody(String rawBody, int statusCode) {
    try {
      final decoded = jsonDecode(rawBody);
      final body = decoded is Map<String, dynamic>
          ? decoded
          : decoded is Map
          ? _map(decoded)
          : const <String, dynamic>{};
      final message = _messageFromBody(body).trim();
      if (message.isNotEmpty) return message;
    } catch (_) {}

    final text = rawBody.trim();
    if (text.isEmpty ||
        text.startsWith('<!doctype') ||
        text.startsWith('<html')) {
      return 'No se pudo guardar la captura. HTTP $statusCode.';
    }
    return text;
  }

  static Map<String, String> _flattenMultipartFields(
    Map<String, dynamic> source,
  ) {
    final fields = <String, String>{};

    void add(String key, dynamic value) {
      if (value == null) return;

      if (value is Map) {
        for (final entry in value.entries) {
          add('$key[${entry.key}]', entry.value);
        }
        return;
      }

      if (value is Iterable && value is! String) {
        var index = 0;
        for (final item in value) {
          add('$key[$index]', item);
          index += 1;
        }
        return;
      }

      if (value is bool) {
        fields[key] = value ? '1' : '0';
        return;
      }

      fields[key] = value.toString();
    }

    for (final entry in source.entries) {
      add(entry.key, entry.value);
    }

    return fields;
  }

  static Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }
}
