import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/actividad.dart';
import '../models/actividad_categoria.dart';
import '../models/actividad_subcategoria.dart';
import 'auth_service.dart';
import 'offline_sync_service.dart';
import 'photo_orientation_service.dart';

class ActividadUpsertData {
  final String? clientUuid;
  final int actividadCategoriaId;
  final int? actividadSubcategoriaId;
  final String? fecha;
  final String? hora;
  final String? lugar;
  final String? municipio;
  final String? carretera;
  final String? tramo;
  final String? kilometro;
  final String? lat;
  final String? lng;
  final String? coordenadasTexto;
  final String? fuenteUbicacion;
  final String? notaGeo;
  final String? motivo;
  final String? narrativa;
  final String? accionesRealizadas;
  final String? observaciones;
  final String? personasAlcanzadas;
  final String? personasParticipantes;
  final String? personasDetenidas;
  final String? elementosParticipantesTexto;
  final String? patrullasParticipantesTexto;
  final String? destacamentoId;
  final List<ActividadVehiculo> vehiculos;

  const ActividadUpsertData({
    this.clientUuid,
    required this.actividadCategoriaId,
    this.actividadSubcategoriaId,
    this.fecha,
    this.hora,
    this.lugar,
    this.municipio,
    this.carretera,
    this.tramo,
    this.kilometro,
    this.lat,
    this.lng,
    this.coordenadasTexto,
    this.fuenteUbicacion,
    this.notaGeo,
    this.motivo,
    this.narrativa,
    this.accionesRealizadas,
    this.observaciones,
    this.personasAlcanzadas,
    this.personasParticipantes,
    this.personasDetenidas,
    this.elementosParticipantesTexto,
    this.patrullasParticipantesTexto,
    this.destacamentoId,
    this.vehiculos = const <ActividadVehiculo>[],
  });

  Map<String, String> toFields() {
    final fields = <String, String>{
      'actividad_categoria_id': actividadCategoriaId.toString(),
    };

    void add(String key, String? value) {
      if (value == null) return;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      fields[key] = trimmed;
    }

    if (actividadSubcategoriaId != null && actividadSubcategoriaId! > 0) {
      fields['actividad_subcategoria_id'] = actividadSubcategoriaId.toString();
    }

    add('client_uuid', clientUuid);
    add('fecha', fecha);
    add('hora', hora);
    add('lugar', lugar);
    add('municipio', municipio);
    add('lat', lat);
    add('lng', lng);
    add('coordenadas_texto', coordenadasTexto);
    add('fuente_ubicacion', fuenteUbicacion);
    add('nota_geo', notaGeo);
    add('motivo', motivo);
    add('narrativa', narrativa);
    add('acciones_realizadas', accionesRealizadas);
    add('observaciones', observaciones);
    add('personas_alcanzadas', personasAlcanzadas);
    add('personas_participantes', personasParticipantes);
    add('personas_detenidas', personasDetenidas);
    add('elementos_participantes_texto', elementosParticipantesTexto);
    add('patrullas_participantes_texto', patrullasParticipantesTexto);

    for (var index = 0; index < vehiculos.length; index += 1) {
      final vehiculo = vehiculos[index].toApiJson();
      vehiculo.forEach((key, value) {
        if (value == null) return;
        final text = value.toString().trim();
        if (text.isEmpty) return;
        fields['vehiculos[$index][$key]'] = text;
      });
    }

    return fields;
  }
}

class ActividadNativeShareData {
  final String message;
  final List<String> media;

  const ActividadNativeShareData({required this.message, required this.media});

  factory ActividadNativeShareData.fromJson(Map<String, dynamic> raw) {
    final source = raw['data'] is Map
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : raw;

    final texto = ((source['texto'] ?? source['message'] ?? '').toString())
        .trim();

    final media = <String>[];

    void addMedia(dynamic listLike) {
      if (listLike is! List) return;
      for (final item in listLike) {
        final s = (item ?? '').toString().trim();
        if (s.isNotEmpty && !media.contains(s)) {
          media.add(s);
        }
      }
    }

    addMedia(source['fotos']);
    addMedia(source['media']);

    return ActividadNativeShareData(message: texto, media: media);
  }
}

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
      throw Exception('Sesion invalida. Vuelve a iniciar sesion.');
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
          final msg = (raw['message'] as String).trim();
          if (msg.isNotEmpty) return msg;
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
    int perPage = 20,
    int? actividadCategoriaId,
    int? actividadSubcategoriaId,
    String? q,
  }) async {
    final headers = await _headersJson();

    final qp = <String, String>{
      'per_page': perPage.clamp(1, 20).toString(),
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

    throw Exception('Respuesta invalida del servidor.');
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

  static Future<ActividadNativeShareData> fetchShareData({
    required int actividadId,
  }) async {
    final headers = await _headersJson();
    final uri = Uri.parse('$_base/$actividadId/compartir');

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('Respuesta invalida del servidor.');
    }

    return ActividadNativeShareData.fromJson(raw);
  }

  static Future<ActividadNativeShareData> fetchShareTotalsData({
    required DateTime fecha,
  }) async {
    final headers = await _headersJson();
    final uri = Uri.parse(
      '$_base/compartir-totales-whatsapp',
    ).replace(queryParameters: {'fecha': _fmtYmd(fecha)});

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('Respuesta invalida del servidor.');
    }

    return ActividadNativeShareData.fromJson(raw);
  }

  static Future<OfflineActionResult> create({
    required ActividadUpsertData data,
    required List<File> fotos,
  }) async {
    final clientUuid = _ensureClientUuid(data.clientUuid);
    final fields = data.toFields()..['client_uuid'] = clientUuid;
    final landscapeFotos = await PhotoOrientationService.forceLandscapeAll(
      fotos,
    );
    final uploads = <OfflineUploadFile>[
      for (final foto in landscapeFotos)
        OfflineUploadFile(field: 'fotos[]', path: foto.path),
    ];

    return OfflineSyncService.submitMultipart(
      label: 'Actividad',
      method: 'POST',
      uri: Uri.parse(_base),
      fields: fields,
      files: uploads,
      requestId: clientUuid,
      successCodes: const <int>{200, 201},
      errorParser: _parseBackendError,
    );
  }

  static Future<Actividad> storeVehiculo({
    required int actividadId,
    required ActividadVehiculo vehiculo,
  }) async {
    final headers = await _headersJson();
    final uri = Uri.parse('$_base/$actividadId/vehiculos');
    final resp = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(vehiculo.toApiJson()),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    return _decodeActividadResponse(resp.body);
  }

  static Future<Actividad> destroyVehiculo({
    required int actividadId,
    required int vehiculoId,
  }) async {
    final headers = await _headersJson();
    final uri = Uri.parse('$_base/$actividadId/vehiculos/$vehiculoId');
    final resp = await http.delete(uri, headers: headers);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    return _decodeActividadResponse(resp.body);
  }

  static Future<OfflineActionResult> update({
    required int id,
    required ActividadUpsertData data,
    File? foto,
  }) async {
    final fields = data.toFields()..['_method'] = 'PUT';
    final landscapeFoto = foto == null
        ? null
        : await PhotoOrientationService.forceLandscape(foto);

    return OfflineSyncService.submitMultipart(
      label: 'Actividad',
      method: 'POST',
      uri: Uri.parse('$_base/$id'),
      fields: fields,
      files: <OfflineUploadFile>[
        if (landscapeFoto != null)
          OfflineUploadFile(field: 'foto', path: landscapeFoto.path),
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

  static String _ensureClientUuid(String? clientUuid) {
    final current = (clientUuid ?? '').trim();
    if (current.isNotEmpty) return current;
    return OfflineSyncService.newClientUuid();
  }

  static Actividad _decodeActividadResponse(String body) {
    final raw = jsonDecode(body);

    if (raw is Map<String, dynamic> && raw['data'] is Map) {
      return Actividad.fromJson(Map<String, dynamic>.from(raw['data']));
    }

    if (raw is Map<String, dynamic>) {
      return Actividad.fromJson(raw);
    }

    throw Exception('Respuesta invalida del servidor.');
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
    if (raw == null || raw.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }

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
