import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'push_service.dart';

class AuthService {
  static const String _baseUrl = 'https://seguridadvial-mich.com/api';

  static const String _tokenKey = 'auth_token';
  static const String _roleKey = 'auth_role';
  static const String _roleIdKey = 'auth_role_id';
  static const String _permsKey = 'auth_perms';
  static const String _userIdKey = 'auth_user_id';
  static const String _userEmailKey = 'auth_user_email';
  static const String _sessionOwnerKeyKey = 'auth_session_owner_key';

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
      int? roleId;
      if (data['role'] != null) {
        if (data['role'] is Map) {
          final roleMap = data['role'] as Map;
          if (roleMap['name'] != null) role = roleMap['name'].toString();
          final rawRoleId = roleMap['id'];
          roleId = int.tryParse(rawRoleId?.toString() ?? '');
        } else {
          role = data['role'].toString();
        }
      } else if (data['user'] is Map && data['user']['role'] != null) {
        final rawRole = data['user']['role'];
        if (rawRole is Map) {
          if (rawRole['name'] != null) role = rawRole['name'].toString();
          roleId = int.tryParse(rawRole['id']?.toString() ?? '');
        } else {
          role = rawRole.toString();
        }
      } else if (data['user'] is Map && data['user']['roles'] is List) {
        final roles = data['user']['roles'] as List;
        if (roles.isNotEmpty) {
          final r0 = roles.first;
          if (r0 is Map) {
            if (r0['name'] != null) role = r0['name'].toString();
            roleId = int.tryParse(r0['id']?.toString() ?? '');
          }
          if (r0 is String) role = r0;
        }
      }

      roleId ??= int.tryParse(
        (data['role_id'] ??
                    (data['user'] is Map ? data['user']['role_id'] : null))
                ?.toString() ??
            '',
      );

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
      final normalizedEmail = email.trim().toLowerCase();
      await prefs.setString(_tokenKey, token.toString());
      await prefs.setString(_userEmailKey, normalizedEmail);

      final user = data['user'];
      final dynamic rawUserId = user is Map
          ? (user['id'] ?? user['user_id'])
          : null;
      final userId = int.tryParse(rawUserId?.toString() ?? '');
      if (userId != null && userId > 0) {
        await prefs.setInt(_userIdKey, userId);
      } else {
        await prefs.remove(_userIdKey);
      }

      if (role != null && role.trim().isNotEmpty) {
        await prefs.setString(_roleKey, role.trim());
      } else {
        await prefs.remove(_roleKey);
      }

      if (roleId != null && roleId > 0) {
        await prefs.setInt(_roleIdKey, roleId);
      } else {
        await prefs.remove(_roleIdKey);
      }

      if (perms.isNotEmpty) {
        await prefs.setStringList(_permsKey, perms);
      } else {
        await prefs.remove(_permsKey);
      }

      await prefs.setString(
        _sessionOwnerKeyKey,
        _buildSessionOwnerKey(
          userId: userId,
          email: normalizedEmail,
          token: token.toString(),
        ),
      );

      try {
        await refreshPermissions();
      } catch (_) {}

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

  static Future<int?> getRoleId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_roleIdKey);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  static Future<String?> getSessionOwnerKey() async {
    final prefs = await SharedPreferences.getInstance();

    final stored = prefs.getString(_sessionOwnerKeyKey)?.trim() ?? '';
    if (stored.isNotEmpty) {
      return stored;
    }

    final userId = prefs.getInt(_userIdKey);
    if (userId != null && userId > 0) {
      final ownerKey = 'user:$userId';
      await prefs.setString(_sessionOwnerKeyKey, ownerKey);
      return ownerKey;
    }

    final email = prefs.getString(_userEmailKey);
    final normalized = email?.trim().toLowerCase() ?? '';
    if (normalized.isNotEmpty) {
      final ownerKey = 'email:$normalized';
      await prefs.setString(_sessionOwnerKeyKey, ownerKey);
      return ownerKey;
    }

    final token = prefs.getString(_tokenKey)?.trim() ?? '';
    if (token.isNotEmpty) {
      final ownerKey = _buildSessionOwnerKey(token: token);
      await prefs.setString(_sessionOwnerKeyKey, ownerKey);
      return ownerKey;
    }

    return null;
  }

  static Future<bool> isSuperadmin() async {
    final role = await getRole();
    if (role == null) return false;
    return role.trim().toLowerCase() == 'superadmin';
  }

  static Future<bool> isPerito() async {
    final roleId = await getRoleId();
    if (roleId == 4) return true;

    final role = await getRole();
    if (role == null) return false;
    return role.trim().toLowerCase() == 'perito';
  }

  static Future<bool> isAgenteUpec() async {
    final role = await getRole();
    final normalized = role?.trim().toLowerCase() ?? '';
    if (normalized.contains('upec')) {
      return true;
    }

    final perms = await getPermissions();
    return perms.any((perm) => perm.contains('upec'));
  }

  static Future<bool> shouldAskLocation() async {
    return await isPerito();
  }

  static Future<List<String>> getPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_permsKey) ?? <String>[];
  }

  static Future<List<String>> refreshPermissions() async {
    final token = await getToken();
    if (token == null || token.trim().isEmpty) return await getPermissions();

    final res = await http
        .get(
          Uri.parse('$_baseUrl/permissions'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) return await getPermissions();

    final data = jsonDecode(res.body);
    if (data is! List) return await getPermissions();

    var perms = data.map((e) => e.toString()).toList();
    perms = perms
        .map((p) => p.trim().toLowerCase())
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_permsKey, perms);
    return perms;
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
    await prefs.remove(_roleIdKey);
    await prefs.remove(_permsKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_sessionOwnerKeyKey);
  }

  static String _buildSessionOwnerKey({
    int? userId,
    String? email,
    String? token,
  }) {
    if (userId != null && userId > 0) {
      return 'user:$userId';
    }

    final normalizedEmail = email?.trim().toLowerCase() ?? '';
    if (normalizedEmail.isNotEmpty) {
      return 'email:$normalizedEmail';
    }

    final normalizedToken = token?.trim() ?? '';
    if (normalizedToken.isNotEmpty) {
      return 'token:${_stableHash(normalizedToken)}';
    }

    return 'anonymous';
  }

  static String _stableHash(String value) {
    var hash = 0x811C9DC5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
