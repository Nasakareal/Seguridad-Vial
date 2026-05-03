import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class EstadisticasActividadesService {
  EstadisticasActividadesService();

  static String get _base => AuthService.baseUrl;

  Future<Map<String, String>> _headersJson() async {
    final token = await AuthService.getToken();
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _headersDownload() async {
    final token = await AuthService.getToken();
    return <String, String>{
      'Accept': '*/*',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _u(String path, [Map<String, dynamic>? query]) {
    final qp = <String, String>{};

    if (query != null) {
      query.forEach((k, v) {
        if (v == null) return;
        final s = v.toString().trim();
        if (s.isEmpty) return;
        qp[k] = s;
      });
    }

    return Uri.parse(
      '$_base$path',
    ).replace(queryParameters: qp.isEmpty ? null : qp);
  }

  dynamic _decodeJson(http.Response res) {
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  Exception _err(http.Response res, [String? fallback]) {
    try {
      final data = _decodeJson(res);
      if (data is Map && data['message'] is String) {
        return Exception(data['message'] as String);
      }
    } catch (_) {}

    return Exception(fallback ?? 'Error HTTP ${res.statusCode}');
  }

  Future<Map<String, dynamic>> kpis({Map<String, dynamic>? params}) async {
    final uri = _u('/estadisticas-actividades/kpis', params);
    final res = await http.get(uri, headers: await _headersJson());
    if (res.statusCode != 200) {
      throw _err(res, 'No se pudieron cargar KPIs de actividades.');
    }

    final data = _decodeJson(res);
    return (data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> seriesActividades({
    Map<String, dynamic>? params,
  }) async {
    final uri = _u('/estadisticas-actividades/series/actividades', params);
    final res = await http.get(uri, headers: await _headersJson());
    if (res.statusCode != 200) {
      throw _err(res, 'No se pudo cargar la serie de actividades.');
    }

    final data = _decodeJson(res);
    return (data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> distribution(
    String endpoint, {
    Map<String, dynamic>? params,
  }) async {
    final uri = _u('/estadisticas-actividades/series/$endpoint', params);
    final res = await http.get(uri, headers: await _headersJson());
    if (res.statusCode != 200) {
      throw _err(res, 'No se pudo cargar distribución: $endpoint.');
    }

    final data = _decodeJson(res);
    return (data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> actividades({
    Map<String, dynamic>? params,
  }) async {
    final uri = _u('/estadisticas-actividades/actividades', params);
    final res = await http.get(uri, headers: await _headersJson());
    if (res.statusCode != 200) {
      throw _err(res, 'No se pudo cargar listado de actividades.');
    }

    final data = _decodeJson(res);
    return (data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> catalogoCategorias() async {
    final uri = _u('/estadisticas-actividades/catalogos/categorias');
    final res = await http.get(uri, headers: await _headersJson());
    if (res.statusCode != 200) {
      throw _err(res, 'No se pudieron cargar categorías.');
    }

    final data = _decodeJson(res);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> catalogoSubcategorias({
    int? actividadCategoriaId,
  }) async {
    final uri = _u('/estadisticas-actividades/catalogos/subcategorias', {
      if (actividadCategoriaId != null && actividadCategoriaId > 0)
        'actividad_categoria_id': actividadCategoriaId,
    });
    final res = await http.get(uri, headers: await _headersJson());
    if (res.statusCode != 200) {
      throw _err(res, 'No se pudieron cargar subcategorías.');
    }

    final data = _decodeJson(res);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> catalogoDelegaciones() async {
    final uri = _u('/estadisticas-actividades/catalogos/delegaciones');
    final res = await http.get(uri, headers: await _headersJson());
    if (res.statusCode != 200) {
      throw _err(res, 'No se pudieron cargar delegaciones.');
    }

    final data = _decodeJson(res);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return const <Map<String, dynamic>>[];
  }

  Future<Uint8List> exportActividades({Map<String, dynamic>? params}) async {
    final uri = _u('/estadisticas-actividades/export/actividades', params);
    final res = await http.get(uri, headers: await _headersDownload());
    if (res.statusCode != 200) {
      throw _err(res, 'No se pudo exportar actividades.');
    }

    return res.bodyBytes;
  }
}
