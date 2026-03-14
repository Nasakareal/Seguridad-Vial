import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/actividad.dart';
import '../models/actividad_categoria.dart';
import '../models/actividad_subcategoria.dart';
import 'auth_service.dart';
import 'offline_sync_service.dart';

class ActividadesService {
  static String get _base => '${AuthService.baseUrl}/actividades';
  static const String _categoriasCacheKey = 'actividades_categorias_cache_v1';

  static String _subcategoriasCacheKey(int categoriaId) =>
      'actividades_subcategorias_cache_v1_$categoriaId';

  static String toPublicUrl(String pathOrUrl) {
    final p = pathOrUrl.trim();
    if (p.isEmpty) return '';

    final lower = p.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return p;

    final root = AuthService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

    if (p.startsWith('/storage/')) return '$root$p';
    if (p.startsWith('storage/')) return '$root/$p';

    return '$root/storage/$p';
  }

  static Future<Map<String, String>> _headersJson() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String _parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);

      if (raw is Map<String, dynamic>) {
        if (raw['message'] is String) {
          final msg = (raw['message'] as String).trim();
          if (msg.isNotEmpty) return msg;
        }

        final errors = raw['errors'];
        if (errors is Map) {
          final sb = StringBuffer();
          errors.forEach((_, v) {
            if (v is List && v.isNotEmpty) {
              sb.writeln('• ${v.first}');
            }
          });
          final out = sb.toString().trim();
          if (out.isNotEmpty) return out;
        }
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }

  static List<Actividad> _decodeActividadesList(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];

      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is List) {
          return inner
              .whereType<Map>()
              .map((e) => Actividad.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }

      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Actividad.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Actividad.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return const <Actividad>[];
  }

  static Future<List<Actividad>> fetchIndex({
    required DateTime date,
    int perPage = 50,
    int? actividadCategoriaId,
    int? actividadSubcategoriaId,
    String? q,
  }) async {
    final headers = await _headersJson();

    final qp = <String, String>{
      'per_page': perPage.clamp(1, 50).toString(),
      'date': _fmtYmd(date),
    };

    if (actividadCategoriaId != null && actividadCategoriaId > 0) {
      qp['actividad_categoria_id'] = actividadCategoriaId.toString();
    }
    if (actividadSubcategoriaId != null && actividadSubcategoriaId > 0) {
      qp['actividad_subcategoria_id'] = actividadSubcategoriaId.toString();
    }
    if (q != null && q.trim().isNotEmpty) {
      qp['q'] = q.trim();
    }

    final uri = Uri.parse(_base).replace(queryParameters: qp);
    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    return _decodeActividadesList(raw);
  }

  static Future<Actividad> fetchShow(int id) async {
    final headers = await _headersJson();
    final uri = Uri.parse('$_base/$id');

    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);

    if (raw is Map<String, dynamic> && raw['data'] is Map) {
      return Actividad.fromJson(Map<String, dynamic>.from(raw['data']));
    }

    if (raw is Map<String, dynamic>) {
      return Actividad.fromJson(raw);
    }

    throw Exception('Respuesta inválida del servidor.');
  }

  static Future<List<ActividadCategoria>> fetchCategorias() async {
    try {
      final headers = await _headersJson();
      final uri = Uri.parse('$_base/categorias');
      final resp = await http.get(uri, headers: headers);

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(_parseBackendError(resp.body, resp.statusCode));
      }

      final raw = jsonDecode(resp.body);
      final list = _extractListFromResponse(raw);
      await _saveCache(_categoriasCacheKey, list);

      return list
          .map((e) => ActividadCategoria.fromJson(e))
          .where((e) => e.id > 0)
          .toList();
    } catch (e) {
      final cached = await _loadCache(_categoriasCacheKey);
      if (cached.isNotEmpty) {
        return cached
            .map((e) => ActividadCategoria.fromJson(e))
            .where((e) => e.id > 0)
            .toList();
      }
      rethrow;
    }
  }

  static Future<List<ActividadSubcategoria>> fetchSubcategorias(
    int categoriaId,
  ) async {
    final cacheKey = _subcategoriasCacheKey(categoriaId);

    try {
      final headers = await _headersJson();
      final uri = Uri.parse('$_base/subcategorias/$categoriaId');
      final resp = await http.get(uri, headers: headers);

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(_parseBackendError(resp.body, resp.statusCode));
      }

      final raw = jsonDecode(resp.body);
      final list = _extractListFromResponse(raw);
      await _saveCache(cacheKey, list);

      return list
          .map((e) => ActividadSubcategoria.fromJson(e))
          .where((e) => e.id > 0)
          .toList();
    } catch (e) {
      final cached = await _loadCache(cacheKey);
      if (cached.isNotEmpty) {
        return cached
            .map((e) => ActividadSubcategoria.fromJson(e))
            .where((e) => e.id > 0)
            .toList();
      }
      rethrow;
    }
  }

  static Future<OfflineActionResult> create({
    required int actividadCategoriaId,
    int? actividadSubcategoriaId,
    required File foto,
  }) async {
    return OfflineSyncService.submitMultipart(
      label: 'Actividad',
      method: 'POST',
      uri: Uri.parse(_base),
      fields: <String, String>{
        'actividad_categoria_id': actividadCategoriaId.toString(),
        if (actividadSubcategoriaId != null && actividadSubcategoriaId > 0)
          'actividad_subcategoria_id': actividadSubcategoriaId.toString(),
      },
      files: <OfflineUploadFile>[
        OfflineUploadFile(field: 'foto', path: foto.path),
      ],
      successCodes: const <int>{200, 201},
      errorParser: _parseBackendError,
    );
  }

  static Future<OfflineActionResult> update({
    required int id,
    required int actividadCategoriaId,
    int? actividadSubcategoriaId,
    File? foto,
  }) async {
    return OfflineSyncService.submitMultipart(
      label: 'Actividad',
      method: 'POST',
      uri: Uri.parse('$_base/$id'),
      fields: <String, String>{
        '_method': 'PUT',
        'actividad_categoria_id': actividadCategoriaId.toString(),
        if (actividadSubcategoriaId != null && actividadSubcategoriaId > 0)
          'actividad_subcategoria_id': actividadSubcategoriaId.toString(),
      },
      files: <OfflineUploadFile>[
        if (foto != null) OfflineUploadFile(field: 'foto', path: foto.path),
      ],
      successCodes: const <int>{200},
      errorParser: _parseBackendError,
    );
  }

  static Future<void> destroy(int id) async {
    final headers = await _headersJson();
    final uri = Uri.parse('$_base/$id');

    final resp = await http.delete(uri, headers: headers);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }
  }

  static String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static List<Map<String, dynamic>> _extractListFromResponse(dynamic raw) {
    if (raw is Map<String, dynamic> && raw['data'] is List) {
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return const <Map<String, dynamic>>[];
  }

  static Future<void> _saveCache(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items));
  }

  static Future<List<Map<String, dynamic>>> _loadCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty)
      return const <Map<String, dynamic>>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }
}
