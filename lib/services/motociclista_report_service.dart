import 'dart:io';

import '../models/actividad.dart';
import '../models/actividad_categoria.dart';
import '../models/actividad_subcategoria.dart';
import 'auth_service.dart';
import 'actividades_service.dart';
import 'offline_sync_service.dart';

enum MotociclistaReportKind {
  abanderamiento,
  apoyoPreventivo,
  cierreVialidad,
  dispositivoVial,
  monitoreoSinNovedad,
}

extension MotociclistaReportKindLabel on MotociclistaReportKind {
  String get title {
    switch (this) {
      case MotociclistaReportKind.abanderamiento:
        return 'Abanderamiento por hecho de tránsito';
      case MotociclistaReportKind.apoyoPreventivo:
        return 'Apoyo vial preventivo';
      case MotociclistaReportKind.cierreVialidad:
        return 'Cierre parcial o total de vialidad';
      case MotociclistaReportKind.dispositivoVial:
        return 'Dispositivo vial';
      case MotociclistaReportKind.monitoreoSinNovedad:
        return 'Monitoreo sin novedad';
    }
  }

  String get asunto {
    switch (this) {
      case MotociclistaReportKind.abanderamiento:
        return 'ABANDERAMIENTO POR HECHO DE TRÁNSITO';
      case MotociclistaReportKind.apoyoPreventivo:
        return 'APOYO VIAL PREVENTIVO';
      case MotociclistaReportKind.cierreVialidad:
        return 'CIERRE DE VIALIDAD';
      case MotociclistaReportKind.dispositivoVial:
        return 'DISPOSITIVO VIAL';
      case MotociclistaReportKind.monitoreoSinNovedad:
        return 'MONITOREO SIN NOVEDAD';
    }
  }
}

class MotociclistaReportDraft {
  final MotociclistaReportKind kind;
  final String fecha;
  final String hora;
  final String ubicacion;
  final String lat;
  final String lng;
  final String coordenadas;
  final String tipoPreliminar;
  final String lesionados;
  final String estado;
  final String motivo;
  final String descripcion;
  final String tipoCierre;
  final String vialidadAfectada;
  final String sentidoAfectado;
  final String estadoCirculacion;
  final String puntosCubiertos;
  final String estadoFuerza;
  final String zonaMonitoreada;
  final String kilometrosRecorridos;
  final String unidadCrp;
  final String numeroElementos;
  final String informa;

  const MotociclistaReportDraft({
    required this.kind,
    required this.fecha,
    required this.hora,
    required this.ubicacion,
    required this.lat,
    required this.lng,
    required this.coordenadas,
    this.tipoPreliminar = '',
    this.lesionados = '',
    this.estado = '',
    this.motivo = '',
    this.descripcion = '',
    this.tipoCierre = '',
    this.vialidadAfectada = '',
    this.sentidoAfectado = '',
    this.estadoCirculacion = '',
    this.puntosCubiertos = '',
    this.estadoFuerza = '',
    this.zonaMonitoreada = '',
    this.kilometrosRecorridos = '',
    this.unidadCrp = '',
    this.numeroElementos = '',
    this.informa = '',
  });
}

class MotociclistaCatalogSelection {
  final ActividadCategoria categoria;
  final ActividadSubcategoria subcategoria;

  const MotociclistaCatalogSelection({
    required this.categoria,
    required this.subcategoria,
  });
}

class MotociclistaCatalogTarget {
  final String categoria;
  final String subcategoria;

  const MotociclistaCatalogTarget({
    required this.categoria,
    required this.subcategoria,
  });
}

class MotociclistaReportService {
  static const String reportSourceMarker = 'ÁGUILAS MOTOCICLETAS';
  static const String legacyReportSourceMarker = 'MOTOCICLISTA';

  static Future<OfflineActionResult> guardarReporte({
    required MotociclistaReportDraft draft,
    required List<File> fotos,
  }) async {
    final catalog = await resolveActivityCatalog(draft);
    final data = buildActividadData(draft: draft, catalog: catalog);
    final validation = await ActividadesService.validateBeforeSubmit(
      data: data,
      fotos: fotos,
      requirePhotos: false,
      requireCoords: false,
      requireTimestamp: true,
    );
    if (validation != null) {
      throw Exception(validation);
    }

    return ActividadesService.create(data: data, fotos: fotos);
  }

  static ActividadUpsertData buildActividadData({
    required MotociclistaReportDraft draft,
    required MotociclistaCatalogSelection catalog,
  }) {
    final observaciones = _observaciones(draft);
    return ActividadUpsertData(
      actividadCategoriaId: catalog.categoria.id,
      actividadSubcategoriaId: catalog.subcategoria.id,
      fecha: draft.fecha,
      hora: draft.hora,
      lugar: _activityPlace(draft),
      municipio: 'MORELIA',
      lat: draft.lat,
      lng: draft.lng,
      coordenadasTexto: draft.coordenadas,
      fuenteUbicacion: 'GPS_APP',
      motivo: _motivo(draft),
      narrativa: buildInstitutionalText(draft),
      accionesRealizadas: _acciones(draft),
      observaciones: observaciones,
      personasAlcanzadas: '1',
      personasParticipantes: draft.numeroElementos.trim().isEmpty
          ? '1'
          : draft.numeroElementos.trim(),
      personasDetenidas: '0',
      elementosParticipantesTexto: draft.numeroElementos.trim().isEmpty
          ? ''
          : '${draft.numeroElementos.trim()} elementos',
      patrullasParticipantesTexto: reportSourceMarker,
    );
  }

  static Future<List<Actividad>> fetchRecentReports({int days = 30}) async {
    final safeDays = days.clamp(1, 60);
    final today = DateTime.now();
    final byId = <int, Actividad>{};

    for (var offset = 0; offset < safeDays; offset += 1) {
      final date = today.subtract(Duration(days: offset));
      for (final marker in const <String>[
        reportSourceMarker,
        legacyReportSourceMarker,
      ]) {
        final items = await ActividadesService.fetchIndex(
          date: date,
          perPage: 20,
          unidadId: AuthService.unidadVialidadesUrbanasId,
          q: marker,
        );

        for (final item in items) {
          if (isMotociclistaReport(item)) {
            byId[item.id] = item;
          }
        }
      }
    }

    final reports = byId.values.toList()
      ..sort((a, b) => _activitySortValue(b).compareTo(_activitySortValue(a)));
    return reports;
  }

  static bool isMotociclistaReport(Actividad actividad) {
    final patrullas = _normalize(actividad.patrullasParticipantesTexto ?? '');
    final observaciones = _normalize(actividad.observaciones ?? '');
    final reportMarker = _normalize(reportSourceMarker);
    final legacyMarker = _normalize(legacyReportSourceMarker);
    return patrullas.contains(reportMarker) ||
        patrullas.contains(legacyMarker) ||
        observaciones.contains('REPORTE AGUILAS MOTOCICLETAS') ||
        observaciones.contains('REPORTE MOTOCICLISTA');
  }

  static Future<MotociclistaCatalogSelection> resolveActivityCatalog(
    MotociclistaReportDraft draft,
  ) async {
    final target = catalogTargetFor(draft);
    final categorias = await ActividadesService.fetchCategorias();
    if (categorias.isEmpty) {
      throw Exception('No hay categorías de actividades disponibles.');
    }

    final categoria = _firstWhereOrNull(categorias, (item) {
      return _normalize(item.nombre) == _normalize(target.categoria);
    });

    if (categoria == null) {
      throw Exception('No existe la categoría ${target.categoria}.');
    }

    final subcategorias = await ActividadesService.fetchSubcategorias(
      categoria.id,
    );
    final subcategoria = _firstWhereOrNull(subcategorias, (item) {
      return _normalize(item.nombre) == _normalize(target.subcategoria);
    });

    if (subcategoria == null) {
      throw Exception(
        'No existe la subcategoría ${target.subcategoria} para ${target.categoria}.',
      );
    }

    return MotociclistaCatalogSelection(
      categoria: categoria,
      subcategoria: subcategoria,
    );
  }

  static MotociclistaCatalogTarget catalogTargetFor(
    MotociclistaReportDraft draft,
  ) {
    switch (draft.kind) {
      case MotociclistaReportKind.abanderamiento:
        return const MotociclistaCatalogTarget(
          categoria: 'ABANDERAMIENTOS',
          subcategoria: 'ACCIDENTES',
        );
      case MotociclistaReportKind.apoyoPreventivo:
        return const MotociclistaCatalogTarget(
          categoria: 'DISPOSITIVOS DE SEGURIDAD VIAL',
          subcategoria: 'APOYO A LA VIALIDAD',
        );
      case MotociclistaReportKind.cierreVialidad:
        return const MotociclistaCatalogTarget(
          categoria: 'ABANDERAMIENTOS',
          subcategoria: 'CORTES DE CIRCULACIÓN',
        );
      case MotociclistaReportKind.dispositivoVial:
        return const MotociclistaCatalogTarget(
          categoria: 'DISPOSITIVOS DE SEGURIDAD VIAL',
          subcategoria: 'APOYO A LA VIALIDAD',
        );
      case MotociclistaReportKind.monitoreoSinNovedad:
        return MotociclistaCatalogTarget(
          categoria: 'MONITOREOS',
          subcategoria: _monitoreoSubcategoria(draft.zonaMonitoreada),
        );
    }
  }

  static String buildInstitutionalText(MotociclistaReportDraft draft) {
    final fecha = _dateForHuman(draft.fecha);
    final hora = _clean(draft.hora);
    final ubicacion = _activityPlace(draft);
    final asunto = draft.kind.asunto;
    final motivo = _motivo(draft);
    final objetivo = _objetivo(draft);
    final extra = _extraParagraph(draft);
    final ubicacionMapa = _draftLocationLines(draft);
    final elementos = _fallback(draft.numeroElementos, 'No especificado');
    final unidad = _fallback(draft.unidadCrp, 'Unidad no especificada');
    final informa = _fallback(draft.informa, 'Nombre no especificado');

    final lines = <String>[
      'GUARDIA CIVIL',
      'COORDINACIÓN DEL AGRUPAMIENTO DE SEGURIDAD VIAL',
      'UNIDAD DE PROTECCIÓN EN VIALIDADES URBANAS',
      'MORELIA, MICHOACÁN',
      '',
      'FECHA: $fecha',
      'HORA: ${_fallback(hora, 'No especificada')}',
      ...ubicacionMapa,
      if (ubicacionMapa.isNotEmpty) '',
      'ASUNTO: $asunto',
      '',
      'Me permito informar que a la hora antes mencionada se activa protocolo en $ubicacion, derivado de $motivo, con el objetivo de $objetivo.',
      if (extra.isNotEmpty) '',
      if (extra.isNotEmpty) extra,
      '',
      'ESTADO DE FUERZA:',
      '$elementos elementos',
      unidad,
      '',
      'RESPETUOSAMENTE:',
      informa,
    ];

    return lines.join('\n').trim();
  }

  static String buildShareTextFromActividad(
    Actividad actividad, {
    String? informaFallback,
  }) {
    final narrativa = actividad.narrativa ?? '';
    final asunto = _fallback(
      _extractLineValue(narrativa, 'ASUNTO'),
      _subjectFromActivity(actividad),
    );
    final cuerpo = _fallback(
      _extractReportBody(narrativa),
      _bodyFromActivity(actividad),
    );
    final ubicacionMapa = _activityLocationLines(actividad);
    final elementos = _shareElements(actividad);
    final unidad = _shareUnit(actividad);
    final informa = _fallback(
      _extractSectionValue(narrativa, const ['INFORMA', 'RESPETUOSAMENTE']),
      _fallback(informaFallback ?? '', 'Nombre no especificado'),
    );

    final lines = <String>[
      'GUARDIA CIVIL',
      'COORDINACIÓN DEL AGRUPAMIENTO DE SEGURIDAD VIAL',
      'UNIDAD DE PROTECCIÓN EN VIALIDADES URBANAS',
      'MORELIA, MICHOACÁN',
      '',
      'ID DE ACTIVIDAD: ${actividad.id}',
      'FECHA: ${_dateForHuman(actividad.fecha ?? '')}',
      'HORA: ${_fallback(actividad.hora ?? '', 'No especificada')}',
      ...ubicacionMapa,
      if (ubicacionMapa.isNotEmpty) '',
      'ASUNTO: ${asunto.toUpperCase()}',
      '',
      cuerpo,
      '',
      'ESTADO DE FUERZA:',
      elementos,
      unidad,
      '',
      'INFORMA:',
      informa,
    ];

    return _cleanMultiline(lines).trim();
  }

  static List<String> validateDraft(
    MotociclistaReportDraft draft, {
    required int photoCount,
  }) {
    final issues = <String>[];

    void required(String value, String label) {
      if (value.trim().isEmpty) issues.add(label);
    }

    required(draft.fecha, 'Fecha');
    required(draft.hora, 'Hora');
    return issues.toSet().toList();
  }

  static String _motivo(MotociclistaReportDraft draft) {
    switch (draft.kind) {
      case MotociclistaReportKind.abanderamiento:
        return _fallback(draft.tipoPreliminar, 'un hecho de tránsito');
      case MotociclistaReportKind.apoyoPreventivo:
        return _fallback(draft.motivo, 'apoyo vial preventivo');
      case MotociclistaReportKind.cierreVialidad:
        final tipo = _fallback(draft.tipoCierre, 'cierre de vialidad');
        final motivo = _fallback(draft.motivo, 'situación vial');
        return '$tipo por $motivo';
      case MotociclistaReportKind.dispositivoVial:
        return _fallback(draft.motivo, 'dispositivo vial');
      case MotociclistaReportKind.monitoreoSinNovedad:
        return 'monitoreo preventivo sin novedad';
    }
  }

  static String _objetivo(MotociclistaReportDraft draft) {
    switch (draft.kind) {
      case MotociclistaReportKind.abanderamiento:
        return 'salvaguardar la integridad física de usuarios de la vía, prevenir otro hecho vial y mantener la circulación segura';
      case MotociclistaReportKind.apoyoPreventivo:
        return 'prevenir riesgos, orientar a usuarios de la vía y mantener condiciones de circulación segura';
      case MotociclistaReportKind.cierreVialidad:
        return 'regular la circulación, proteger a usuarios de la vía y evitar incidentes secundarios';
      case MotociclistaReportKind.dispositivoVial:
        return 'mantener presencia preventiva, ordenar la movilidad y reforzar la seguridad vial';
      case MotociclistaReportKind.monitoreoSinNovedad:
        return 'mantener vigilancia preventiva y verificar condiciones de movilidad sin novedad relevante';
    }
  }

  static String _extraParagraph(MotociclistaReportDraft draft) {
    switch (draft.kind) {
      case MotociclistaReportKind.abanderamiento:
        final estado = _clean(draft.estado);
        final lesionados = _clean(draft.lesionados);
        return [
          if (estado.isNotEmpty) 'Estado: $estado.',
          if (lesionados.isNotEmpty) 'Lesionados: $lesionados.',
          if (draft.descripcion.trim().isNotEmpty) draft.descripcion.trim(),
        ].join('\n');
      case MotociclistaReportKind.apoyoPreventivo:
        return draft.descripcion.trim();
      case MotociclistaReportKind.cierreVialidad:
        return [
          if (draft.vialidadAfectada.trim().isNotEmpty)
            'Vialidad afectada: ${draft.vialidadAfectada.trim()}.',
          if (draft.sentidoAfectado.trim().isNotEmpty)
            'Sentido afectado: ${draft.sentidoAfectado.trim()}.',
          if (draft.estadoCirculacion.trim().isNotEmpty)
            'Estado de circulación: ${draft.estadoCirculacion.trim()}.',
          if (draft.descripcion.trim().isNotEmpty) draft.descripcion.trim(),
        ].join('\n');
      case MotociclistaReportKind.dispositivoVial:
        return [
          if (draft.puntosCubiertos.trim().isNotEmpty)
            'Lugar cubierto: ${draft.puntosCubiertos.trim()}.',
          if (draft.estadoFuerza.trim().isNotEmpty)
            'Estado de fuerza: ${draft.estadoFuerza.trim()}.',
          if (draft.descripcion.trim().isNotEmpty) draft.descripcion.trim(),
        ].join('\n');
      case MotociclistaReportKind.monitoreoSinNovedad:
        return [
          if (draft.zonaMonitoreada.trim().isNotEmpty)
            'Zona monitoreada: ${draft.zonaMonitoreada.trim()}.',
          if (draft.kilometrosRecorridos.trim().isNotEmpty)
            'Kilómetros recorridos: ${draft.kilometrosRecorridos.trim()}.',
          if (draft.descripcion.trim().isNotEmpty) draft.descripcion.trim(),
        ].join('\n');
    }
  }

  static String _acciones(MotociclistaReportDraft draft) {
    switch (draft.kind) {
      case MotociclistaReportKind.abanderamiento:
        return 'Protección y abanderamiento. ${draft.estado}'.trim();
      case MotociclistaReportKind.apoyoPreventivo:
        return 'Apoyo vial preventivo.';
      case MotociclistaReportKind.cierreVialidad:
        return 'Control de cierre ${draft.tipoCierre}.'.trim();
      case MotociclistaReportKind.dispositivoVial:
        return 'Dispositivo vial preventivo.';
      case MotociclistaReportKind.monitoreoSinNovedad:
        return 'Monitoreo preventivo sin novedad.';
    }
  }

  static String _observaciones(MotociclistaReportDraft draft) {
    return [
      'Reporte Águilas Motocicletas: ${draft.kind.title}',
      if (draft.descripcion.trim().isNotEmpty)
        'Descripción: ${draft.descripcion.trim()}',
      if (draft.lesionados.trim().isNotEmpty)
        'Lesionados: ${draft.lesionados.trim()}',
      if (draft.estadoCirculacion.trim().isNotEmpty)
        'Circulación: ${draft.estadoCirculacion.trim()}',
      if (draft.kilometrosRecorridos.trim().isNotEmpty)
        'Kilómetros: ${draft.kilometrosRecorridos.trim()}',
    ].join('\n');
  }

  static String _activityPlace(MotociclistaReportDraft draft) {
    final ubicacion = draft.ubicacion.trim();
    if (ubicacion.isNotEmpty) return ubicacion;

    final coordenadas = draft.coordenadas.trim();
    if (coordenadas.isNotEmpty) return 'Ubicación GPS $coordenadas';

    return 'Lugar informado';
  }

  static String _activityPlaceFromActividad(Actividad actividad) {
    final lugar = (actividad.lugar ?? '').trim();
    if (lugar.isNotEmpty) return lugar;

    final coordenadas = (actividad.coordenadasTexto ?? '').trim();
    if (coordenadas.isNotEmpty) return 'Ubicación GPS $coordenadas';

    final lat = actividad.lat;
    final lng = actividad.lng;
    if (lat != null && lng != null) return 'Ubicación GPS $lat, $lng';

    return 'Lugar informado';
  }

  static List<String> _draftLocationLines(MotociclistaReportDraft draft) {
    final pair =
        _coordinatePairFromTextValues(draft.lat, draft.lng) ??
        _coordinatePairFromFreeText(draft.coordenadas);
    if (pair != null) {
      return [
        'COORDENADAS: ${pair[0]}, ${pair[1]}',
        'GOOGLE MAPS: https://www.google.com/maps?q=${pair[0]},${pair[1]}',
      ];
    }

    final coordenadas = draft.coordenadas.trim();
    if (coordenadas.isEmpty) return const <String>[];
    return ['COORDENADAS: $coordenadas'];
  }

  static List<String> _activityLocationLines(Actividad actividad) {
    final pair =
        _coordinatePairFromNums(actividad.lat, actividad.lng) ??
        _coordinatePairFromFreeText(actividad.coordenadasTexto ?? '');
    if (pair != null) {
      return [
        'COORDENADAS: ${pair[0]}, ${pair[1]}',
        'GOOGLE MAPS: https://www.google.com/maps?q=${pair[0]},${pair[1]}',
      ];
    }

    final coordenadas = (actividad.coordenadasTexto ?? '').trim();
    if (coordenadas.isEmpty) return const <String>[];
    return ['COORDENADAS: $coordenadas'];
  }

  static List<String>? _coordinatePairFromNums(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return [_formatCoordinate(lat), _formatCoordinate(lng)];
  }

  static List<String>? _coordinatePairFromTextValues(
    String latRaw,
    String lngRaw,
  ) {
    final lat = double.tryParse(latRaw.trim().replaceAll(',', '.'));
    final lng = double.tryParse(lngRaw.trim().replaceAll(',', '.'));
    return _coordinatePairFromNums(lat, lng);
  }

  static List<String>? _coordinatePairFromFreeText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final match = RegExp(
      r'(-?\d+(?:[.,]\d+)?)\s*,\s*(-?\d+(?:[.,]\d+)?)',
    ).firstMatch(text);
    if (match == null) return null;

    return _coordinatePairFromTextValues(
      match.group(1) ?? '',
      match.group(2) ?? '',
    );
  }

  static String _formatCoordinate(double value) => value.toStringAsFixed(7);

  static String _subjectFromActivity(Actividad actividad) {
    final observaciones = actividad.observaciones ?? '';
    final match = RegExp(
      r'Reporte\s+(?:Águilas\s+Motocicletas|Aguilas\s+Motocicletas|Motociclista):\s*([^\n\r]+)',
      caseSensitive: false,
    ).firstMatch(observaciones);
    if (match != null) {
      final value = match.group(1)?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    final motivo = (actividad.motivo ?? '').trim();
    if (motivo.isNotEmpty) return motivo;

    final subcategoria = actividad.subcategoria?.nombre.trim() ?? '';
    if (subcategoria.isNotEmpty) return subcategoria;

    return 'REPORTE ÁGUILAS MOTOCICLETAS';
  }

  static String _bodyFromActivity(Actividad actividad) {
    final lugar = _activityPlaceFromActividad(actividad);
    final motivo = _fallback(
      actividad.motivo ?? '',
      _subjectFromActivity(actividad).toLowerCase(),
    );
    return 'Me permito informar que a la hora antes mencionada se activa protocolo en $lugar, derivado de $motivo, con el objetivo de prevenir riesgos, orientar a usuarios de la vía y mantener condiciones de circulación segura.';
  }

  static String _shareElements(Actividad actividad) {
    final text = (actividad.elementosParticipantesTexto ?? '').trim();
    if (text.isNotEmpty) return text;

    if (actividad.personasParticipantes > 0) {
      return '${actividad.personasParticipantes} elementos';
    }

    return 'No especificado';
  }

  static String _shareUnit(Actividad actividad) {
    final patrullas = (actividad.patrullasParticipantesTexto ?? '').trim();
    if (patrullas.isNotEmpty) {
      if (_normalize(patrullas) == _normalize(legacyReportSourceMarker)) {
        return reportSourceMarker;
      }
      return patrullas;
    }

    final unidad = actividad.unidad?.nombre.trim() ?? '';
    if (unidad.isNotEmpty) return unidad;

    return reportSourceMarker;
  }

  static String _monitoreoSubcategoria(String zona) {
    final normalized = _normalize(zona);
    if (normalized.contains('PERIFER')) return 'PERIFÉRICOS';
    if (normalized.contains('AVENIDA')) return 'AVENIDAS';
    if (normalized.contains('BANCO')) return 'BANCOS';
    if (normalized.contains('TIENDA')) return 'TIENDAS DEPARTAMENTALES';
    if (normalized.contains('OFICINA')) return 'OFICINAS GUBERNAMENTALES';
    return 'OTROS MONITOREOS (Especificar en las novedades relevantes)';
  }

  static T? _firstWhereOrNull<T>(
    Iterable<T> items,
    bool Function(T item) test,
  ) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }

  static int _activitySortValue(Actividad actividad) {
    final date = DateTime.tryParse((actividad.fecha ?? '').trim());
    final time = (actividad.hora ?? '').trim();
    final parts = time.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    final base =
        date ?? actividad.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime(
      base.year,
      base.month,
      base.day,
      hour.clamp(0, 23),
      minute.clamp(0, 59),
    ).millisecondsSinceEpoch;
  }

  static String _dateForHuman(String raw) {
    final date = DateTime.tryParse(raw.trim());
    if (date == null) return _fallback(raw, 'No especificada');
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  static String _fallback(String value, String fallback) {
    final text = value.trim();
    return text.isEmpty ? fallback : text;
  }

  static String _clean(String value) => value.trim();

  static String _extractLineValue(String text, String label) {
    final expected = _normalize(label).replaceAll(':', '');
    for (final line in text.replaceAll('\r\n', '\n').split('\n')) {
      final cleanLine = line.trim();
      final colon = cleanLine.indexOf(':');
      if (colon < 0) continue;

      final left = _normalize(cleanLine.substring(0, colon));
      if (left == expected) {
        return cleanLine.substring(colon + 1).trim();
      }
    }

    return '';
  }

  static String _extractSectionValue(String text, List<String> labels) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final expected = labels.map((e) => _normalize(e).replaceAll(':', ''));

    for (var i = 0; i < lines.length; i += 1) {
      final cleanLine = lines[i].trim();
      if (cleanLine.isEmpty) continue;

      final colon = cleanLine.indexOf(':');
      final left = colon >= 0 ? cleanLine.substring(0, colon) : cleanLine;
      if (!expected.contains(_normalize(left))) continue;

      if (colon >= 0) {
        final inline = cleanLine.substring(colon + 1).trim();
        if (inline.isNotEmpty) return inline;
      }

      for (var j = i + 1; j < lines.length; j += 1) {
        final candidate = lines[j].trim();
        if (candidate.isEmpty) continue;
        if (_looksLikeSection(candidate)) break;
        return candidate;
      }
    }

    return '';
  }

  static String _extractReportBody(String narrativa) {
    final lines = narrativa.replaceAll('\r\n', '\n').split('\n');
    final start = lines.indexWhere((line) {
      return _normalize(line).startsWith('ME PERMITO INFORMAR');
    });
    if (start < 0) return '';

    var end = lines.length;
    for (var i = start + 1; i < lines.length; i += 1) {
      final normalized = _normalize(lines[i]);
      if (normalized.startsWith('ESTADO DE FUERZA') ||
          normalized.startsWith('RESPETUOSAMENTE') ||
          normalized.startsWith('INFORMA') ||
          normalized.startsWith('DATOS GENERALES') ||
          normalized == 'CRP') {
        end = i;
        break;
      }
    }

    return _cleanMultiline(lines.sublist(start, end));
  }

  static bool _looksLikeSection(String text) {
    final normalized = _normalize(text);
    return normalized.endsWith(':') ||
        normalized.startsWith('FECHA') ||
        normalized.startsWith('HORA') ||
        normalized.startsWith('ASUNTO') ||
        normalized.startsWith('ESTADO DE FUERZA') ||
        normalized.startsWith('RESPETUOSAMENTE') ||
        normalized.startsWith('INFORMA');
  }

  static String _cleanMultiline(Iterable<String> lines) {
    final out = <String>[];
    var lastWasBlank = false;

    for (final line in lines) {
      final cleanLine = line.trim();
      if (cleanLine.isEmpty) {
        if (out.isNotEmpty && !lastWasBlank) {
          out.add('');
          lastWasBlank = true;
        }
        continue;
      }

      out.add(cleanLine);
      lastWasBlank = false;
    }

    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }

    return out.join('\n');
  }

  static String _normalize(String raw) {
    return raw
        .trim()
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
