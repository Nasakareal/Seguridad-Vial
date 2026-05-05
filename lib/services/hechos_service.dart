import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../services/auth_service.dart';

class HechosService {
  static Future<Map<String, dynamic>> fetchById(int id) async {
    final token = await AuthService.getToken();

    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = Uri.parse('${AuthService.baseUrl}/hechos/$id');
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final raw = jsonDecode(res.body);

    if (raw is Map<String, dynamic> && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data']);
    }
    if (raw is Map<String, dynamic> && raw['hecho'] is Map) {
      return Map<String, dynamic>.from(raw['hecho']);
    }
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    return {};
  }

  static Future<Map<String, dynamic>> uploadIphDelegacion({
    required int hechoId,
    required File archivoPdf,
    String? nombrePolicia,
    String? nombreMp,
  }) async {
    final token = await AuthService.getToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AuthService.baseUrl}/hechos/$hechoId/iph-delegacion'),
    );

    request.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final policia = (nombrePolicia ?? '').trim();
    if (policia.isNotEmpty) request.fields['nombre_policia'] = policia;

    final mp = (nombreMp ?? '').trim();
    if (mp.isNotEmpty) request.fields['nombre_mp'] = mp;

    request.files.add(
      await http.MultipartFile.fromPath(
        'archivo_iph',
        archivoPdf.path,
        filename: p.basename(archivoPdf.path),
      ),
    );

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errorMessage(res));
    }

    final raw = jsonDecode(res.body);
    if (raw is Map<String, dynamic>) return raw;
    return <String, dynamic>{};
  }

  static String _errorMessage(http.Response res) {
    try {
      final raw = jsonDecode(res.body);
      if (raw is Map<String, dynamic>) {
        final errors = raw['errors'];
        if (errors is Map) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              return value.first.toString();
            }
          }
        }

        final message = raw['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {}

    return 'Error HTTP ${res.statusCode}';
  }
}
