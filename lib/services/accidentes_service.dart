import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

int _seguimientoReadInt(dynamic value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? fallback;
}

bool _seguimientoReadBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = (value ?? '').toString().trim().toLowerCase();
  return s == '1' || s == 'true' || s == 'si' || s == 'sí' || s == 'yes';
}

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

class SeguimientoHechosMeta {
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;

  const SeguimientoHechosMeta({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory SeguimientoHechosMeta.fromJson(dynamic raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    return SeguimientoHechosMeta(
      currentPage: _seguimientoReadInt(map['current_page'], fallback: 1),
      perPage: _seguimientoReadInt(map['per_page'], fallback: 20),
      total: _seguimientoReadInt(map['total'], fallback: 0),
      lastPage: _seguimientoReadInt(map['last_page'], fallback: 1),
    );
  }
}

class SeguimientoHechosFilters {
  final String periodo;
  final String situacion;
  final String unidadFiltro;
  final bool puedeFiltrarUnidad;
  final Map<String, String> unidadesFiltro;

  const SeguimientoHechosFilters({
    required this.periodo,
    required this.situacion,
    required this.unidadFiltro,
    required this.puedeFiltrarUnidad,
    required this.unidadesFiltro,
  });

  factory SeguimientoHechosFilters.fromJson(dynamic raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final unidadesRaw = map['unidades_filtro'];
    final unidades = <String, String>{};

    if (unidadesRaw is Map) {
      unidadesRaw.forEach((key, value) {
        final k = key.toString().trim();
        final v = (value ?? '').toString().trim();
        if (k.isNotEmpty && v.isNotEmpty) {
          unidades[k] = v;
        }
      });
    }

    return SeguimientoHechosFilters(
      periodo: ((map['periodo'] ?? 'SEMANA').toString()).toUpperCase(),
      situacion: ((map['situacion'] ?? 'PENDIENTE').toString()).toUpperCase(),
      unidadFiltro: (map['unidad_filtro'] ?? '').toString(),
      puedeFiltrarUnidad: _seguimientoReadBool(map['puede_filtrar_unidad']),
      unidadesFiltro: unidades,
    );
  }
}

class SeguimientoHechosResponse {
  final List<Map<String, dynamic>> hechos;
  final Map<String, Map<String, int>> conteos;
  final SeguimientoHechosFilters filters;
  final SeguimientoHechosMeta meta;

  const SeguimientoHechosResponse({
    required this.hechos,
    required this.conteos,
    required this.filters,
    required this.meta,
  });

  factory SeguimientoHechosResponse.fromJson(Map<String, dynamic> raw) {
    final dataRaw = raw['data'];
    final hechos = dataRaw is List
        ? dataRaw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    return SeguimientoHechosResponse(
      hechos: hechos,
      conteos: _parseConteos(raw['conteos']),
      filters: SeguimientoHechosFilters.fromJson(raw['filters']),
      meta: SeguimientoHechosMeta.fromJson(raw['meta']),
    );
  }

  static Map<String, Map<String, int>> _parseConteos(dynamic raw) {
    final out = <String, Map<String, int>>{
      'semana': <String, int>{},
      'mes': <String, int>{},
      'anio': <String, int>{},
    };

    if (raw is! Map) return out;

    raw.forEach((periodoKey, values) {
      final key = periodoKey.toString().trim().toLowerCase();
      if (key.isEmpty || values is! Map) return;

      final mapped = <String, int>{};
      values.forEach((estadoKey, value) {
        final estado = estadoKey.toString().trim().toUpperCase();
        if (estado.isNotEmpty) {
          mapped[estado] = _seguimientoReadInt(value, fallback: 0);
        }
      });
      out[key] = mapped;
    });

    return out;
  }
}

class AccidentesService {
  static Future<List<Map<String, dynamic>>> fetchHechos({
    required String fecha,
    int perPage = 100,
    int? unidadOrgId,
    int? delegacionId,
  }) async {
    final token = await AuthService.getToken();

    final uri = Uri.parse('${AuthService.baseUrl}/hechos').replace(
      queryParameters: {
        'per_page': '$perPage',
        'fecha': fecha,
        if (unidadOrgId != null && unidadOrgId > 0)
          'unidad_org_id': '$unidadOrgId',
        if (delegacionId != null && delegacionId > 0)
          'delegacion_id': '$delegacionId',
      },
    );

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

  static Future<SeguimientoHechosResponse> fetchSeguimientoHechos({
    String periodo = 'SEMANA',
    String situacion = 'PENDIENTE',
    String unidadFiltro = '',
    int page = 1,
    int perPage = 20,
  }) async {
    final token = await AuthService.getToken();

    final query = <String, String>{
      'periodo': periodo,
      'situacion': situacion,
      'page': '$page',
      'per_page': '$perPage',
    };

    if (unidadFiltro.trim().isNotEmpty) {
      query['unidad_filtro'] = unidadFiltro.trim();
    }

    final uri = Uri.parse(
      '${AuthService.baseUrl}/hechos/seguimiento',
    ).replace(queryParameters: query);

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
    if (raw is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del servidor.');
    }

    return SeguimientoHechosResponse.fromJson(raw);
  }

  static Future<List<Map<String, dynamic>>> fetchDelegacionesCatalogo() async {
    final token = await AuthService.getToken();

    final uri = Uri.parse(
      '${AuthService.baseUrl}/estadisticas-actividades/catalogos/delegaciones',
    );

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
    final data = raw is List
        ? raw
        : raw is Map<String, dynamic> && raw['data'] is List
        ? raw['data'] as List<dynamic>
        : const <dynamic>[];

    return data
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

  static Future<void> deleteHecho({required int hechoId}) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    final uri = Uri.parse('${AuthService.baseUrl}/hechos/$hechoId');

    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final resp = await http.delete(uri, headers: headers);

    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }
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
