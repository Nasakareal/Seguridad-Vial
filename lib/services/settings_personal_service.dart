import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class SettingsPersonalPage {
  final List<Map<String, dynamic>> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const SettingsPersonalPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}

class SettingsPersonalCatalogItem {
  final int id;
  final String nombre;

  const SettingsPersonalCatalogItem({required this.id, required this.nombre});

  factory SettingsPersonalCatalogItem.fromJson(Map<String, dynamic> json) {
    return SettingsPersonalCatalogItem(
      id: _readInt(json['id']) ?? 0,
      nombre: _readText(json['nombre'] ?? json['name'] ?? json['label']),
    );
  }
}

class SettingsPersonalMeta {
  final List<SettingsPersonalCatalogItem> unidades;

  const SettingsPersonalMeta({required this.unidades});

  const SettingsPersonalMeta.empty()
    : unidades = const <SettingsPersonalCatalogItem>[];

  factory SettingsPersonalMeta.fromJson(Map<String, dynamic> json) {
    final raw = json['unidades'];
    return SettingsPersonalMeta(
      unidades: raw is List
          ? raw
                .whereType<Map>()
                .map(
                  (item) => SettingsPersonalCatalogItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.id > 0)
                .toList()
          : const <SettingsPersonalCatalogItem>[],
    );
  }
}

class SettingsPersonalService {
  static const List<String> incidenciaTipos = <String>[
    'VACACIONES',
    'INCAPACIDAD',
    'PERMISO',
    'FALTA',
    'COMISION',
    'SUSPENSION',
    'OTRO',
  ];

  static String get _base => '${AuthService.baseUrl}/settings/personal';

  static String photoUrlFor(dynamic raw) {
    final path = _photoPathFrom(raw);
    return path == null ? '' : toPublicUrl(path);
  }

  static String toPublicUrl(String pathOrUrl) {
    final raw = pathOrUrl.trim();
    if (raw.isEmpty) return '';

    final lower = raw.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return raw;
    }

    final root = AuthService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final storageIndex = lower.indexOf('/storage/');
    if (storageIndex >= 0) return '$root${raw.substring(storageIndex)}';
    if (raw.startsWith('/storage/')) return '$root$raw';
    if (raw.startsWith('storage/')) return '$root/$raw';

    return '$root/storage/$raw';
  }

  static String? _photoPathFrom(dynamic raw) {
    if (raw is List) {
      for (final item in raw) {
        final value = _photoPathFrom(item);
        if (value != null) return value;
      }
      return null;
    }

    if (raw is! Map) return _nonEmptyText(raw);

    final map = Map<String, dynamic>.from(raw);
    for (final key in const <String>[
      'foto_url',
      'fotoUrl',
      'foto_path',
      'fotoPath',
      'foto',
      'fotografia_url',
      'fotografiaUrl',
      'fotografia_path',
      'fotografiaPath',
      'fotografia',
      'foto_personal_url',
      'fotoPersonalUrl',
      'foto_personal',
      'fotoPersonal',
      'foto_perfil_url',
      'fotoPerfilUrl',
      'foto_perfil',
      'fotoPerfil',
      'photo_url',
      'photoUrl',
      'photo_path',
      'photoPath',
      'photo',
      'image_url',
      'imageUrl',
      'imagen_url',
      'imagenUrl',
      'imagen',
      'avatar_url',
      'avatarUrl',
      'avatar',
      'profile_photo_url',
      'profilePhotoUrl',
      'profile_photo_path',
      'profilePhotoPath',
      'profile_photo',
      'profilePhoto',
      'url',
      'path',
      'ruta',
    ]) {
      final value = _photoPathFrom(map[key]);
      if (value != null) return value;
    }

    for (final key in const <String>['user', 'usuario', 'profile', 'perfil']) {
      final nested = map[key];
      if (nested is Map || nested is List) {
        final value = _photoPathFrom(nested);
        if (value != null) return value;
      }
    }

    return null;
  }

  static String? _nonEmptyText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

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

  static Future<SettingsPersonalPage> index({
    String? q,
    int? unidadId,
    int page = 1,
    int perPage = 50,
  }) async {
    final uri = Uri.parse(_base).replace(
      queryParameters: <String, String>{
        'page': '$page',
        'per_page': '$perPage',
        if ((q ?? '').trim().isNotEmpty) 'q': q!.trim(),
        if (unidadId != null && unidadId > 0) 'unidad_id': '$unidadId',
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

    return SettingsPersonalPage(
      items: items,
      currentPage: _readInt(pagination['current_page']) ?? page,
      lastPage: _readInt(pagination['last_page']) ?? page,
      total: _readInt(pagination['total']) ?? items.length,
    );
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

  static Future<SettingsPersonalMeta> meta() async {
    final resp = await http
        .get(Uri.parse('$_base/meta'), headers: await _headers())
        .timeout(const Duration(seconds: 15));

    return SettingsPersonalMeta.fromJson(_decodeMap(resp));
  }

  static Future<Map<String, dynamic>> storeIncidencia({
    required int personalId,
    required Map<String, dynamic> payload,
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_base/$personalId/incidencias'),
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
