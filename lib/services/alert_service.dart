import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AlertService {
  static const String baseUrl = 'https://seguridadvial-mich.com/api';

  static Future<List<dynamic>> fetchAlerts() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return [];

    final res = await http.get(
      Uri.parse('$baseUrl/alerts'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body);

    // tu API devuelve paginate(), esto trae "data"
    return (body['data'] as List?) ?? [];
  }

  static Future<bool> markRead(int alertId) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return false;

    final res = await http.post(
      Uri.parse('$baseUrl/alerts/$alertId/read'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    return res.statusCode >= 200 && res.statusCode < 300;
  }
}
