import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class DelegacionesExcelRevisionService {
  static String get _base => AuthService.baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri({required String fecha}) {
    return Uri.parse('$_base/delegaciones/excel-revision').replace(
      queryParameters: <String, String>{
        if (fecha.trim().isNotEmpty) 'fecha': fecha.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> fetch({required DateTime fecha}) async {
    final res = await http.get(
      _uri(fecha: _fmtYmd(fecha)),
      headers: await _headers(),
    );

    if (res.statusCode != 200) {
      throw _error(res, 'No se pudo cargar la revisión del Excel.');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception('Respuesta inválida del servidor.');
  }

  Exception _error(http.Response res, String fallback) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['message'] != null) {
        return Exception(decoded['message'].toString());
      }
    } catch (_) {}

    return Exception('$fallback HTTP ${res.statusCode}');
  }

  static String _fmtYmd(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}
