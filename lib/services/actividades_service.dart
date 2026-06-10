import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/municipios_michoacan.dart';
import '../models/actividad.dart';
import '../models/actividad_categoria.dart';
import '../models/actividad_fomento.dart';
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
  final ActividadFomentoDetalle? fomento;
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
    this.fomento,
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

    void addOptionalCount(String key, String? value) {
      final trimmed = (value ?? '').trim();
      fields[key] = trimmed.isEmpty ? '0' : trimmed;
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
    addOptionalCount('personas_detenidas', personasDetenidas);
    add('elementos_participantes_texto', elementosParticipantesTexto);
    add('patrullas_participantes_texto', patrullasParticipantesTexto);

    final fomentoData = fomento;
    if (fomentoData != null) {
      if (fomentoData.programaId != null && fomentoData.programaId! > 0) {
        fields['fomento[programa_id]'] = fomentoData.programaId.toString();
      }
      add('fomento[nivel_educativo]', fomentoData.nivelEducativo);
      add('fomento[sector]', fomentoData.sector);
      add('fomento[nombre_institucion]', fomentoData.escuela);
      add('fomento[escuela]', fomentoData.escuela);
      add('fomento[domicilio]', fomentoData.domicilio);
      for (final field in ActividadFomentoDetalle.numericFields) {
        fields['fomento[${field.key}]'] = fomentoData
            .valueFor(field.key)
            .clamp(0, ActividadFomentoDetalle.maxCount)
            .toString();
      }
      fields['fomento[total_poblacion_atendida]'] = fomentoData.computedTotal
          .clamp(0, ActividadFomentoDetalle.maxCount * 8)
          .toString();
    }

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

enum ActividadValidationTarget {
  categoria,
  subcategoria,
  fecha,
  hora,
  lugar,
  municipio,
  carretera,
  tramo,
  kilometro,
  ubicacion,
  fuenteUbicacion,
  notaGeo,
  personasAlcanzadas,
  personasParticipantes,
  personasDetenidas,
  fomento,
  fotos,
  vehiculos,
}

class ActividadValidationIssue {
  final ActividadValidationTarget target;
  final String message;

  const ActividadValidationIssue({required this.target, required this.message});
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

    return ActividadNativeShareData(
      message: texto,
      media: media,
    ).withHoraFallback(_readShareHora(source, raw));
  }

  bool get hasClockTimeInMessage => _hasClockTime(message);

  ActividadNativeShareData withMedia(Iterable<String> rawMedia) {
    final nextMedia = <String>[];
    for (final item in rawMedia) {
      final value = item.trim();
      if (value.isNotEmpty && !nextMedia.contains(value)) {
        nextMedia.add(value);
      }
    }

    if (nextMedia.isEmpty) return this;
    return ActividadNativeShareData(message: message, media: nextMedia);
  }

  ActividadNativeShareData withHoraFallback(String? rawHora) {
    final nextMessage = _appendHoraIfMissing(message, rawHora);
    if (nextMessage == message) return this;

    return ActividadNativeShareData(message: nextMessage, media: media);
  }

  static String? _readShareHora(
    Map<String, dynamic> source,
    Map<String, dynamic> raw,
  ) {
    String? readFromMap(Map<dynamic, dynamic>? map) {
      if (map == null) return null;

      for (final key in const <String>[
        'hora',
        'time',
        'hora_actividad',
        'actividad_hora',
      ]) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }

      for (final key in const <String>['actividad', 'activity']) {
        final nested = map[key];
        if (nested is Map) {
          final value = readFromMap(nested);
          if (value != null && value.trim().isNotEmpty) return value;
        }
      }

      return null;
    }

    return readFromMap(source) ?? readFromMap(raw);
  }

  static String _appendHoraIfMissing(String message, String? rawHora) {
    final text = message.trim();
    final hora = _formatShareHora(rawHora);
    if (hora.isEmpty) return text;
    if (_messageContainsHora(text, hora)) return text;

    if (text.isEmpty) return 'Hora: $hora';

    final lines = text.split(RegExp(r'\r?\n'));
    final fechaIndex = lines.indexWhere(
      (line) => line.toLowerCase().contains('fecha'),
    );

    if (fechaIndex >= 0) {
      lines.insert(fechaIndex + 1, 'Hora: $hora');
      return lines.join('\n').trim();
    }

    return '$text\nHora: $hora';
  }

  static String _formatShareHora(String? rawHora) {
    final text = (rawHora ?? '').trim();
    if (text.isEmpty) return '';

    final match = RegExp(r'(\d{1,2}):([0-5]\d)').firstMatch(text);
    if (match != null) {
      final hour = int.tryParse(match.group(1) ?? '');
      final minute = match.group(2);
      if (hour != null && hour >= 0 && hour <= 23 && minute != null) {
        return '${hour.toString().padLeft(2, '0')}:$minute';
      }
    }

    return text.length <= 8 ? text : '';
  }

  static bool _messageContainsHora(String message, String hora) {
    if (message.isEmpty) return false;
    if (message.contains(hora)) return true;

    final match = RegExp(r'^0?(\d{1,2}):([0-5]\d)$').firstMatch(hora);
    if (match != null) {
      final hour = int.tryParse(match.group(1) ?? '');
      final minute = match.group(2);
      if (hour != null && minute != null) {
        return message.contains('$hour:$minute');
      }
    }

    return false;
  }

  static bool _hasClockTime(String message) {
    final match = RegExp(r'(\d{1,2}):([0-5]\d)').firstMatch(message);
    if (match == null) return false;

    final hour = int.tryParse(match.group(1) ?? '');
    return hour != null && hour >= 0 && hour <= 23;
  }
}

class ActividadesService {
  static String get _base => '${AuthService.baseUrl}/actividades';
  static const String _categoriasCacheKey = 'actividades_categorias_cache_v1';
  static const int _maxImageBytes = 4 * 1024 * 1024;
  static const int suspiciousReachedCount = 1000;
  static const int suspiciousParticipantsCount = 5;
  static const int suspiciousDetainedCount = 3;
  static const int maxParticipantsCount = 15;
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
    bool userCanCaptureHechos = true,
  }) {
    if (!userCanCaptureHechos) return false;

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

  static String formatValidationIssues(
    Iterable<ActividadValidationIssue> issues,
  ) {
    final messages = <String>[];
    for (final issue in issues) {
      if (!messages.contains(issue.message)) messages.add(issue.message);
    }
    return 'Corrige esto antes de guardar:\n• ${messages.join('\n• ')}';
  }

  static Future<String?> validateBeforeSubmit({
    required ActividadUpsertData data,
    required List<File> fotos,
    bool requirePhotos = true,
    bool requireCoords = true,
    bool requireTimestamp = true,
  }) async {
    final issues = await validateBeforeSubmitIssues(
      data: data,
      fotos: fotos,
      requirePhotos: requirePhotos,
      requireCoords: requireCoords,
      requireTimestamp: requireTimestamp,
    );
    if (issues.isEmpty) return null;
    return formatValidationIssues(issues);
  }

  static Future<List<ActividadValidationIssue>> validateBeforeSubmitIssues({
    required ActividadUpsertData data,
    required List<File> fotos,
    bool requirePhotos = true,
    bool requireCoords = true,
    bool requireTimestamp = true,
  }) async {
    final issues = <ActividadValidationIssue>[];

    void add(ActividadValidationTarget target, String message) {
      if (issues.any((issue) => issue.message == message)) return;
      issues.add(ActividadValidationIssue(target: target, message: message));
    }

    if (data.actividadCategoriaId <= 0) {
      add(ActividadValidationTarget.categoria, 'Selecciona una categoría.');
    }
    if (data.actividadSubcategoriaId == null ||
        data.actividadSubcategoriaId! <= 0) {
      add(
        ActividadValidationTarget.subcategoria,
        'Selecciona una subcategoría.',
      );
    }

    final fecha = (data.fecha ?? '').trim();
    if (requireTimestamp && fecha.isEmpty) {
      add(ActividadValidationTarget.fecha, 'Captura la fecha.');
    } else if (fecha.isNotEmpty && DateTime.tryParse(fecha) == null) {
      add(
        ActividadValidationTarget.fecha,
        'La fecha debe tener formato AAAA-MM-DD.',
      );
    }

    final hora = (data.hora ?? '').trim();
    if (hora.isNotEmpty &&
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(hora)) {
      add(ActividadValidationTarget.hora, 'La hora debe tener formato HH:mm.');
    }

    _validateLength(
      issues,
      ActividadValidationTarget.lugar,
      data.lugar,
      255,
      'Lugar',
    );
    _validateLength(
      issues,
      ActividadValidationTarget.municipio,
      data.municipio,
      255,
      'Municipio',
    );
    _validateMunicipio(issues, data.municipio);
    _validateLength(
      issues,
      ActividadValidationTarget.carretera,
      data.carretera,
      255,
      'Carretera',
    );
    _validateLength(
      issues,
      ActividadValidationTarget.tramo,
      data.tramo,
      255,
      'Tramo',
    );
    _validateLength(
      issues,
      ActividadValidationTarget.kilometro,
      data.kilometro,
      50,
      'Kilómetro',
    );
    _validateLength(
      issues,
      ActividadValidationTarget.fuenteUbicacion,
      data.fuenteUbicacion,
      50,
      'Fuente de ubicación',
    );
    _validateLength(
      issues,
      ActividadValidationTarget.notaGeo,
      data.notaGeo,
      255,
      'Nota de ubicación',
    );

    final latText = (data.lat ?? '').trim();
    final lngText = (data.lng ?? '').trim();
    if (requireCoords && (latText.isEmpty || lngText.isEmpty)) {
      add(
        ActividadValidationTarget.ubicacion,
        'Captura la ubicación con el botón "Usar mi ubicación".',
      );
    } else if (latText.isNotEmpty || lngText.isNotEmpty) {
      final lat = double.tryParse(latText);
      final lng = double.tryParse(lngText);
      if (lat == null || lat < -90 || lat > 90) {
        add(
          ActividadValidationTarget.ubicacion,
          'La latitud de la ubicación no es válida.',
        );
      }
      if (lng == null || lng < -180 || lng > 180) {
        add(
          ActividadValidationTarget.ubicacion,
          'La longitud de la ubicación no es válida.',
        );
      }
    }

    _validateNonNegativeInt(
      issues,
      ActividadValidationTarget.personasAlcanzadas,
      data.personasAlcanzadas,
      'Personas alcanzadas',
      min: data.fomento == null ? 1 : 0,
    );
    _validateNonNegativeInt(
      issues,
      ActividadValidationTarget.personasParticipantes,
      data.personasParticipantes,
      'Personas participantes',
      max: maxParticipantsCount,
    );
    _validateNonNegativeInt(
      issues,
      ActividadValidationTarget.personasDetenidas,
      data.personasDetenidas,
      'Personas detenidas',
      max: maxDetainedCount,
    );

    if (requirePhotos && fotos.isEmpty) {
      add(ActividadValidationTarget.fotos, 'Selecciona al menos una foto.');
    }

    _validateFomento(issues, data.fomento);

    final seenPaths = <String>{};
    for (var i = 0; i < fotos.length; i += 1) {
      final file = fotos[i];
      final label = 'Foto ${i + 1}';
      final path = file.path.trim();
      if (path.isEmpty) {
        add(
          ActividadValidationTarget.fotos,
          '$label no tiene una ruta válida.',
        );
        continue;
      }
      if (!seenPaths.add(path)) {
        add(
          ActividadValidationTarget.fotos,
          '$label está duplicada en la misma captura.',
        );
      }
      if (!await file.exists()) {
        add(
          ActividadValidationTarget.fotos,
          '$label ya no existe en el dispositivo.',
        );
        continue;
      }

      final ext = path.split('.').last.toLowerCase();
      const allowed = <String>{'jpg', 'jpeg', 'png', 'webp'};
      if (!allowed.contains(ext)) {
        add(
          ActividadValidationTarget.fotos,
          '$label debe ser JPG, JPEG, PNG o WEBP.',
        );
      }

      final size = await file.length();
      if (size > _maxImageBytes) {
        add(
          ActividadValidationTarget.fotos,
          '$label es muy pesada (máximo 4 MB).',
        );
      }
    }

    for (var i = 0; i < data.vehiculos.length; i += 1) {
      _validateVehiculo(issues, data.vehiculos[i], i + 1);
    }

    return issues;
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
    int? unidadId,
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
    if (unidadId != null && unidadId > 0) {
      qp['unidad_id'] = unidadId.toString();
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

  static Future<List<ActividadRef>> fetchUnidadesFiltro() async {
    final headers = await _headersJson();
    final uri = Uri.parse(
      '${AuthService.baseUrl}/estadisticas-actividades/catalogos/unidades',
    );
    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(_parseBackendError(resp.body, resp.statusCode));
    }

    final raw = jsonDecode(resp.body);
    if (raw is! List) return const <ActividadRef>[];

    return raw
        .whereType<Map>()
        .map((e) => ActividadRef.fromJson(Map<String, dynamic>.from(e)))
        .where((item) => item.id > 0)
        .toList();
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

      final categorias = list
          .map((e) => ActividadCategoria.fromJson(e))
          .where((e) => e.id > 0)
          .toList();
      unawaited(_warmSubcategoriasCache(categorias));

      return categorias;
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

      final subcategorias = list
          .map((e) => ActividadSubcategoria.fromJson(e))
          .where((e) => e.id > 0)
          .toList();
      return await _prioritizeFomentoSubcategoriasForCurrentUser(subcategorias);
    } catch (e) {
      final cached = await _loadCache(cacheKey);
      if (cached.isNotEmpty) {
        final subcategorias = cached
            .map((e) => ActividadSubcategoria.fromJson(e))
            .where((e) => e.id > 0)
            .toList();
        return await _prioritizeFomentoSubcategoriasForCurrentUser(
          subcategorias,
        );
      }
      rethrow;
    }
  }

  static List<ActividadSubcategoria> prioritizeFomentoSubcategorias(
    List<ActividadSubcategoria> subcategorias,
  ) {
    final sorted = List<ActividadSubcategoria>.from(subcategorias);
    sorted.sort((a, b) {
      final prioridadA = a.programasFomento.isNotEmpty ? 0 : 1;
      final prioridadB = b.programasFomento.isNotEmpty ? 0 : 1;

      if (prioridadA != prioridadB) {
        return prioridadA.compareTo(prioridadB);
      }

      return a.nombre.toUpperCase().compareTo(b.nombre.toUpperCase());
    });
    return sorted;
  }

  static Future<List<ActividadSubcategoria>>
  _prioritizeFomentoSubcategoriasForCurrentUser(
    List<ActividadSubcategoria> subcategorias,
  ) async {
    final unidadId = await AuthService.getUnidadId();
    if (unidadId != AuthService.unidadCulturaVialId) return subcategorias;
    return prioritizeFomentoSubcategorias(subcategorias);
  }

  static Future<void> _warmSubcategoriasCache(
    List<ActividadCategoria> categorias,
  ) async {
    if (categorias.isEmpty) return;

    Map<String, String> headers;
    try {
      headers = await _headersJson();
    } catch (_) {
      return;
    }

    for (final categoria in categorias) {
      if (categoria.id <= 0) continue;
      try {
        final uri = Uri.parse('$_base/subcategorias/${categoria.id}');
        final resp = await http.get(uri, headers: headers);
        if (resp.statusCode < 200 || resp.statusCode >= 300) continue;

        final raw = jsonDecode(resp.body);
        final list = _extractListFromResponse(raw);
        await _saveCache(_subcategoriasCacheKey(categoria.id), list);
      } catch (_) {
        // Best-effort cache warmup for offline captures.
      }
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
    await _addLocalKilometrosRecorridos(
      fields,
      lat: data.lat,
      lng: data.lng,
      notaGeo: data.notaGeo,
    );
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
    List<File> fotos = const <File>[],
    List<int> eliminarFotos = const <int>[],
  }) async {
    final fields = data.toFields();
    await _addDelegacionKilometrosRecorridos(
      fields,
      lat: data.lat,
      lng: data.lng,
    );
    fields['_method'] = 'PUT';

    for (var index = 0; index < eliminarFotos.length; index += 1) {
      final fotoId = eliminarFotos[index];
      if (fotoId > 0) {
        fields['eliminar_fotos[$index]'] = fotoId.toString();
      }
    }

    final landscapeFotos = await PhotoOrientationService.forceLandscapeAll(
      fotos,
    );

    return OfflineSyncService.submitMultipart(
      label: 'Actividad',
      method: 'POST',
      uri: Uri.parse('$_base/$id'),
      fields: fields,
      files: <OfflineUploadFile>[
        for (final foto in landscapeFotos)
          OfflineUploadFile(field: 'fotos[]', path: foto.path),
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

  static Future<void> _addLocalKilometrosRecorridos(
    Map<String, String> fields, {
    required String? lat,
    required String? lng,
    String? notaGeo,
  }) async {
    final km = await DelegacionDistanceService.localMileageForCaptureKmField(
      lat: double.tryParse(lat?.trim() ?? ''),
      lng: double.tryParse(lng?.trim() ?? ''),
      accuracyMeters: _accuracyMetersFromGeoNote(notaGeo),
    );
    if (km == null) return;

    fields[DelegacionDistanceService.kilometrosRecorridosField] = km;
  }

  static double? _accuracyMetersFromGeoNote(String? notaGeo) {
    final text = (notaGeo ?? '').trim();
    if (text.isEmpty) return null;

    final accMatch = RegExp(
      r'ACC:\s*([0-9]+(?:[\.,][0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(text);
    final raw = accMatch?.group(1) ?? text;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  static Future<void> _addDelegacionKilometrosRecorridos(
    Map<String, String> fields, {
    required String? lat,
    required String? lng,
  }) async {
    final km =
        await DelegacionDistanceService.distanceFromCurrentDelegacionKmField(
          lat: double.tryParse(lat?.trim() ?? ''),
          lng: double.tryParse(lng?.trim() ?? ''),
        );
    if (km == null) return;

    fields[DelegacionDistanceService.kilometrosRecorridosField] = km;
  }

  static void _validateLength(
    List<ActividadValidationIssue> issues,
    ActividadValidationTarget target,
    String? value,
    int max,
    String label,
  ) {
    final text = (value ?? '').trim();
    if (text.length > max) {
      issues.add(
        ActividadValidationIssue(
          target: target,
          message: '$label no puede exceder $max caracteres.',
        ),
      );
    }
  }

  static void _validateMunicipio(
    List<ActividadValidationIssue> issues,
    String? value,
  ) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      issues.add(
        const ActividadValidationIssue(
          target: ActividadValidationTarget.municipio,
          message: 'Selecciona un municipio de Michoacan.',
        ),
      );
      return;
    }
    if (!MunicipiosMichoacan.isKnown(text)) {
      issues.add(
        const ActividadValidationIssue(
          target: ActividadValidationTarget.municipio,
          message: 'Selecciona un municipio de Michoacan.',
        ),
      );
    }
  }

  static void _validateNonNegativeInt(
    List<ActividadValidationIssue> issues,
    ActividadValidationTarget target,
    String? value,
    String label, {
    int min = 0,
    int? max,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      if (min > 0) {
        issues.add(
          ActividadValidationIssue(
            target: target,
            message: '$label debe ser al menos $min.',
          ),
        );
      }
      return;
    }

    final parsed = int.tryParse(text);
    if (parsed == null) {
      issues.add(
        ActividadValidationIssue(
          target: target,
          message: '$label debe ser un número entero.',
        ),
      );
      return;
    }
    if (parsed < min) {
      issues.add(
        ActividadValidationIssue(
          target: target,
          message: min <= 0
              ? '$label no puede ser negativo.'
              : '$label debe ser al menos $min.',
        ),
      );
    }
    if (max != null && parsed > max) {
      issues.add(
        ActividadValidationIssue(
          target: target,
          message: '$label no puede ser mayor a $max.',
        ),
      );
    }
  }

  static void _validateFomento(
    List<ActividadValidationIssue> issues,
    ActividadFomentoDetalle? fomento,
  ) {
    if (fomento == null) return;

    for (final field in ActividadFomentoDetalle.numericFields) {
      final value = fomento.valueFor(field.key);
      if (value > ActividadFomentoDetalle.maxCount) {
        issues.add(
          ActividadValidationIssue(
            target: ActividadValidationTarget.fomento,
            message:
                '${field.label} no puede ser mayor a ${ActividadFomentoDetalle.maxCount}.',
          ),
        );
      }
    }
  }

  static void _validateVehiculo(
    List<ActividadValidationIssue> issues,
    ActividadVehiculo vehiculo,
    int index,
  ) {
    final prefix = 'Vehículo $index';

    void add(String message) {
      issues.add(
        ActividadValidationIssue(
          target: ActividadValidationTarget.vehiculos,
          message: message,
        ),
      );
    }

    void requiredText(String? value, String label, int max) {
      final text = (value ?? '').trim();
      if (text.isEmpty) {
        add('$prefix: captura $label.');
      } else if (text.length > max) {
        add('$prefix: $label no puede exceder $max caracteres.');
      }
    }

    void optionalText(String? value, String label, int max) {
      final text = (value ?? '').trim();
      if (text.length > max) {
        add('$prefix: $label no puede exceder $max caracteres.');
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
      add('$prefix: $tipoServicioError');
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
      add('$prefix: capacidad de personas no puede ser negativa.');
    }
    if (vehiculo.montoDanos != null && vehiculo.montoDanos! < 0) {
      add('$prefix: monto de daños no puede ser negativo.');
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
