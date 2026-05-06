import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/municipios_michoacan.dart';
import '../models/actividad.dart';
import '../models/actividad_categoria.dart';
import '../models/actividad_subcategoria.dart';
import 'auth_service.dart';
import 'delegacion_distance_service.dart';
import 'offline_sync_service.dart';
import 'photo_orientation_service.dart';
import 'vehiculo_form_service.dart';

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
    add('municipio', MunicipiosMichoacan.canonical(municipio) ?? municipio);
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
  static const int _maxImageBytes = 4 * 1024 * 1024;
  static const int suspiciousReachedCount = 1000;
  static const int suspiciousParticipantsCount = 5;
  static const int suspiciousDetainedCount = 3;
  static const int maxDetainedCount = 3;

  static String _subcategoriasCacheKey(int categoriaId) =>
      'actividades_subcategorias_cache_v1_$categoriaId';

  static List<String> peopleCountWarnings(ActividadUpsertData data) {
    final warnings = <String>[];

    final participantes = int.tryParse(
      (data.personasParticipantes ?? '').trim(),
    );
    if (participantes == 0) {
      warnings.add(
        'Personas participantes está en 0. Revisa si realmente no participó nadie.',
      );
    }

    void warnHigh(String label, String? raw, int threshold, String reason) {
      final value = int.tryParse((raw ?? '').trim());
      if (value == null || value < threshold) return;
      warnings.add('$label tiene $value. $reason');
    }

    warnHigh(
      'Personas alcanzadas',
      data.personasAlcanzadas,
      suspiciousReachedCount,
      'Es una cantidad muy alta; revisa si fue captura accidental.',
    );
    warnHigh(
      'Personas participantes',
      data.personasParticipantes,
      suspiciousParticipantsCount,
      'Ya suena a operativo o dispositivo; confirma que sí corresponde a esta actividad.',
    );
    warnHigh(
      'Personas detenidas',
      data.personasDetenidas,
      suspiciousDetainedCount,
      'Ya suena a operativo o dispositivo; confirma que sí corresponde a esta actividad.',
    );

    return warnings;
  }

  static bool shouldRedirectC5iReportToHecho({
    required String categoriaNombre,
    required String subcategoriaNombre,
  }) {
    final categoria = _normalizeCatalogLabel(categoriaNombre);
    final subcategoria = _normalizeCatalogLabel(subcategoriaNombre);

    final isC5iReport =
        categoria.contains('REPORTE') &&
        (categoria.contains('C5I') || categoria.contains('C5'));
    final isHechoOrSiniestro =
        subcategoria.contains('HECHO DE TRANSITO') ||
        subcategoria.contains('HECHOS DE TRANSITO') ||
        subcategoria.contains('SINIESTRO');

    return isC5iReport && isHechoOrSiniestro;
  }

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

  static String _normalizeCatalogLabel(String value) {
    const accents = <String, String>{
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'Ü': 'U',
      'Ñ': 'N',
    };

    final upper = value.trim().toUpperCase();
    final buffer = StringBuffer();
    for (final char in upper.split('')) {
      buffer.write(accents[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
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

  static String cleanExceptionMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'Ocurrió un error inesperado.';
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }

  static Future<String?> validateBeforeSubmit({
    required ActividadUpsertData data,
    required List<File> fotos,
    bool requirePhotos = true,
    bool requireCoords = true,
  }) async {
    final errors = <String>[];

    void add(String message) {
      if (!errors.contains(message)) errors.add(message);
    }

    if (data.actividadCategoriaId <= 0) {
      add('Selecciona una categoría.');
    }
    if (data.actividadSubcategoriaId == null ||
        data.actividadSubcategoriaId! <= 0) {
      add('Selecciona una subcategoría.');
    }

    final fecha = (data.fecha ?? '').trim();
    if (fecha.isEmpty) {
      add('Captura la fecha.');
    } else if (DateTime.tryParse(fecha) == null) {
      add('La fecha debe tener formato AAAA-MM-DD.');
    }

    final hora = (data.hora ?? '').trim();
    if (hora.isNotEmpty &&
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(hora)) {
      add('La hora debe tener formato HH:mm.');
    }

    _validateLength(errors, data.lugar, 255, 'Lugar');
    _validateLength(errors, data.municipio, 255, 'Municipio');
    _validateMunicipio(errors, data.municipio);
    _validateLength(errors, data.carretera, 255, 'Carretera');
    _validateLength(errors, data.tramo, 255, 'Tramo');
    _validateLength(errors, data.kilometro, 50, 'Kilómetro');
    _validateLength(errors, data.fuenteUbicacion, 50, 'Fuente de ubicación');
    _validateLength(errors, data.notaGeo, 255, 'Nota de ubicación');

    final latText = (data.lat ?? '').trim();
    final lngText = (data.lng ?? '').trim();
    if (requireCoords && (latText.isEmpty || lngText.isEmpty)) {
      add('Captura la ubicación con el botón "Usar mi ubicación".');
    } else if (latText.isNotEmpty || lngText.isNotEmpty) {
      final lat = double.tryParse(latText);
      final lng = double.tryParse(lngText);
      if (lat == null || lat < -90 || lat > 90) {
        add('La latitud de la ubicación no es válida.');
      }
      if (lng == null || lng < -180 || lng > 180) {
        add('La longitud de la ubicación no es válida.');
      }
    }

    _validateNonNegativeInt(
      errors,
      data.personasAlcanzadas,
      'Personas alcanzadas',
      min: 1,
    );
    _validateNonNegativeInt(
      errors,
      data.personasParticipantes,
      'Personas participantes',
    );
    _validateNonNegativeInt(
      errors,
      data.personasDetenidas,
      'Personas detenidas',
      max: maxDetainedCount,
    );

    if (requirePhotos && fotos.isEmpty) {
      add('Selecciona al menos una foto.');
    }

    final seenPaths = <String>{};
    for (var i = 0; i < fotos.length; i += 1) {
      final file = fotos[i];
      final label = 'Foto ${i + 1}';
      final path = file.path.trim();
      if (path.isEmpty) {
        add('$label no tiene una ruta válida.');
        continue;
      }
      if (!seenPaths.add(path)) {
        add('$label está duplicada en la misma captura.');
      }
      if (!await file.exists()) {
        add('$label ya no existe en el dispositivo.');
        continue;
      }

      final ext = path.split('.').last.toLowerCase();
      const allowed = <String>{'jpg', 'jpeg', 'png', 'webp'};
      if (!allowed.contains(ext)) {
        add('$label debe ser JPG, JPEG, PNG o WEBP.');
      }

      final size = await file.length();
      if (size > _maxImageBytes) {
        add('$label es muy pesada (máximo 4 MB).');
      }
    }

    for (var i = 0; i < data.vehiculos.length; i += 1) {
      _validateVehiculo(errors, data.vehiculos[i], i + 1);
    }

    if (errors.isEmpty) return null;
    return 'Corrige esto antes de guardar:\n• ${errors.join('\n• ')}';
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
    final fields = data.toFields();
    await _addKilometrosRecorridos(fields, lat: data.lat, lng: data.lng);
    fields['client_uuid'] = clientUuid;
    final landscapeFotos = await PhotoOrientationService.forceLandscapeAll(
      fotos,
    );
    final uploads = <OfflineUploadFile>[
      for (final foto in landscapeFotos)
        OfflineUploadFile(field: 'fotos[]', path: foto.path),
    ];

    final result = await OfflineSyncService.submitMultipart(
      label: 'Actividad',
      method: 'POST',
      uri: Uri.parse(_base),
      fields: fields,
      files: uploads,
      requestId: clientUuid,
      successCodes: const <int>{200, 201},
      errorParser: _parseBackendError,
    );
    await DelegacionDistanceService.markCaptureSubmitted(
      lat: double.tryParse(data.lat?.trim() ?? ''),
      lng: double.tryParse(data.lng?.trim() ?? ''),
    );
    return result;
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
    final fields = data.toFields();
    fields['_method'] = 'PUT';
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

  static Future<void> _addKilometrosRecorridos(
    Map<String, String> fields, {
    required String? lat,
    required String? lng,
  }) async {
    final km = await DelegacionDistanceService.distanceForNextCaptureKmField(
      lat: double.tryParse(lat?.trim() ?? ''),
      lng: double.tryParse(lng?.trim() ?? ''),
    );
    if (km == null) return;

    fields[DelegacionDistanceService.kilometrosRecorridosField] = km;
  }

  static void _validateLength(
    List<String> errors,
    String? value,
    int max,
    String label,
  ) {
    final text = (value ?? '').trim();
    if (text.length > max) {
      errors.add('$label no puede exceder $max caracteres.');
    }
  }

  static void _validateMunicipio(List<String> errors, String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      errors.add('Selecciona un municipio de Michoacan.');
      return;
    }
    if (!MunicipiosMichoacan.isKnown(text)) {
      errors.add('Selecciona un municipio de Michoacan.');
    }
  }

  static void _validateNonNegativeInt(
    List<String> errors,
    String? value,
    String label, {
    int min = 0,
    int? max,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      if (min > 0) {
        errors.add('$label debe ser al menos $min.');
      }
      return;
    }

    final parsed = int.tryParse(text);
    if (parsed == null) {
      errors.add('$label debe ser un número entero.');
      return;
    }
    if (parsed < min) {
      errors.add(
        min <= 0
            ? '$label no puede ser negativo.'
            : '$label debe ser al menos $min.',
      );
    }
    if (max != null && parsed > max) {
      errors.add('$label no puede ser mayor a $max.');
    }
  }

  static void _validateVehiculo(
    List<String> errors,
    ActividadVehiculo vehiculo,
    int index,
  ) {
    final prefix = 'Vehículo $index';

    void requiredText(String? value, String label, int max) {
      final text = (value ?? '').trim();
      if (text.isEmpty) {
        errors.add('$prefix: captura $label.');
      } else if (text.length > max) {
        errors.add('$prefix: $label no puede exceder $max caracteres.');
      }
    }

    void optionalText(String? value, String label, int max) {
      final text = (value ?? '').trim();
      if (text.length > max) {
        errors.add('$prefix: $label no puede exceder $max caracteres.');
      }
    }

    requiredText(vehiculo.marca, 'marca', 50);
    optionalText(vehiculo.modelo, 'modelo', 10);
    requiredText(vehiculo.tipo, 'tipo', 50);
    requiredText(vehiculo.linea, 'línea', 50);
    requiredText(vehiculo.color, 'color', 30);
    optionalText(vehiculo.placas, 'placas', 15);
    optionalText(vehiculo.estadoPlacas, 'estado de placas', 15);
    optionalText(vehiculo.serie, 'serie', 17);
    final tipoServicioError = VehiculoFormService.validateTipoServicioPlaca(
      vehiculo.tipoServicio,
    );
    if (tipoServicioError != null) {
      errors.add('$prefix: $tipoServicioError');
    }
    optionalText(
      vehiculo.tarjetaCirculacionNombre,
      'nombre de tarjeta de circulación',
      60,
    );
    optionalText(vehiculo.grua, 'grúa', 255);
    optionalText(vehiculo.corralon, 'corralón', 255);
    optionalText(vehiculo.aseguradora, 'aseguradora', 100);

    if (vehiculo.capacidadPersonas < 0) {
      errors.add('$prefix: capacidad de personas no puede ser negativa.');
    }
    if (vehiculo.montoDanos != null && vehiculo.montoDanos! < 0) {
      errors.add('$prefix: monto de daños no puede ser negativo.');
    }
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
