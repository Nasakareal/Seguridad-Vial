import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/croquis_element.dart';
import 'auth_service.dart';
import 'hechos_form_service.dart';

class CroquisPayload {
  const CroquisPayload({
    required this.exists,
    required this.elementos,
    this.raw,
  });

  final bool exists;
  final List<CroquisElement> elementos;
  final Map<String, dynamic>? raw;
}

class CroquisService {
  static Uri _uri(int hechoId) {
    return Uri.parse('${AuthService.baseUrl}/hechos/$hechoId/croquis');
  }

  static Future<Map<String, String>> _headers({bool form = false}) async {
    final token = await AuthService.getToken();
    return <String, String>{
      'Accept': 'application/json',
      if (!form) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<CroquisPayload> fetch(int hechoId) async {
    final response = await http
        .get(_uri(hechoId), headers: await _headers())
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 404) {
      return const CroquisPayload(exists: false, elementos: <CroquisElement>[]);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_parseError(response));
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final body = response.body.trim();

    if (contentType.contains('text/html') ||
        body.toLowerCase().contains('<!doctype html') ||
        body.toLowerCase().contains('<html')) {
      final fromHtml = _extractInitialDataFromHtml(body);
      return CroquisPayload(
        exists: fromHtml.isNotEmpty,
        elementos: fromHtml,
        raw: const <String, dynamic>{'source': 'html'},
      );
    }

    try {
      final raw = jsonDecode(body);
      final croquis = _extractCroquisMap(raw);
      final dibujo = croquis?['json_dibujo'] ?? _extractDibujo(raw);
      final elementos = CroquisModels.deserialize(dibujo);
      return CroquisPayload(
        exists: croquis != null || elementos.isNotEmpty,
        elementos: elementos,
        raw: croquis,
      );
    } catch (_) {
      throw Exception('El servidor no devolvió un croquis válido.');
    }
  }

  static Future<void> save({
    required int hechoId,
    required List<CroquisElement> elementos,
    required String previewDataUrl,
  }) async {
    final response = await http
        .post(
          _uri(hechoId),
          headers: await _headers(form: true),
          body: <String, String>{
            'titulo': 'Croquis del hecho #$hechoId',
            'json_dibujo': CroquisElement.serialize(elementos),
            'imagen_preview': previewDataUrl,
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode >= 200 && response.statusCode < 400) {
      return;
    }

    throw Exception(_parseError(response));
  }

  static Future<void> delete(int hechoId) async {
    final response = await http
        .delete(_uri(hechoId), headers: await _headers())
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 404 ||
        response.statusCode == 204 ||
        (response.statusCode >= 200 && response.statusCode < 400)) {
      return;
    }

    throw Exception(_parseError(response));
  }

  static Map<String, dynamic>? _extractCroquisMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final candidates = <dynamic>[
        raw['croquis'],
        raw['data'],
        raw['item'],
        raw,
      ];

      for (final candidate in candidates) {
        if (candidate is Map && candidate.containsKey('json_dibujo')) {
          return Map<String, dynamic>.from(candidate);
        }
      }
    }

    return null;
  }

  static dynamic _extractDibujo(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map<String, dynamic>) {
      return raw['json_dibujo'] ??
          raw['dibujo'] ??
          raw['elementos'] ??
          raw['elements'];
    }
    return null;
  }

  static List<CroquisElement> _extractInitialDataFromHtml(String html) {
    final marker = html.indexOf('initialData:');
    if (marker < 0) return <CroquisElement>[];

    final start = html.indexOf('[', marker);
    if (start < 0) return <CroquisElement>[];

    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var i = start; i < html.length; i += 1) {
      final char = html[i];

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }

      if (char == '"') {
        inString = true;
        continue;
      }

      if (char == '[') {
        depth += 1;
      } else if (char == ']') {
        depth -= 1;
        if (depth == 0) {
          final json = html.substring(start, i + 1);
          return CroquisModels.deserialize(json);
        }
      }
    }

    return <CroquisElement>[];
  }

  static String _parseError(http.Response response) {
    final parsed = HechosFormService.parseBackendError(
      response.body,
      response.statusCode,
    );

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final looksHtml =
        contentType.contains('text/html') ||
        response.body.toLowerCase().contains('<html');

    if (looksHtml) {
      return '$parsed El servidor devolvió HTML en lugar de JSON.';
    }

    return parsed;
  }
}
