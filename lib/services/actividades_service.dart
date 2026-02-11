import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/actividad.dart';
import '../models/actividad_categoria.dart';
import '../models/actividad_subcategoria.dart';
import 'auth_service.dart';

class ActividadesService {
  static String get _base => '${AuthService.baseUrl}/actividades';

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

  static Future<Map<String, String>> _headersAuthOnly() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
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
    // Controller: { ok, date, per_page, data: paginator }
    // paginator: { data: [...], current_page, last_page, ... }
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

    return const [];
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

  /// ✅ NUEVO: categorías según tus rutas:
  /// GET /api/actividades/categorias
  static Future<List<ActividadCategoria>> fetchCategorias() async {
    final headers = await _headersJson();

    final uri = Uri.parse('$_base/categorias');
    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);

    if (raw is Map<String, dynamic> && raw['data'] is List) {
      final list = raw['data'] as List;
      return list
          .whereType<Map>()
          .map((e) => ActividadCategoria.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return const [];
  }

  /// GET /api/actividades/subcategorias/{categoria}
  static Future<List<ActividadSubcategoria>> fetchSubcategorias(
    int categoriaId,
  ) async {
    final headers = await _headersJson();
    final uri = Uri.parse('$_base/subcategorias/$categoriaId');

    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);

    if (raw is Map<String, dynamic> && raw['data'] is List) {
      final list = raw['data'] as List;
      return list
          .whereType<Map>()
          .map(
            (e) => ActividadSubcategoria.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    }

    return const [];
  }

  static Future<Actividad> create({
    required int actividadCategoriaId,
    int? actividadSubcategoriaId,
    required File foto,
  }) async {
    final headers = await _headersAuthOnly();

    final uri = Uri.parse(_base);
    final req = http.MultipartRequest('POST', uri);

    req.headers.addAll(headers);
    req.fields['actividad_categoria_id'] = actividadCategoriaId.toString();

    if (actividadSubcategoriaId != null && actividadSubcategoriaId > 0) {
      req.fields['actividad_subcategoria_id'] = actividadSubcategoriaId
          .toString();
    }

    req.files.add(await http.MultipartFile.fromPath('foto', foto.path));

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);

    if (raw is Map<String, dynamic> && raw['data'] is Map) {
      return Actividad.fromJson(Map<String, dynamic>.from(raw['data']));
    }

    throw Exception('Respuesta inválida del servidor.');
  }

  static Future<Actividad> update({
    required int id,
    required int actividadCategoriaId,
    int? actividadSubcategoriaId,
    File? foto,
  }) async {
    final headers = await _headersAuthOnly();

    final uri = Uri.parse('$_base/$id');
    final req = http.MultipartRequest('POST', uri);

    // Laravel: PUT con multipart => POST + _method=PUT
    req.headers.addAll(headers);
    req.fields['_method'] = 'PUT';
    req.fields['actividad_categoria_id'] = actividadCategoriaId.toString();

    if (actividadSubcategoriaId != null && actividadSubcategoriaId > 0) {
      req.fields['actividad_subcategoria_id'] = actividadSubcategoriaId
          .toString();
    }

    if (foto != null) {
      req.files.add(await http.MultipartFile.fromPath('foto', foto.path));
    }

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);

    if (raw is Map<String, dynamic> && raw['data'] is Map) {
      return Actividad.fromJson(Map<String, dynamic>.from(raw['data']));
    }

    throw Exception('Respuesta inválida del servidor.');
  }

  static Future<void> destroy(int id) async {
    final headers = await _headersJson();
    final uri = Uri.parse('$_base/$id');

    final resp = await http.delete(uri, headers: headers);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }
  }
}
