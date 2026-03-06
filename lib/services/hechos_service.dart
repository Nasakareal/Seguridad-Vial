import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class HechosService {
  static Future<Map<String, dynamic>> fetchById(int id) async {
    final token = await AuthService.getToken();

    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = Uri.parse('${AuthService.baseUrl}/hechos/$id');
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final raw = jsonDecode(res.body);

    if (raw is Map<String, dynamic> && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data']);
    }
    if (raw is Map<String, dynamic> && raw['hecho'] is Map) {
      return Map<String, dynamic>.from(raw['hecho']);
    }
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    return {};
  }
}
