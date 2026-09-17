import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class PatrullaServicioException implements Exception {
  final String message;

  const PatrullaServicioException(this.message);

  @override
  String toString() => message;
}

class PatrullaServicioService {
  static String get _base => '${AuthService.baseUrl}/patrullas';

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await AuthService.getToken();
    return <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<Map<String, dynamic>>> disponibles() async {
    final response = await http
        .get(Uri.parse('$_base/disponibles'), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final body = _decode(response);
    final raw = body['data'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<Map<String, dynamic>> miServicio() async {
    final response = await http
        .get(Uri.parse('$_base/mi-servicio'), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  static Future<Map<String, dynamic>?> miBitacora() async {
    final response = await http
        .get(Uri.parse('$_base/mi-bitacora'), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) return null;
    return _decode(response);
  }

  static Future<List<Map<String, dynamic>>> miHistorial() async {
    final response = await http
        .get(
          Uri.parse('$_base/mi-historial?per_page=50'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 20));
    final body = _decode(response);
    final raw = body['data'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<Map<String, dynamic>> recibir({
    required int patrullaId,
    required Map<String, String> fields,
    Map<String, String> photos = const <String, String>{},
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/$patrullaId/recibir'),
    );
    request.headers.addAll(await _headers(json: false));
    request.fields.addAll(fields);
    for (final entry in photos.entries) {
      if (entry.value.trim().isEmpty) continue;
      request.files.add(
        await http.MultipartFile.fromPath(entry.key, entry.value),
      );
    }
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    return _decode(await http.Response.fromStream(streamed));
  }

  static Future<Map<String, dynamic>> entregar({
    required int patrullaId,
    required int kilometraje,
    required double nivelCombustible,
    String? novedades,
    String? observaciones,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/$patrullaId/entregar'),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{
            'kilometraje': kilometraje,
            'nivel_combustible': nivelCombustible,
            if (novedades?.trim().isNotEmpty == true)
              'novedades': novedades!.trim(),
            if (observaciones?.trim().isNotEmpty == true)
              'observaciones': observaciones!.trim(),
          }),
        )
        .timeout(const Duration(seconds: 30));
    return _decode(response);
  }

  static Future<Map<String, dynamic>> actualizarServicio({
    int? kilometraje,
    double? nivelCombustible,
    String? observaciones,
  }) async {
    final response = await http
        .put(
          Uri.parse('$_base/mi-servicio'),
          headers: await _headers(),
          body: jsonEncode(<String, dynamic>{
            if (kilometraje != null) 'kilometraje': kilometraje,
            if (nivelCombustible != null) 'nivel_combustible': nivelCombustible,
            if (observaciones != null) 'observaciones': observaciones.trim(),
          }),
        )
        .timeout(const Duration(seconds: 25));
    return _decode(response);
  }

  static Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    final errors = body['errors'];
    String? detail;
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          detail = value.first.toString();
          break;
        }
        if (value != null) {
          detail = value.toString();
          break;
        }
      }
    }
    throw PatrullaServicioException(
      detail ??
          body['message']?.toString() ??
          'No fue posible completar la operación.',
    );
  }
}
