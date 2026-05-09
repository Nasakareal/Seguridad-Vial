import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/delegaciones_home_models.dart';
import 'auth_service.dart';

class DelegacionesHomeService {
  static const int defaultDays = 30;
  static const int defaultWazeMinutes = 30;
  static const int defaultLimit = 350;
  static const String _cacheKey = 'delegaciones_home_map_cache_v2';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sesion invalida. Vuelve a iniciar sesion.');
    }

    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String _parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map<String, dynamic>) {
        final message = raw['message']?.toString().trim() ?? '';
        if (message.isNotEmpty) return message;
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }

  static Future<DelegacionesHomeMapData> fetchMapa({
    int days = defaultDays,
    int wazeMinutes = defaultWazeMinutes,
    int limit = defaultLimit,
  }) async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/delegaciones-home/mapa')
          .replace(
            queryParameters: <String, String>{
              'days': days.toString(),
              'waze_minutes': wazeMinutes.toString(),
              'limit': limit.toString(),
            },
          );

      final res = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          await _storeCache(decoded);
          return DelegacionesHomeMapData.fromJson(decoded);
        }
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          await _storeCache(map);
          return DelegacionesHomeMapData.fromJson(map);
        }
        throw Exception('Respuesta invalida al cargar mapa de delegaciones.');
      }

      if (res.statusCode == 401) {
        throw Exception(_parseBackendError(res.body, res.statusCode));
      }
    } catch (error) {
      if (error.toString().contains('Sesion invalida') ||
          error.toString().contains('401')) {
        rethrow;
      }
    }

    return await readCachedMapa() ?? DelegacionesHomeMapData.empty();
  }

  static Future<DelegacionesHomeMapData?> readCachedMapa() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey)?.trim() ?? '';
    if (raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return DelegacionesHomeMapData.fromJson(decoded);
      }
      if (decoded is Map) {
        return DelegacionesHomeMapData.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {}

    return null;
  }

  static Future<void> _storeCache(Map<String, dynamic> json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(json));
    } catch (_) {}
  }
}
