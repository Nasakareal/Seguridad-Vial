import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/guardianes_camino_dispositivo.dart';
import 'auth_service.dart';

class GuardianesCaminoDispositivosService {
  static String get _base =>
      '${AuthService.baseUrl}/guardianes-camino/dispositivos';

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
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              final first = value.first.toString().trim();
              if (first.isNotEmpty) return first;
            }
          }
        }
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }

  static List<Map<String, dynamic>> _extractList(dynamic raw, String key) {
    if (raw is Map<String, dynamic> && raw[key] is List) {
      return (raw[key] as List)
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

  static String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static Future<GuardianesCaminoDispositivosIndexResult> fetchIndex({
    required DateTime fecha,
    int perPage = 50,
  }) async {
    final headers = await _headersJson();
    final qp = <String, String>{
      'per_page': perPage.clamp(1, 100).toString(),
      'fecha': _fmtYmd(fecha),
    };

    final uri = Uri.parse(_base).replace(queryParameters: qp);
    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    final items = _extractList(
      raw,
      'data',
    ).map(GuardianesCaminoDispositivo.fromJson).toList();

    final meta = raw is Map<String, dynamic> && raw['meta'] is Map
        ? Map<String, dynamic>.from(raw['meta'] as Map)
        : const <String, dynamic>{};

    int asInt(dynamic value) => int.tryParse('${value ?? ''}') ?? 0;

    return GuardianesCaminoDispositivosIndexResult(
      items: items,
      currentPage: asInt(meta['current_page']),
      lastPage: asInt(meta['last_page']),
      total: asInt(meta['total']),
    );
  }
}
