import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class EstadisticasAseguramientosService {
  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final params = <String, String>{};
    query?.forEach((key, value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) params[key] = text;
    });
    return Uri.parse(
      '${AuthService.baseUrl}$path',
    ).replace(queryParameters: params.isEmpty ? null : params);
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    final response = await http.get(
      _uri(path, query),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      var message = 'Error HTTP ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          message = decoded['message'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }
    final decoded = jsonDecode(response.body);
    return (decoded as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> catalogos() =>
      _get('/estadisticas-aseguramientos/catalogos');

  Future<Map<String, dynamic>> resumen(Map<String, dynamic> params) =>
      _get('/estadisticas-aseguramientos/resumen', params);
}
