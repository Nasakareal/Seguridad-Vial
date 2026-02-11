import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class EstadisticasGlobalesService {
  EstadisticasGlobalesService();

  // ✅ TU BASE REAL (FIJA)
  static const String apiBase = 'https://seguridadvial-mich.com/api';

  // =========================
  // Helpers base
  // =========================
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

    // path viene como: /estadisticas-globales/kpis
    return Uri.parse(
      '$apiBase$path',
    ).replace(queryParameters: qp.isEmpty ? null : qp);
  }

  dynamic _decodeJson(http.Response res) {
    final body = res.body;
    if (body.isEmpty) return null;
    return jsonDecode(body);
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

  // =========================
  // Endpoints
  // =========================

  /// GET /estadisticas-globales/kpis
  Future<Map<String, dynamic>> kpis({Map<String, dynamic>? params}) async {
    final uri = _u('/estadisticas-globales/kpis', params);
    final res = await http.get(uri, headers: await _headersJson());
    if (res.statusCode != 200) {
      throw _err(res, 'No se pudieron cargar KPIs.');
    }
    final data = _decodeJson(res);
    return (data as Map).cast<String, dynamic>();
  }

  /// GET /estadisticas-globales/series/hechos
  Future<Map<String, dynamic>> seriesHechos({
    Map<String, dynamic>? params,
  }) async {
    final uri = _u('/estadisticas-globales/series/hechos', params);
    final res = await http.get(uri, headers: await _headersJson());
    if (res.statusCode != 200) {
      throw _err(res, 'No se pudo cargar serie de hechos.');
    }
    final data = _decodeJson(res);
    return (data as Map).cast<String, dynamic>();
  }

  /// GET /estadisticas-globales/series/lesionados
  Future<Map<String, dynamic>> seriesLesionados({
    Map<String, dynamic>? params,
  }) async {
    final uri = _u('/estadisticas-globales/series/lesionados', params);
    final res = await http.get(uri, headers: await _headersJson());
    if (res.statusCode != 200) {
      throw _err(res, 'No se pudo cargar serie de lesionados.');
    }
    final data = _decodeJson(res);
    return (data as Map).cast<String, dynamic>();
  }

  /// Distribuciones
  /// endpoint ejemplo: 'sector' -> /estadisticas-globales/series/sector
  Future<Map<String, dynamic>> distribution(
    String endpoint, {
    Map<String, dynamic>? params,
  }) async {
    final uri = _u('/estadisticas-globales/series/$endpoint', params);
    final res = await http.get(uri, headers: await _headersJson());
    if (res.statusCode != 200) {
      throw _err(res, 'No se pudo cargar distribución: $endpoint.');
    }
    final data = _decodeJson(res);
    return (data as Map).cast<String, dynamic>();
  }

  /// Drilldown hechos (paginado)
  /// GET /estadisticas-globales/hechos?per=25&page=1&...filtros
  Future<Map<String, dynamic>> hechos({Map<String, dynamic>? params}) async {
    final uri = _u('/estadisticas-globales/hechos', params);
    final res = await http.get(uri, headers: await _headersJson());
    if (res.statusCode != 200) {
      throw _err(res, 'No se pudo cargar listado de hechos.');
    }
    final data = _decodeJson(res);
    return (data as Map).cast<String, dynamic>();
  }

  /// Export hechos (CSV/Word/lo que expongas)
  /// GET /estadisticas-globales/export/hechos?...filtros
  Future<Uint8List> exportHechos({Map<String, dynamic>? params}) async {
    final uri = _u('/estadisticas-globales/export/hechos', params);
    final res = await http.get(uri, headers: await _headersDownload());
    if (res.statusCode != 200) {
      throw _err(res, 'No se pudo exportar.');
    }
    return res.bodyBytes;
  }

  /// Nombre de archivo desde Content-Disposition (sin regex problemática)
  String? filenameFromHeaders(Map<String, String> headers) {
    final cd = headers['content-disposition'] ?? headers['Content-Disposition'];
    if (cd == null || cd.trim().isEmpty) return null;

    // 1) filename*=UTF-8''archivo.ext
    final idxStar = cd.toLowerCase().indexOf('filename*=');
    if (idxStar >= 0) {
      final part = cd.substring(idxStar);
      final eq = part.indexOf('=');
      if (eq >= 0) {
        var v = part.substring(eq + 1).trim();
        final sem = v.indexOf(';');
        if (sem >= 0) v = v.substring(0, sem).trim();

        final p = v.indexOf("''");
        if (p >= 0) v = v.substring(p + 2);

        v = v.replaceAll('"', '').trim();
        if (v.isNotEmpty) return Uri.decodeFull(v);
      }
    }

    // 2) filename="archivo.ext"  o filename=archivo.ext
    final idx = cd.toLowerCase().indexOf('filename=');
    if (idx >= 0) {
      var v = cd.substring(idx + 'filename='.length).trim();
      final sem = v.indexOf(';');
      if (sem >= 0) v = v.substring(0, sem).trim();

      v = v.replaceAll('"', '').trim();
      if (v.isNotEmpty) return v;
    }

    return null;
  }
}
