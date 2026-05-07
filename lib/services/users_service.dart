import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class UserCatalogItem {
  final int id;
  final String nombre;
  final int? unidadId;
  final int? turnoId;
  final int? unidadEfectivaId;
  final String? unidadEfectivaNombre;
  final bool activa;

  const UserCatalogItem({
    required this.id,
    required this.nombre,
    this.unidadId,
    this.turnoId,
    this.unidadEfectivaId,
    this.unidadEfectivaNombre,
    this.activa = true,
  });

  factory UserCatalogItem.fromJson(Map<String, dynamic> json) {
    return UserCatalogItem(
      id: _readInt(json['id']) ?? 0,
      nombre: _readText(
        json['nombre'] ??
            json['name'] ??
            json['numero_economico'] ??
            json['label'],
      ),
      unidadId: _readInt(json['unidad_id']),
      turnoId: _readInt(json['turno_id']),
      unidadEfectivaId: _readInt(json['unidad_efectiva_id']),
      unidadEfectivaNombre: _nullableText(json['unidad_efectiva_nombre']),
      activa: _readBool(json['activa'], fallback: true),
    );
  }

  String get roleScopedLabel {
    final scope = (unidadEfectivaNombre ?? '').trim();
    return '$nombre (${scope.isEmpty ? 'Global' : scope})';
  }
}

class UsersMeta {
  final List<UserCatalogItem> roles;
  final List<UserCatalogItem> unidades;
  final List<UserCatalogItem> turnos;
  final List<UserCatalogItem> patrullas;
  final List<UserCatalogItem> delegaciones;
  final List<UserCatalogItem> destacamentos;

  const UsersMeta({
    required this.roles,
    required this.unidades,
    required this.turnos,
    required this.patrullas,
    required this.delegaciones,
    required this.destacamentos,
  });

  const UsersMeta.empty()
    : roles = const <UserCatalogItem>[],
      unidades = const <UserCatalogItem>[],
      turnos = const <UserCatalogItem>[],
      patrullas = const <UserCatalogItem>[],
      delegaciones = const <UserCatalogItem>[],
      destacamentos = const <UserCatalogItem>[];

  factory UsersMeta.fromJson(Map<String, dynamic> json) {
    return UsersMeta(
      roles: _list(json['roles']),
      unidades: _list(json['unidades']),
      turnos: _list(json['turnos']),
      patrullas: _list(json['patrullas']),
      delegaciones: _list(json['delegaciones']),
      destacamentos: _list(json['destacamentos']),
    );
  }

  static List<UserCatalogItem> _list(dynamic raw) {
    if (raw is! List) return const <UserCatalogItem>[];
    return raw
        .whereType<Map>()
        .map(
          (item) => UserCatalogItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.id > 0)
        .toList();
  }
}

class UsersPage {
  final List<Map<String, dynamic>> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const UsersPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}

class UsersService {
  static String get _base => '${AuthService.baseUrl}/settings/users';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sesion invalida. Vuelve a iniciar sesion.');
    }

    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<UsersPage> index({
    String? q,
    int page = 1,
    int perPage = 50,
  }) async {
    final uri = Uri.parse(_base).replace(
      queryParameters: <String, String>{
        'page': '$page',
        'per_page': '$perPage',
        if ((q ?? '').trim().isNotEmpty) 'q': q!.trim(),
      },
    );

    final resp = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));

    final raw = _decodeMap(resp);
    final data = raw['data'];
    final items = data is List
        ? data
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final pagination = raw['pagination'] is Map
        ? Map<String, dynamic>.from(raw['pagination'] as Map)
        : <String, dynamic>{};

    return UsersPage(
      items: items,
      currentPage: _readInt(pagination['current_page']) ?? page,
      lastPage: _readInt(pagination['last_page']) ?? page,
      total: _readInt(pagination['total']) ?? items.length,
    );
  }

  static Future<UsersMeta> meta() async {
    final resp = await http
        .get(Uri.parse('$_base/meta'), headers: await _headers())
        .timeout(const Duration(seconds: 15));

    return UsersMeta.fromJson(_decodeMap(resp));
  }

  static Future<Map<String, dynamic>> show(int id) async {
    final resp = await http
        .get(Uri.parse('$_base/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 15));

    final raw = _decodeMap(resp);
    final data = raw['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return raw;
  }

  static Future<Map<String, dynamic>> store(
    Map<String, dynamic> payload,
  ) async {
    final resp = await http
        .post(
          Uri.parse(_base),
          headers: await _headers(),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    return _decodeMap(resp);
  }

  static Future<Map<String, dynamic>> update({
    required int id,
    required Map<String, dynamic> payload,
  }) async {
    final resp = await http
        .put(
          Uri.parse('$_base/$id'),
          headers: await _headers(),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    return _decodeMap(resp);
  }

  static String cleanExceptionMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Ocurrio un error inesperado.';
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  static String roleScopedLabel(dynamic raw, {String fallback = '-'}) {
    if (raw is! Map) return fallback;

    final role = _readText(raw['nombre'] ?? raw['name'], fallback: '');
    if (role.isEmpty) return fallback;

    final scope = _readText(
      raw['unidad_efectiva_nombre'] ??
          raw['unidad_nombre'] ??
          raw['scope_nombre'],
      fallback: '',
    );

    return '$role (${scope.isEmpty ? 'Global' : scope})';
  }

  static Map<String, dynamic> _decodeMap(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw Exception('Respuesta invalida del servidor.');
  }

  static String _parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map<String, dynamic>) {
        final errors = raw['errors'];
        if (errors is Map) {
          final messages = <String>[];
          errors.forEach((_, value) {
            if (value is List && value.isNotEmpty) {
              messages.add(value.first.toString());
            }
          });
          if (messages.isNotEmpty) return messages.join('\n');
        }

        final message = (raw['message'] ?? '').toString().trim();
        if (message.isNotEmpty) return message;
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _readText(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

bool _readBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text == '1' || text == 'true' || text == 'si' || text == 'sí') {
    return true;
  }
  if (text == '0' || text == 'false' || text == 'no') return false;
  return fallback;
}
