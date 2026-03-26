import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class HechoNativeShareData {
  final String title;
  final String message;
  final List<String> media;
  final int? hechoId;

  const HechoNativeShareData({
    required this.title,
    required this.message,
    required this.media,
    this.hechoId,
  });

  factory HechoNativeShareData.fromJson(Map<String, dynamic> raw) {
    final source = raw['data'] is Map
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : raw;

    final mediaRaw = source['media'];
    final media = mediaRaw is List
        ? mediaRaw
              .map((e) => (e ?? '').toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];

    final rawHechoId = source['hecho_id'] ?? raw['hecho_id'];

    return HechoNativeShareData(
      title: ((source['title'] ?? 'Hecho de tránsito').toString()).trim(),
      message: ((source['message'] ?? '').toString()).trim(),
      media: media,
      hechoId: int.tryParse('${rawHechoId ?? ''}'),
    );
  }
}

class AccidentesService {
  static Future<List<Map<String, dynamic>>> fetchHechos({
    required String fecha,
    int perPage = 100,
  }) async {
    final token = await AuthService.getToken();

    final uri = Uri.parse(
      '${AuthService.baseUrl}/hechos',
    ).replace(queryParameters: {'per_page': '$perPage', 'fecha': fecha});

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception(_parseBackendError(response.body, response.statusCode));
    }

    final raw = jsonDecode(response.body);
    List<dynamic> datos;

    if (raw is List) {
      datos = raw;
    } else if (raw is Map<String, dynamic> && raw['data'] is List) {
      datos = raw['data'] as List<dynamic>;
    } else if (raw is Map<String, dynamic> && raw['hechos'] is List) {
      datos = raw['hechos'] as List<dynamic>;
    } else {
      datos = [];
    }

    return datos
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<Uint8List> downloadReporteDoc({required int hechoId}) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    final uri = Uri.parse('${AuthService.baseUrl}/hechos/$hechoId/reporte-doc');

    final headers = <String, String>{
      'Accept': 'application/octet-stream',
      'Authorization': 'Bearer $token',
    };

    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode != 200) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    return resp.bodyBytes;
  }

  static Future<HechoNativeShareData> fetchNativeShareData({
    required int hechoId,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    http.Response? lastResponse;
    String? lastError;

    for (final path in [
      '/hechos/$hechoId/native-share',
      '/hechos/$hechoId/native_share',
      '/hechos/$hechoId/nativeShare',
    ]) {
      final uri = Uri.parse('${AuthService.baseUrl}$path');

      for (final method in ['GET', 'POST']) {
        final resp = method == 'GET'
            ? await http.get(uri, headers: headers)
            : await http.post(uri, headers: headers);

        lastResponse = resp;

        if (resp.statusCode == 200) {
          final raw = jsonDecode(resp.body);
          if (raw is! Map<String, dynamic>) {
            throw Exception('Respuesta inválida del servidor.');
          }
          return HechoNativeShareData.fromJson(raw);
        }

        if (resp.statusCode != 404 && resp.statusCode != 405) {
          lastError = _parseBackendError(resp.body, resp.statusCode);
        }
      }
    }

    throw Exception(
      lastError ??
          _parseBackendError(
            lastResponse?.body ?? '',
            lastResponse?.statusCode ?? 500,
          ),
    );
  }

  static Future<Uri> fetchWhatsappUri({required int hechoId}) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    http.Response? lastResponse;
    String? lastError;

    for (final path in ['/hechos/$hechoId/whatsapp']) {
      final uri = Uri.parse('${AuthService.baseUrl}$path');

      for (final method in ['GET', 'POST']) {
        final resp = method == 'GET'
            ? await http.get(uri, headers: headers)
            : await http.post(uri, headers: headers);

        lastResponse = resp;

        if (resp.statusCode == 200) {
          final raw = jsonDecode(resp.body);
          if (raw is Map && raw['wa_url'] is String) {
            final url = (raw['wa_url'] as String).trim();
            if (url.isNotEmpty) {
              return Uri.parse(url);
            }
          }
          throw Exception('El servidor no devolvió el enlace de WhatsApp.');
        }

        if (resp.statusCode != 404 && resp.statusCode != 405) {
          lastError = _parseBackendError(resp.body, resp.statusCode);
        }
      }
    }

    throw Exception(
      lastError ??
          _parseBackendError(
            lastResponse?.body ?? '',
            lastResponse?.statusCode ?? 500,
          ),
    );
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
}
