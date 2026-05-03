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
  static const String _userNameKey = 'auth_user_name';
  static const String _userPayloadKey = 'auth_user_payload';
  static const String _unidadIdKey = 'auth_unidad_id';
  static const String _delegacionIdKey = 'auth_delegacion_id';
  static const String _destacamentoIdKey = 'auth_destacamento_id';
  static const String _sessionOwnerKeyKey = 'auth_session_owner_key';
  static const int unidadDelegacionesId = 2;
  static const int unidadSeguridadVialId = 3;
  static const int unidadProteccionCarreterasId = 4;
  static const int unidadVialidadesUrbanasId = 5;
  static const int unidadCulturaVialId = 6;
  static const String locationTrackingIntervalDefault = 'default';
  static const String locationTrackingIntervalExtended = 'extended';
  static const String locationTrackingIntervalHourly = 'hourly';

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

      final userPayload = _extractUserPayload(data);
      await _storeUserSnapshot(prefs, userPayload);
      perms = await _filterHechosPermissionsForCurrentUser(
        perms,
        userPayload: userPayload,
      );

      final userName = _extractUserName(data['user']) ?? _extractUserName(data);
      if (userName != null && userName.trim().isNotEmpty) {
        await prefs.setString(_userNameKey, userName.trim());
      } else {
        await prefs.remove(_userNameKey);
      }

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

  static Future<String?> getUserName({bool refreshIfMissing = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_userNameKey)?.trim() ?? '';
    if (stored.isNotEmpty) {
      return stored;
    }

    if (!refreshIfMissing) return null;

    try {
      final refreshed = await _refreshCurrentUserProfile();
      final name = _extractUserName(refreshed)?.trim() ?? '';
      if (name.isNotEmpty) {
        return name;
      }
    } catch (_) {}

    return null;
  }

  static Future<Map<String, dynamic>?> getStoredUserPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userPayloadKey)?.trim() ?? '';
    if (raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return null;
  }

  static Future<Map<String, dynamic>?> getCurrentUserPayload({
    bool refresh = false,
  }) async {
    if (!refresh) {
      final stored = await getStoredUserPayload();
      if (stored != null) return stored;
    }

    try {
      return await _refreshCurrentUserProfile();
    } catch (_) {
      return await getStoredUserPayload();
    }
  }

  static Future<int?> getUnidadId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_unidadIdKey);
  }

  static Future<int?> getDelegacionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_delegacionIdKey);
  }

  static Future<int?> getDestacamentoId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_destacamentoIdKey);
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
    final roleId = await getRoleId();
    if (roleId == 1) return true;

    final role = await getRole();
    if (role == null) return false;
    return role.trim().toLowerCase() == 'superadmin';
  }

  static Future<bool> hasFullOperationalAccess() async {
    if (await isSuperadmin()) return true;

    final unidadId = await getUnidadId();
    if (unidadId == unidadSeguridadVialId) {
      return true;
    }

    final payload = await getStoredUserPayload();
    final directId =
        _readNullableInt(payload?['unidad_id']) ??
        _readNullableInt(payload?['unidad_org_id']);
    return directId == unidadSeguridadVialId;
  }

  static Future<bool> isPerito() async {
    final roleId = await getRoleId();
    if (roleId == 4) return true;

    final role = await getRole();
    if (role == null) return false;
    return role.trim().toLowerCase() == 'perito';
  }

  static Future<bool> isAgenteUpec() async {
    final roleId = await getRoleId();
    if (roleId == 11) return true;

    final role = await getRole();
    final normalized = role?.trim().toLowerCase() ?? '';
    if (normalized.contains('upec')) {
      return true;
    }

    final perms = await getPermissions();
    return perms.any((perm) => perm.contains('upec'));
  }

  static Future<bool> isPolicia() async {
    final roleId = await getRoleId();
    if (roleId == 10) return true;

    final role = await getRole();
    if (_roleTextMatches(role, 'policia')) {
      return true;
    }

    final payload = await getStoredUserPayload();
    return _payloadHasRole(payload, 'policia');
  }

  static Future<bool> isDelegado() async {
    final role = await getRole();
    if (_roleTextMatches(role, 'delegado')) {
      return true;
    }

    final payload = await getStoredUserPayload();
    return _payloadHasRole(payload, 'delegado');
  }

  static Future<bool> isDelegadoLocationTrackingRole() async {
    final role = await getRole();
    if (_roleTextEquals(role, 'delegado')) {
      return true;
    }

    final payload = await getStoredUserPayload();
    return _payloadHasExactRole(payload, 'delegado');
  }

  static Future<bool> isAgenteVial() async {
    final roleId = await getRoleId();
    if (roleId == 12) return true;

    final role = await getRole();
    if (_roleTextMatches(role, 'agente vial')) {
      return true;
    }

    final payload = await getStoredUserPayload();
    return _payloadHasRole(payload, 'agente vial');
  }

  static Future<bool> hasRoleName(String roleName) async {
    final role = await getRole();
    if (_roleTextMatches(role, roleName)) {
      return true;
    }

    final payload = await getStoredUserPayload();
    return _payloadHasRole(payload, roleName);
  }

  static Future<bool> isJefeGrupo() async {
    final payload = await getStoredUserPayload();
    if (_payloadFlagIsTrue(payload, 'is_jefe_grupo')) {
      return true;
    }

    return hasRoleName('jefe de grupo');
  }

  static Future<bool> isAdministrativoRole() async {
    final roleId = await getRoleId();
    if (roleId == 5) return true;
    return hasRoleName('administrativo');
  }

  static Future<bool> isDelegacionesHechosPrivilegedRole() async {
    if (await isSuperadmin()) return true;

    final roleId = await getRoleId();
    if (roleId == 2 || roleId == 3) return true;

    return await hasRoleName('administrador') ||
        await hasRoleName('subdirector');
  }

  static Future<bool> hideDelegacionesHechoAdminFields({
    bool refresh = false,
  }) async {
    if (refresh) {
      await refreshCurrentUserAccess();
    }

    if (!await isDelegacionesUser()) {
      return false;
    }

    return !await isDelegacionesHechosPrivilegedRole();
  }

  static Future<bool> isSiniestrosUser({bool refresh = false}) async {
    if (refresh) {
      await refreshCurrentUserAccess();
    }

    if (await isSuperadmin()) {
      return true;
    }

    if (await isPerito() || await isJefeGrupo()) {
      return true;
    }

    final unidadId = await getUnidadId();
    if (unidadId == 1) {
      return true;
    }

    final payload = await getCurrentUserPayload(refresh: false);
    return _payloadMatchesSiniestros(payload);
  }

  static Future<bool> isDelegacionesUser({bool refresh = false}) async {
    if (refresh) {
      await refreshCurrentUserAccess();
    }

    final unidadId = await getUnidadId();
    if (unidadId == unidadDelegacionesId) {
      return true;
    }

    final payload = await getCurrentUserPayload(refresh: false);
    return _payloadMatchesDelegaciones(payload);
  }

  static Future<bool> canUseConstanciasManejo({bool refresh = false}) async {
    if (refresh) {
      await refreshCurrentUserAccess();
    }

    if (await isSuperadmin()) {
      return true;
    }

    if (!await can('ver modulo examenes')) {
      return false;
    }

    final unidadId = await getUnidadId();
    if (unidadId == 1 || unidadId == unidadDelegacionesId) {
      return true;
    }

    final payload = await getCurrentUserPayload(refresh: false);
    return _payloadHasAnyUnitId(payload, const <int>{1, unidadDelegacionesId});
  }

  static Future<bool> canEditConstanciasManejo({bool refresh = false}) async {
    if (refresh) {
      await refreshCurrentUserAccess();
    }

    if (await isSuperadmin()) {
      return true;
    }

    if (!await canUseConstanciasManejo()) {
      return false;
    }

    return can('editar modulo examenes');
  }

  static Future<bool> canShareLocationTracking() async {
    final unidadId = await getUnidadId();
    final payload = await getStoredUserPayload();

    final isSiniestros = unidadId == 1 || _payloadMatchesSiniestros(payload);
    if (isSiniestros && await isPerito()) {
      return true;
    }

    final isCarreteras =
        unidadId == unidadProteccionCarreterasId ||
        _payloadMatchesCarreterasStrict(payload);
    if (isCarreteras && await isAgenteUpec()) {
      return true;
    }

    final isDelegaciones =
        unidadId == unidadDelegacionesId ||
        _payloadMatchesDelegaciones(payload);
    if (isDelegaciones && await isDelegadoLocationTrackingRole()) {
      return true;
    }

    final isVialidadesUrbanas =
        unidadId == unidadVialidadesUrbanasId ||
        _payloadMatchesVialidadesUrbanasStrict(payload);
    if (isVialidadesUrbanas && await isAgenteVial()) {
      return true;
    }

    return false;
  }

  static Future<String> getLocationTrackingIntervalProfile() async {
    if (!await canShareLocationTracking()) {
      return locationTrackingIntervalDefault;
    }

    final unidadId = await getUnidadId();
    final payload = await getStoredUserPayload();

    final isDelegaciones =
        unidadId == unidadDelegacionesId ||
        _payloadMatchesDelegaciones(payload);
    if (isDelegaciones) {
      return locationTrackingIntervalHourly;
    }

    final isExtendedUnit =
        unidadId == unidadProteccionCarreterasId ||
        unidadId == unidadVialidadesUrbanasId ||
        _payloadMatchesCarreterasStrict(payload) ||
        _payloadMatchesVialidadesUrbanasStrict(payload);

    return isExtendedUnit
        ? locationTrackingIntervalExtended
        : locationTrackingIntervalDefault;
  }

  static Future<bool> shouldAskLocation() async {
    return await canShareLocationTracking();
  }

  static Future<List<String>> getPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_permsKey) ?? <String>[];
    final filtered = await _filterHechosPermissionsForCurrentUser(stored);

    if (!_sameStringSet(stored, filtered)) {
      await prefs.setStringList(_permsKey, filtered);
    }

    return filtered;
  }

  static Future<void> refreshCurrentUserAccess() async {
    try {
      await _refreshCurrentUserProfile();
    } catch (_) {}

    try {
      await refreshPermissions();
    } catch (_) {}
  }

  static Future<bool> isVialidadesUrbanasUser({bool refresh = false}) async {
    if (refresh) {
      await refreshCurrentUserAccess();
    }

    if (await isSuperadmin()) {
      return true;
    }

    final unidadId = await getUnidadId();
    if (unidadId == unidadVialidadesUrbanasId ||
        unidadId == unidadSeguridadVialId) {
      return true;
    }

    final payload = await getCurrentUserPayload(refresh: false);
    return _payloadMatchesVialidadesUrbanas(payload);
  }

  static Future<bool> isCarreterasUser({bool refresh = false}) async {
    if (refresh) {
      await refreshCurrentUserAccess();
    }

    if (await isSuperadmin()) {
      return true;
    }

    final unidadId = await getUnidadId();
    if (unidadId == unidadProteccionCarreterasId ||
        unidadId == unidadSeguridadVialId) {
      return true;
    }

    final payload = await getCurrentUserPayload(refresh: false);
    return _payloadMatchesCarreteras(payload);
  }

  static Future<bool> canCreateHechos({bool refresh = false}) async {
    if (refresh) {
      await refreshCurrentUserAccess();
    }

    if (await isSuperadmin()) {
      return true;
    }

    final unidadId = await getUnidadId();
    final payload = await getCurrentUserPayload(refresh: false);
    final isPeritoUser = await isPerito() || _payloadHasRole(payload, 'perito');
    if (isPeritoUser) {
      return true;
    }

    if (_isHechosCreateExcludedUnitId(unidadId)) {
      return false;
    }

    if (_payloadMatchesHechosCreateExcludedUnit(payload)) {
      return false;
    }

    final isDelegaciones =
        unidadId == unidadDelegacionesId ||
        _payloadMatchesDelegaciones(payload);
    if (isDelegaciones) {
      final permissions = await getPermissions();
      return permissions.contains('crear hechos');
    }

    return true;
  }

  static Future<bool> isHechosModuleExcludedUser({bool refresh = false}) async {
    if (refresh) {
      await refreshCurrentUserAccess();
    }

    if (await isSuperadmin()) {
      return false;
    }

    final unidadId = await getUnidadId();
    if (_isHechosCreateExcludedUnitId(unidadId)) {
      return true;
    }

    final payload = await getCurrentUserPayload(refresh: false);
    return _payloadMatchesHechosCreateExcludedUnit(payload);
  }

  static Future<bool> isHechosCaptureRelaxedUser({bool refresh = false}) async {
    if (refresh) {
      await refreshCurrentUserAccess();
    }

    final unidadId = await getUnidadId();
    if (_isHechosCaptureRelaxedUnitId(unidadId)) {
      return true;
    }

    final payload = await getCurrentUserPayload(refresh: false);
    return _payloadMatchesHechosCaptureRelaxedUnit(payload);
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
    perms = await _filterHechosPermissionsForCurrentUser(perms);

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

  static Future<Map<String, dynamic>> fetchProfile({
    bool refresh = true,
  }) async {
    if (!refresh) {
      final stored = await getStoredUserPayload();
      if (stored != null && stored.isNotEmpty) {
        return stored;
      }
    }

    return _fetchAndStoreCurrentUserProfile(
      endpoint: '$_baseUrl/profile',
      fallbackError: 'No se pudo obtener el perfil.',
    );
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final token = await getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    final response = await http
        .put(
          Uri.parse('$_baseUrl/profile/password'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'current_password': currentPassword,
            'password': newPassword,
            'password_confirmation': confirmPassword,
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _parseAuthError(
          response.body,
          response.statusCode,
          fallback: 'No se pudo actualizar la contraseña.',
        ),
      );
    }
  }

  static Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_roleIdKey);
    await prefs.remove(_permsKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userPayloadKey);
    await prefs.remove(_unidadIdKey);
    await prefs.remove(_delegacionIdKey);
    await prefs.remove(_destacamentoIdKey);
    await prefs.remove(_sessionOwnerKeyKey);
  }

  static Future<Map<String, dynamic>> _refreshCurrentUserProfile() async {
    return _fetchAndStoreCurrentUserProfile(
      endpoint: '$_baseUrl/me',
      fallbackError: 'No se pudo obtener el usuario actual.',
    );
  }

  static Future<Map<String, dynamic>> _fetchAndStoreCurrentUserProfile({
    required String endpoint,
    required String fallbackError,
  }) async {
    final token = await getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sesión inválida.');
    }

    final response = await http
        .get(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _parseAuthError(
          response.body,
          response.statusCode,
          fallback: fallbackError,
        ),
      );
    }

    final raw = jsonDecode(response.body);
    final payload = _extractUserPayload(raw);
    if (payload == null) {
      throw Exception('Respuesta inválida al obtener usuario actual.');
    }

    final prefs = await SharedPreferences.getInstance();
    await _storeUserSnapshot(prefs, payload);
    await _storeRoleSnapshot(prefs, raw, payload);

    final name = _extractUserName(payload)?.trim() ?? '';
    if (name.isNotEmpty) {
      await prefs.setString(_userNameKey, name);
    }

    final email = _extractUserEmail(payload)?.trim().toLowerCase() ?? '';
    if (email.isNotEmpty) {
      await prefs.setString(_userEmailKey, email);
    }

    final userId = int.tryParse('${payload['id'] ?? payload['user_id'] ?? ''}');
    if (userId != null && userId > 0) {
      await prefs.setInt(_userIdKey, userId);
    }

    return payload;
  }

  static String _parseAuthError(
    String body,
    int statusCode, {
    required String fallback,
  }) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map) {
        final errors = raw['errors'];
        if (errors is Map) {
          final messages = <String>[];
          for (final value in errors.values) {
            if (value is Iterable) {
              for (final item in value) {
                final text = item?.toString().trim() ?? '';
                if (text.isNotEmpty) {
                  messages.add(text);
                }
              }
              continue;
            }

            final text = value?.toString().trim() ?? '';
            if (text.isNotEmpty) {
              messages.add(text);
            }
          }

          if (messages.isNotEmpty) {
            return messages.join('\n');
          }
        }

        final message = raw['message']?.toString().trim() ?? '';
        if (message.isNotEmpty &&
            message.toLowerCase() != 'the given data was invalid.') {
          return message;
        }
      }
    } catch (_) {}

    if (statusCode == 401) {
      return 'Sesión inválida. Vuelve a iniciar sesión.';
    }

    return fallback;
  }

  static Map<String, dynamic>? _extractUserPayload(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      if (raw['user'] is Map) {
        final payload = Map<String, dynamic>.from(raw['user'] as Map);
        final flags = raw['flags'];
        if (flags is Map) {
          payload['flags'] = Map<String, dynamic>.from(flags);
        }

        if (payload['role'] == null && raw['role'] != null) {
          payload['role'] = raw['role'];
        }
        if (payload['role_id'] == null && raw['role_id'] != null) {
          payload['role_id'] = raw['role_id'];
        }
        if (payload['permissions'] == null && raw['permissions'] is List) {
          payload['permissions'] = List<dynamic>.from(
            raw['permissions'] as List,
          );
        }

        return payload;
      }
      if (raw['data'] is Map) {
        return Map<String, dynamic>.from(raw['data'] as Map);
      }
      return raw;
    }
    return null;
  }

  static Future<void> _storeRoleSnapshot(
    SharedPreferences prefs,
    dynamic raw,
    Map<String, dynamic>? payload,
  ) async {
    String? role;
    int? roleId;

    void readRole(dynamic value) {
      if (value is Map) {
        final name = value['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) role ??= name;
        roleId ??= int.tryParse(value['id']?.toString() ?? '');
        return;
      }

      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) role ??= text;
    }

    void readRoles(dynamic value) {
      if (value is! List || value.isEmpty) return;
      readRole(value.first);
    }

    if (raw is Map) {
      readRole(raw['role']);
      readRoles(raw['roles']);
      roleId ??= int.tryParse(raw['role_id']?.toString() ?? '');

      final user = raw['user'];
      if (user is Map) {
        readRole(user['role']);
        readRoles(user['roles']);
        roleId ??= int.tryParse(user['role_id']?.toString() ?? '');
      }
    }

    if (payload != null) {
      readRole(payload['role']);
      readRoles(payload['roles']);
      roleId ??= int.tryParse(payload['role_id']?.toString() ?? '');
    }

    if (role != null && role!.trim().isNotEmpty) {
      await prefs.setString(_roleKey, role!.trim());
    } else {
      await prefs.remove(_roleKey);
    }

    if (roleId != null && roleId! > 0) {
      await prefs.setInt(_roleIdKey, roleId!);
    } else {
      await prefs.remove(_roleIdKey);
    }
  }

  static String? _extractUserName(dynamic raw) {
    if (raw is! Map) return null;
    final candidates = <dynamic>[
      raw['name'],
      raw['nombre'],
      raw['full_name'],
      raw['display_name'],
    ];
    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static String? _extractUserEmail(dynamic raw) {
    if (raw is! Map) return null;
    final candidates = <dynamic>[raw['email'], raw['correo']];
    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static Future<void> _storeUserSnapshot(
    SharedPreferences prefs,
    Map<String, dynamic>? payload,
  ) async {
    if (payload == null || payload.isEmpty) {
      await prefs.remove(_userPayloadKey);
      await prefs.remove(_unidadIdKey);
      await prefs.remove(_delegacionIdKey);
      await prefs.remove(_destacamentoIdKey);
      return;
    }

    await prefs.setString(_userPayloadKey, jsonEncode(payload));

    await _storeNullableInt(prefs, _unidadIdKey, _extractUnidadId(payload));
    await _storeNullableInt(
      prefs,
      _delegacionIdKey,
      _extractDelegacionId(payload),
    );
    await _storeNullableInt(
      prefs,
      _destacamentoIdKey,
      _extractDestacamentoId(payload),
    );
  }

  static Future<void> _storeNullableInt(
    SharedPreferences prefs,
    String key,
    int? value,
  ) async {
    if (value != null && value > 0) {
      await prefs.setInt(key, value);
      return;
    }

    await prefs.remove(key);
  }

  static int? _extractUnidadId(Map<String, dynamic> payload) {
    return _readNullableInt(payload['unidad_id']) ??
        _readNullableInt(payload['unidad_org_id']) ??
        _readNestedId(payload['unidad_principal']) ??
        _readNestedId(payload['unidadPrincipal']) ??
        _readNestedId(payload['unidad']);
  }

  static bool _payloadMatchesVialidadesUrbanas(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) {
      return false;
    }

    final directId =
        _readNullableInt(payload['unidad_id']) ??
        _readNullableInt(payload['unidad_org_id']);
    if (directId == unidadVialidadesUrbanasId ||
        directId == unidadSeguridadVialId) {
      return true;
    }

    final candidates = <dynamic>[
      payload['unidad'],
      payload['unidad_principal'],
      payload['unidadPrincipal'],
      payload['unidad_nombre'],
      payload['unidadName'],
      payload['unidad_label'],
      payload['area'],
      payload['areas'],
      payload['unidades'],
    ];

    for (final candidate in candidates) {
      if (_dynamicContainsVialidadesUrbanas(candidate)) {
        return true;
      }
    }

    return false;
  }

  static bool _payloadMatchesSiniestros(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) {
      return false;
    }

    final directId =
        _readNullableInt(payload['unidad_id']) ??
        _readNullableInt(payload['unidad_org_id']);
    if (directId == 1) {
      return true;
    }

    final candidates = <dynamic>[
      payload['unidad'],
      payload['unidad_principal'],
      payload['unidadPrincipal'],
      payload['unidad_nombre'],
      payload['unidadName'],
      payload['unidad_label'],
      payload['area'],
      payload['areas'],
      payload['unidades'],
    ];

    for (final candidate in candidates) {
      if (_dynamicContainsSiniestros(candidate)) {
        return true;
      }
    }

    return false;
  }

  static bool _payloadMatchesVialidadesUrbanasStrict(
    Map<String, dynamic>? payload,
  ) {
    if (payload == null || payload.isEmpty) {
      return false;
    }

    final directId =
        _readNullableInt(payload['unidad_id']) ??
        _readNullableInt(payload['unidad_org_id']);
    if (directId == unidadVialidadesUrbanasId) {
      return true;
    }

    final candidates = <dynamic>[
      payload['unidad'],
      payload['unidad_principal'],
      payload['unidadPrincipal'],
      payload['unidad_nombre'],
      payload['unidadName'],
      payload['unidad_label'],
      payload['area'],
      payload['areas'],
      payload['unidades'],
    ];

    for (final candidate in candidates) {
      if (_dynamicContainsVialidadesUrbanas(candidate)) {
        return true;
      }
    }

    return false;
  }

  static bool _payloadMatchesDelegaciones(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) {
      return false;
    }

    final directId =
        _readNullableInt(payload['unidad_id']) ??
        _readNullableInt(payload['unidad_org_id']);
    if (directId == unidadDelegacionesId) {
      return true;
    }

    final candidates = <dynamic>[
      payload['unidad'],
      payload['unidad_principal'],
      payload['unidadPrincipal'],
      payload['unidad_nombre'],
      payload['unidadName'],
      payload['unidad_label'],
      payload['area'],
      payload['areas'],
      payload['unidades'],
    ];

    for (final candidate in candidates) {
      if (_dynamicContainsDelegaciones(candidate)) {
        return true;
      }
    }

    return false;
  }

  static bool _payloadMatchesHechosCreateExcludedUnit(
    Map<String, dynamic>? payload,
  ) {
    if (payload == null || payload.isEmpty) {
      return false;
    }

    final directId =
        _readNullableInt(payload['unidad_id']) ??
        _readNullableInt(payload['unidad_org_id']);
    if (_isHechosCreateExcludedUnitId(directId)) {
      return true;
    }

    final candidates = <dynamic>[
      payload['unidad'],
      payload['unidad_principal'],
      payload['unidadPrincipal'],
      payload['unidad_nombre'],
      payload['unidadName'],
      payload['unidad_label'],
      payload['area'],
      payload['areas'],
      payload['unidades'],
    ];

    for (final candidate in candidates) {
      if (_dynamicContainsHechosCreateExcludedUnit(candidate)) {
        return true;
      }
    }

    return false;
  }

  static bool _payloadMatchesHechosCaptureRelaxedUnit(
    Map<String, dynamic>? payload,
  ) {
    if (payload == null || payload.isEmpty) {
      return false;
    }

    final directId =
        _readNullableInt(payload['unidad_id']) ??
        _readNullableInt(payload['unidad_org_id']);
    if (_isHechosCaptureRelaxedUnitId(directId)) {
      return true;
    }

    final candidates = <dynamic>[
      payload['unidad'],
      payload['unidad_principal'],
      payload['unidadPrincipal'],
      payload['unidad_nombre'],
      payload['unidadName'],
      payload['unidad_label'],
      payload['area'],
      payload['areas'],
      payload['unidades'],
    ];

    for (final candidate in candidates) {
      if (_dynamicContainsHechosCaptureRelaxedUnit(candidate)) {
        return true;
      }
    }

    return false;
  }

  static Future<List<String>> _filterHechosPermissionsForCurrentUser(
    List<String> permissions, {
    Map<String, dynamic>? userPayload,
  }) async {
    final normalized = permissions
        .map((p) => p.trim().toLowerCase())
        .where((p) => p.isNotEmpty)
        .toSet();

    final payload = userPayload ?? await getStoredUserPayload();
    if (await isSuperadmin() || _payloadHasRole(payload, 'superadmin')) {
      return normalized.toList();
    }

    final unidadId = await getUnidadId();
    final isPeritoUser = await isPerito() || _payloadHasRole(payload, 'perito');
    final excludeHechos =
        !isPeritoUser &&
        (_isHechosCreateExcludedUnitId(unidadId) ||
            _payloadMatchesHechosCreateExcludedUnit(payload));

    const hiddenHechos = <String>{
      'ver busqueda',
      'ver hechos',
      'crear hechos',
      'editar hechos',
      'eliminar hechos',
      'ver vehiculos',
      'crear vehiculos',
      'editar vehiculos',
      'eliminar vehiculos',
      'ver lesionados',
      'crear lesionados',
      'editar lesionados',
      'eliminar lesionados',
    };

    const hiddenCarreteras = <String>{
      'ver operativos carreteras',
      'crear operativos carreteras',
      'editar operativos carreteras',
      'eliminar operativos carreteras',
      'ver estadisticas carreteras',
    };

    const hiddenVialidades = <String>{
      'ver operativos vialidades',
      'crear operativos vialidades',
      'editar operativos vialidades',
      'eliminar operativos vialidades',
    };

    if (excludeHechos) {
      normalized.removeWhere(hiddenHechos.contains);
    }

    final hasImplicitHechosAccess =
        unidadId == 1 ||
        _payloadMatchesSiniestros(payload) ||
        isPeritoUser ||
        _payloadHasRole(payload, 'jefe de grupo') ||
        _payloadFlagIsTrue(payload, 'is_jefe_grupo');
    if (hasImplicitHechosAccess) {
      normalized.add('ver hechos');
    }

    if (isPeritoUser) {
      normalized.add('crear hechos');
    }

    final canUseCarreteras =
        unidadId == unidadProteccionCarreterasId ||
        unidadId == unidadSeguridadVialId ||
        _payloadMatchesCarreteras(payload);
    if (!canUseCarreteras) {
      normalized.removeWhere(hiddenCarreteras.contains);
    }

    final canUseVialidades =
        unidadId == unidadVialidadesUrbanasId ||
        unidadId == unidadSeguridadVialId ||
        _payloadMatchesVialidadesUrbanas(payload);
    if (!canUseVialidades) {
      normalized.removeWhere(hiddenVialidades.contains);
    }

    return normalized.toList();
  }

  static bool _sameStringSet(List<String> a, List<String> b) {
    final aa = a.map((e) => e.trim().toLowerCase()).toSet();
    final bb = b.map((e) => e.trim().toLowerCase()).toSet();

    if (aa.length != bb.length) return false;
    for (final value in aa) {
      if (!bb.contains(value)) return false;
    }
    return true;
  }

  static bool _payloadHasRole(Map<String, dynamic>? payload, String roleName) {
    if (payload == null || payload.isEmpty) {
      return false;
    }

    return _dynamicContainsRole(payload['role'], roleName) ||
        _dynamicContainsRole(payload['roles'], roleName);
  }

  static bool _payloadHasExactRole(
    Map<String, dynamic>? payload,
    String roleName,
  ) {
    if (payload == null || payload.isEmpty) {
      return false;
    }

    return _dynamicContainsExactRole(payload['role'], roleName) ||
        _dynamicContainsExactRole(payload['roles'], roleName);
  }

  static bool _payloadHasAnyUnitId(
    Map<String, dynamic>? payload,
    Set<int> unitIds,
  ) {
    if (payload == null || payload.isEmpty || unitIds.isEmpty) {
      return false;
    }

    final directId =
        _readNullableInt(payload['unidad_id']) ??
        _readNullableInt(payload['unidad_org_id']);
    if (directId != null && unitIds.contains(directId)) {
      return true;
    }

    final candidates = <dynamic>[
      payload['unidad'],
      payload['unidad_principal'],
      payload['unidadPrincipal'],
      payload['unidades'],
      payload['areas'],
    ];

    for (final candidate in candidates) {
      if (_dynamicContainsAnyUnitId(candidate, unitIds)) {
        return true;
      }
    }

    return false;
  }

  static bool _dynamicContainsAnyUnitId(dynamic raw, Set<int> unitIds) {
    if (raw == null || unitIds.isEmpty) {
      return false;
    }

    final id = _readNullableInt(raw);
    if (id != null && unitIds.contains(id)) {
      return true;
    }

    if (raw is Map) {
      final nestedId = _readNullableInt(
        raw['id'] ??
            raw['value'] ??
            raw['unidad_id'] ??
            raw['unidad_org_id'] ??
            raw['unit_id'],
      );
      if (nestedId != null && unitIds.contains(nestedId)) {
        return true;
      }

      for (final value in raw.values) {
        if (_dynamicContainsAnyUnitId(value, unitIds)) {
          return true;
        }
      }

      return false;
    }

    if (raw is Iterable) {
      for (final item in raw) {
        if (_dynamicContainsAnyUnitId(item, unitIds)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _dynamicContainsExactRole(dynamic raw, String roleName) {
    if (raw == null) {
      return false;
    }

    if (raw is String) {
      return _roleTextEquals(raw, roleName);
    }

    if (raw is Map) {
      final values = <dynamic>[
        raw['name'],
        raw['nombre'],
        raw['slug'],
        raw['label'],
      ];

      for (final value in values) {
        if (_dynamicContainsExactRole(value, roleName)) {
          return true;
        }
      }

      return false;
    }

    if (raw is Iterable) {
      for (final item in raw) {
        if (_dynamicContainsExactRole(item, roleName)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _dynamicContainsRole(dynamic raw, String roleName) {
    final target = _normalizeUnitText(roleName).trim();
    if (raw == null || target.isEmpty) {
      return false;
    }

    if (raw is String) {
      return _roleTextMatches(raw, target);
    }

    if (raw is Map) {
      final values = <dynamic>[
        raw['name'],
        raw['nombre'],
        raw['slug'],
        raw['label'],
      ];

      for (final value in values) {
        if (_dynamicContainsRole(value, roleName)) {
          return true;
        }
      }

      return false;
    }

    if (raw is Iterable) {
      for (final item in raw) {
        if (_dynamicContainsRole(item, roleName)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _payloadFlagIsTrue(Map<String, dynamic>? payload, String key) {
    if (payload == null || payload.isEmpty || key.trim().isEmpty) {
      return false;
    }

    final flags = payload['flags'];
    if (flags is Map && _rawFlagIsTrue(flags[key])) {
      return true;
    }

    return _rawFlagIsTrue(payload[key]);
  }

  static bool _rawFlagIsTrue(dynamic value) {
    if (value is bool) {
      return value;
    }

    final number = int.tryParse(value?.toString().trim() ?? '');
    if (number != null) {
      return number > 0;
    }

    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == 'yes' || text == 'si' || text == 'sí';
  }

  static bool _roleTextMatches(String? raw, String roleName) {
    final text = _normalizeUnitText(raw ?? '').trim();
    final target = _normalizeUnitText(roleName).trim();
    if (text.isEmpty || target.isEmpty) {
      return false;
    }

    final looseText = _looseRoleText(text);
    final looseTarget = _looseRoleText(target);

    return text == target ||
        text.contains(target) ||
        looseText == looseTarget ||
        looseText.contains(looseTarget);
  }

  static bool _roleTextEquals(String? raw, String roleName) {
    final text = _normalizedRoleText(raw ?? '');
    final target = _normalizedRoleText(roleName);
    return text.isNotEmpty && target.isNotEmpty && text == target;
  }

  static String _normalizedRoleText(String raw) {
    return _normalizeUnitText(raw).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _looseRoleText(String raw) {
    return raw
        .replaceAll(RegExp(r'\bDE\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _dynamicContainsSiniestros(dynamic raw) {
    if (raw == null) {
      return false;
    }

    final id = _readNullableInt(raw);
    if (id == 1) {
      return true;
    }

    if (raw is String) {
      final normalized = _normalizeUnitText(raw);
      return normalized.contains('SINIESTROS');
    }

    if (raw is Map) {
      final nestedId = _readNullableInt(
        raw['id'] ?? raw['value'] ?? raw['unidad_id'] ?? raw['unidad_org_id'],
      );
      if (nestedId == 1) {
        return true;
      }

      final names = <dynamic>[
        raw['name'],
        raw['nombre'],
        raw['label'],
        raw['descripcion'],
        raw['title'],
        raw['slug'],
      ];

      for (final value in names) {
        if (_dynamicContainsSiniestros(value)) {
          return true;
        }
      }

      return false;
    }

    if (raw is Iterable) {
      for (final item in raw) {
        if (_dynamicContainsSiniestros(item)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _dynamicContainsDelegaciones(dynamic raw) {
    if (raw == null) {
      return false;
    }

    final id = _readNullableInt(raw);
    if (id == unidadDelegacionesId) {
      return true;
    }

    if (raw is String) {
      final normalized = _normalizeUnitText(raw);
      return normalized.contains('DELEGACIONES');
    }

    if (raw is Map) {
      final unitId = _readNullableInt(
        raw['unidad_id'] ?? raw['unidad_org_id'] ?? raw['unit_id'],
      );
      if (unitId == unidadDelegacionesId) {
        return true;
      }

      final nestedId = _readNullableInt(
        raw['id'] ?? raw['value'] ?? raw['unidad_id'] ?? raw['unidad_org_id'],
      );
      if (nestedId == unidadDelegacionesId) {
        return true;
      }

      final names = <dynamic>[
        raw['name'],
        raw['nombre'],
        raw['label'],
        raw['descripcion'],
        raw['title'],
        raw['slug'],
      ];

      for (final value in names) {
        if (_dynamicContainsDelegaciones(value)) {
          return true;
        }
      }

      return false;
    }

    if (raw is Iterable) {
      for (final item in raw) {
        if (_dynamicContainsDelegaciones(item)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _dynamicContainsVialidadesUrbanas(dynamic raw) {
    if (raw == null) {
      return false;
    }

    final id = _readNullableInt(raw);
    if (id == unidadVialidadesUrbanasId) {
      return true;
    }

    if (raw is String) {
      final normalized = _normalizeUnitText(raw);
      return normalized.contains('VIALIDADES URBANAS') ||
          normalized.contains('PROTECCION A VIALIDADES URBANAS') ||
          normalized.contains('PROTECCION EN VIALIDADES URBANAS');
    }

    if (raw is Map) {
      final id = _readNullableInt(
        raw['id'] ?? raw['value'] ?? raw['unidad_id'],
      );
      if (id == unidadVialidadesUrbanasId) {
        return true;
      }

      final names = <dynamic>[
        raw['name'],
        raw['nombre'],
        raw['label'],
        raw['descripcion'],
        raw['title'],
      ];

      for (final value in names) {
        if (_dynamicContainsVialidadesUrbanas(value)) {
          return true;
        }
      }

      return false;
    }

    if (raw is Iterable) {
      for (final item in raw) {
        if (_dynamicContainsVialidadesUrbanas(item)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _payloadMatchesCarreteras(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) {
      return false;
    }

    final directId =
        _readNullableInt(payload['unidad_id']) ??
        _readNullableInt(payload['unidad_org_id']);
    if (directId == unidadProteccionCarreterasId ||
        directId == unidadSeguridadVialId) {
      return true;
    }

    final candidates = <dynamic>[
      payload['unidad'],
      payload['unidad_principal'],
      payload['unidadPrincipal'],
      payload['unidad_nombre'],
      payload['unidadName'],
      payload['unidad_label'],
      payload['area'],
      payload['areas'],
      payload['unidades'],
    ];

    for (final candidate in candidates) {
      if (_dynamicContainsCarreteras(candidate)) {
        return true;
      }
    }

    return false;
  }

  static bool _payloadMatchesCarreterasStrict(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) {
      return false;
    }

    final directId =
        _readNullableInt(payload['unidad_id']) ??
        _readNullableInt(payload['unidad_org_id']);
    if (directId == unidadProteccionCarreterasId) {
      return true;
    }

    final candidates = <dynamic>[
      payload['unidad'],
      payload['unidad_principal'],
      payload['unidadPrincipal'],
      payload['unidad_nombre'],
      payload['unidadName'],
      payload['unidad_label'],
      payload['area'],
      payload['areas'],
      payload['unidades'],
    ];

    for (final candidate in candidates) {
      if (_dynamicContainsCarreteras(candidate)) {
        return true;
      }
    }

    return false;
  }

  static bool _dynamicContainsCarreteras(dynamic raw) {
    if (raw == null) {
      return false;
    }

    final id = _readNullableInt(raw);
    if (id == unidadProteccionCarreterasId) {
      return true;
    }

    if (raw is String) {
      final normalized = _normalizeUnitText(raw);
      return normalized.contains('PROTECCION A CARRETERAS') ||
          normalized.contains('PROTECCION EN CARRETERAS') ||
          normalized == 'CARRETERAS';
    }

    if (raw is Map) {
      final nestedId = _readNullableInt(
        raw['id'] ?? raw['value'] ?? raw['unidad_id'] ?? raw['unidad_org_id'],
      );
      if (nestedId == unidadProteccionCarreterasId) {
        return true;
      }

      final names = <dynamic>[
        raw['name'],
        raw['nombre'],
        raw['label'],
        raw['descripcion'],
        raw['title'],
        raw['slug'],
      ];

      for (final value in names) {
        if (_dynamicContainsCarreteras(value)) {
          return true;
        }
      }

      return false;
    }

    if (raw is Iterable) {
      for (final item in raw) {
        if (_dynamicContainsCarreteras(item)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _dynamicContainsHechosCreateExcludedUnit(dynamic raw) {
    if (raw == null) {
      return false;
    }

    if (_isHechosCreateExcludedUnitId(_readNullableInt(raw))) {
      return true;
    }

    if (raw is String) {
      final normalized = _normalizeUnitText(raw);
      return normalized.contains('VIALIDADES URBANAS') ||
          normalized.contains('PROTECCION A VIALIDADES URBANAS') ||
          normalized.contains('PROTECCION EN VIALIDADES URBANAS') ||
          normalized.contains('PROTECCION A CARRETERAS') ||
          normalized.contains('PROTECCION EN CARRETERAS') ||
          normalized == 'CARRETERAS' ||
          normalized.contains('FOMENTO A LA CULTURA VIAL') ||
          normalized.contains('CULTURA VIAL');
    }

    if (raw is Map) {
      final id = _readNullableInt(
        raw['id'] ?? raw['value'] ?? raw['unidad_id'] ?? raw['unidad_org_id'],
      );
      if (_isHechosCreateExcludedUnitId(id)) {
        return true;
      }

      final names = <dynamic>[
        raw['name'],
        raw['nombre'],
        raw['label'],
        raw['descripcion'],
        raw['title'],
        raw['slug'],
      ];

      for (final value in names) {
        if (_dynamicContainsHechosCreateExcludedUnit(value)) {
          return true;
        }
      }

      return false;
    }

    if (raw is Iterable) {
      for (final item in raw) {
        if (_dynamicContainsHechosCreateExcludedUnit(item)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _dynamicContainsHechosCaptureRelaxedUnit(dynamic raw) {
    if (raw == null) {
      return false;
    }

    if (_isHechosCaptureRelaxedUnitId(_readNullableInt(raw))) {
      return true;
    }

    if (raw is String) {
      final normalized = _normalizeUnitText(raw);
      return normalized.contains('DELEGACIONES');
    }

    if (raw is Map) {
      final unitId = _readNullableInt(
        raw['unidad_id'] ?? raw['unidad_org_id'] ?? raw['unit_id'],
      );
      if (_isHechosCaptureRelaxedUnitId(unitId)) {
        return true;
      }

      final id = _readNullableInt(
        raw['id'] ?? raw['value'] ?? raw['unidad_id'] ?? raw['unidad_org_id'],
      );
      if (_isHechosCaptureRelaxedUnitId(id)) {
        return true;
      }

      final names = <dynamic>[
        raw['name'],
        raw['nombre'],
        raw['label'],
        raw['descripcion'],
        raw['title'],
        raw['slug'],
      ];

      for (final value in names) {
        if (_dynamicContainsHechosCaptureRelaxedUnit(value)) {
          return true;
        }
      }

      return false;
    }

    if (raw is Iterable) {
      for (final item in raw) {
        if (_dynamicContainsHechosCaptureRelaxedUnit(item)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _isHechosCaptureRelaxedUnitId(int? unidadId) {
    return unidadId == unidadDelegacionesId;
  }

  static bool _isHechosCreateExcludedUnitId(int? unidadId) {
    return unidadId == unidadProteccionCarreterasId ||
        unidadId == unidadVialidadesUrbanasId ||
        unidadId == unidadCulturaVialId;
  }

  static String _normalizeUnitText(String raw) {
    return raw
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N');
  }

  static int? _extractDelegacionId(Map<String, dynamic> payload) {
    return _readNullableInt(payload['delegacion_id']) ??
        _readNestedId(payload['delegacion']);
  }

  static int? _extractDestacamentoId(Map<String, dynamic> payload) {
    return _readNullableInt(payload['destacamento_id']) ??
        _readNestedId(payload['destacamento']);
  }

  static int? _readNestedId(dynamic raw) {
    if (raw is Map) {
      return _readNullableInt(raw['id'] ?? raw['value']);
    }

    return _readNullableInt(raw);
  }

  static int? _readNullableInt(dynamic value) {
    final parsed = int.tryParse('${value ?? ''}');
    return parsed != null && parsed > 0 ? parsed : null;
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
