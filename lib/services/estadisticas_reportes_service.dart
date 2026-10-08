import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class EstadisticasReportesService {
  Future<Map<String, dynamic>> cargar(
    String reporte, {
    Map<String, dynamic>? params,
  }) async {
    final token = await AuthService.getToken();
    final query = <String, String>{};
    params?.forEach((key, value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) query[key] = text;
    });
    final uri = Uri.parse(
      '${AuthService.baseUrl}/estadisticas-reportes/$reporte',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(
      uri,
      headers: <String, String>{
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      var message = 'Error HTTP ${response.statusCode}';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          message = body['message'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }
}
