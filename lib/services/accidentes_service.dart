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

    final texto = ((source['texto'] ?? source['message'] ?? '').toString())
        .trim();
    final foto = ((source['foto'] ?? '').toString()).trim();

    final media = <String>[];

    final fotosRaw = source['fotos'];
    if (fotosRaw is List) {
      for (final item in fotosRaw) {
        final s = (item ?? '').toString().trim();
        if (s.isNotEmpty) {
          media.add(s);
        }
      }
    }

    final mediaRaw = source['media'];
    if (mediaRaw is List) {
      for (final item in mediaRaw) {
        final s = (item ?? '').toString().trim();
        if (s.isNotEmpty) {
          media.add(s);
        }
      }
    }

    if (media.isEmpty && foto.isNotEmpty) {
      media.add(foto);
    }

    final uniq = <String>{};
    final cleaned = <String>[];
    for (final item in media) {
      if (uniq.add(item)) {
        cleaned.add(item);
      }
    }

    final rawHechoId = source['hecho_id'] ?? raw['hecho_id'];

    return HechoNativeShareData(
      title: ((source['title'] ?? 'Hecho de tránsito').toString()).trim(),
      message: texto,
      media: cleaned,
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

    final uri = Uri.parse(
      '${AuthService.baseUrl}/hechos/$hechoId/native-share',
    );

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode != 200) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del servidor.');
    }

    return HechoNativeShareData.fromJson(raw);
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

    final uri = Uri.parse(
      '${AuthService.baseUrl}/hechos/$hechoId/whatsapp-link',
    );

    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode != 200) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is Map && raw['wa_url'] is String) {
      final url = (raw['wa_url'] as String).trim();
      if (url.isNotEmpty) {
        return Uri.parse(url);
      }
    }

    throw Exception('El servidor no devolvió el enlace de WhatsApp.');
  }

  static String _parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);

      if (raw is Map<String, dynamic>) {
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

        if (raw['message'] is String) {
          final msg = _friendlyKnownBackendMessage(raw['message'] as String);
          if (msg.isNotEmpty) return msg;
        }
      }
    } catch (_) {}

    final rawFriendly = _friendlyKnownBackendMessage(body);
    if (rawFriendly.isNotEmpty) return rawFriendly;

    return 'Error HTTP $statusCode';
  }

  static String _friendlyKnownBackendMessage(String rawMessage) {
    final msg = rawMessage.trim();
    if (msg.isEmpty) return '';

    final lower = msg.toLowerCase();
    if (lower.contains('hechos_folio_c5i_unique') ||
        (lower.contains('duplicate entry') && lower.contains('folio_c5i'))) {
      return 'Ese folio C5i ya está registrado. Usa uno diferente.';
    }

    return msg;
  }
}
