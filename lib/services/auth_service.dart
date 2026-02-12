import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'push_service.dart';

class AuthService {
  static const String _baseUrl = 'https://seguridadvial-mich.com/api';

  static const String _tokenKey = 'auth_token';
  static const String _roleKey = 'auth_role';
  static const String _permsKey = 'auth_perms';

  static String get baseUrl => _baseUrl;

  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Accept': 'application/json'},
            body: {'email': email, 'password': password},
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        await _clearLocalSession();
        return false;
      }

      final data = jsonDecode(response.body);

      final token = data['token'];
      if (token == null || token.toString().trim().isEmpty) {
        await _clearLocalSession();
        return false;
      }

      String? role;
      if (data['role'] != null) {
        role = data['role'].toString();
      } else if (data['user'] is Map && data['user']['role'] != null) {
        role = data['user']['role'].toString();
      } else if (data['user'] is Map && data['user']['roles'] is List) {
        final roles = data['user']['roles'] as List;
        if (roles.isNotEmpty) {
          final r0 = roles.first;
          if (r0 is Map && r0['name'] != null) role = r0['name'].toString();
          if (r0 is String) role = r0;
        }
      }

      List<String> perms = [];

      final dynamic rawPerms =
          data['permissions'] ??
          (data['user'] is Map ? data['user']['permissions'] : null) ??
          (data['user'] is Map ? data['user']['permisos'] : null);

      if (rawPerms is List) {
        perms = rawPerms.map((e) => e.toString()).toList();
      }

      if (rawPerms is List && rawPerms.isNotEmpty && rawPerms.first is Map) {
        perms = rawPerms
            .map(
              (e) =>
                  (e is Map && e['name'] != null) ? e['name'].toString() : '',
            )
            .where((s) => s.trim().isNotEmpty)
            .toList();
      }

      perms = perms
          .map((p) => p.trim().toLowerCase())
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_tokenKey, token.toString());

      if (role != null && role.trim().isNotEmpty) {
        await prefs.setString(_roleKey, role.trim());
      } else {
        await prefs.remove(_roleKey);
      }

      if (perms.isNotEmpty) {
        await prefs.setStringList(_permsKey, perms);
      } else {
        await prefs.remove(_permsKey);
      }

      try {
        PushService.registerDeviceToken(reason: 'login');
      } catch (_) {}

      return true;
    } catch (_) {
      await _clearLocalSession();
      return false;
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<bool> isSuperadmin() async {
    final role = await getRole();
    if (role == null) return false;
    return role.trim().toLowerCase() == 'superadmin';
  }

  static Future<List<String>> getPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_permsKey) ?? <String>[];
  }

  static Future<bool> can(String permission) async {
    final perms = await getPermissions();
    final p = permission.trim().toLowerCase();
    return perms.contains(p);
  }

  static Future<bool> canAny(List<String> permissions) async {
    final perms = await getPermissions();
    final set = perms.toSet();
    for (final p in permissions) {
      if (set.contains(p.trim().toLowerCase())) return true;
    }
    return false;
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    final token = await getToken();

    if (token != null && token.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse('$_baseUrl/logout'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    await _clearLocalSession();
  }

  static Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_permsKey);
  }
}
