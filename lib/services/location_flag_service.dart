import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class LocationFlagService {
  static const String apiBase = 'https://seguridadvial-mich.com/api';

  static bool _toBool(dynamic v) {
    return v == true ||
        (v is num && v == 1) ||
        ('$v'.trim() == '1') ||
        ('$v'.trim().toLowerCase() == 'true');
  }

  static Future<bool> isEnabledForMe() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return false;

    final res = await http.get(
      Uri.parse('$apiBase/me'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (res.statusCode != 200) return false;

    final j = jsonDecode(res.body);

    dynamic v;

    if (j is Map && j['compartir_ubicacion'] != null) {
      v = j['compartir_ubicacion'];
    }

    if (v == null && j is Map && j['user'] is Map) {
      final u = j['user'] as Map;
      if (u['compartir_ubicacion'] != null) v = u['compartir_ubicacion'];
    }

    if (v == null && j is Map && j['data'] is Map) {
      final d = j['data'] as Map;
      if (d['compartir_ubicacion'] != null) v = d['compartir_ubicacion'];
    }

    return _toBool(v);
  }
}
