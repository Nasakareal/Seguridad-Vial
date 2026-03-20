class PeritoHomeFilters {
  final List<int> daysOptions;
  final List<int> wazeHoursOptions;
  final int defaultDays;
  final double defaultGridSize;
  final int defaultMinScore;
  final int defaultWazeHours;

  const PeritoHomeFilters({
    required this.daysOptions,
    required this.wazeHoursOptions,
    required this.defaultDays,
    required this.defaultGridSize,
    required this.defaultMinScore,
    required this.defaultWazeHours,
  });

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<int> _asIntList(dynamic raw) {
    if (raw is! List) return const <int>[];
    return raw
        .map((item) => _asInt(item, fallback: -1))
        .where((item) => item > 0)
        .toList();
  }

  factory PeritoHomeFilters.fromJson(Map<String, dynamic> json) {
    final defaults = (json['default_values'] is Map<String, dynamic>)
        ? json['default_values'] as Map<String, dynamic>
        : <String, dynamic>{};

    return PeritoHomeFilters(
      daysOptions: _asIntList(json['days_options']),
      wazeHoursOptions: _asIntList(json['waze_hours_options']),
      defaultDays: _asInt(defaults['days'], fallback: 30),
      defaultGridSize: _asDouble(defaults['grid_size'], fallback: 0.01),
      defaultMinScore: _asInt(defaults['min_score'], fallback: 3),
      defaultWazeHours: _asInt(defaults['waze_hours'], fallback: 12),
    );
  }
}

class PeritoHomeMapData {
  final double centerLat;
  final double centerLng;
  final double zoom;
  final String? generatedAt;
  final String? timezone;
  final int riskZonesCount;
  final int wazeAlertsCount;
  final List<PeritoRiskZone> riskZones;
  final List<PeritoWazeAlert> wazeAlerts;

  const PeritoHomeMapData({
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.generatedAt,
    required this.timezone,
    required this.riskZonesCount,
    required this.wazeAlertsCount,
    required this.riskZones,
    required this.wazeAlerts,
  });

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  factory PeritoHomeMapData.fromJson(Map<String, dynamic> json) {
    final map = (json['map'] is Map<String, dynamic>)
        ? json['map'] as Map<String, dynamic>
        : <String, dynamic>{};
    final center = (map['center'] is Map<String, dynamic>)
        ? map['center'] as Map<String, dynamic>
        : <String, dynamic>{};
    final meta = (json['meta'] is Map<String, dynamic>)
        ? json['meta'] as Map<String, dynamic>
        : <String, dynamic>{};
    final layers = (json['layers'] is Map<String, dynamic>)
        ? json['layers'] as Map<String, dynamic>
        : <String, dynamic>{};
    final counts = (json['counts'] is Map<String, dynamic>)
        ? json['counts'] as Map<String, dynamic>
        : <String, dynamic>{};

    final rawRiskZones = layers['risk_zones'];
    final rawWazeAlerts = layers['waze_alerts'];

    return PeritoHomeMapData(
      centerLat: _asDouble(center['lat'], fallback: 19.70595),
      centerLng: _asDouble(center['lng'], fallback: -101.194983),
      zoom: _asDouble(map['zoom'], fallback: 12),
      generatedAt: meta['generated_at']?.toString(),
      timezone: meta['timezone']?.toString(),
      riskZonesCount: _asInt(counts['risk_zones']),
      wazeAlertsCount: _asInt(counts['waze_alerts']),
      riskZones: rawRiskZones is List
          ? rawRiskZones
                .whereType<Map>()
                .map((item) => PeritoRiskZone.fromJson(
                      Map<String, dynamic>.from(item),
                    ))
                .toList()
          : const <PeritoRiskZone>[],
      wazeAlerts: rawWazeAlerts is List
          ? rawWazeAlerts
                .whereType<Map>()
                .map((item) => PeritoWazeAlert.fromJson(
                      Map<String, dynamic>.from(item),
                    ))
                .toList()
          : const <PeritoWazeAlert>[],
    );
  }
}

class PeritoRiskZone {
  final String cellKey;
  final double centerLat;
  final double centerLng;
  final int score;
  final int totalHechos;
  final String severity;
  final double radiusMeters;
  final String label;
  final String? topTipoHecho;
  final List<String> sectores;
  final List<String> municipios;
  final String? lastEventAt;
  final String strokeColor;
  final String fillColor;
  final List<PeritoSampleHecho> sampleHechos;

  const PeritoRiskZone({
    required this.cellKey,
    required this.centerLat,
    required this.centerLng,
    required this.score,
    required this.totalHechos,
    required this.severity,
    required this.radiusMeters,
    required this.label,
    required this.topTipoHecho,
    required this.sectores,
    required this.municipios,
    required this.lastEventAt,
    required this.strokeColor,
    required this.fillColor,
    required this.sampleHechos,
  });

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _asStringList(dynamic raw) {
    if (raw is! List) return const <String>[];
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  factory PeritoRiskZone.fromJson(Map<String, dynamic> json) {
    final style = (json['style'] is Map<String, dynamic>)
        ? json['style'] as Map<String, dynamic>
        : <String, dynamic>{};
    final rawSamples = json['sample_hechos'];

    return PeritoRiskZone(
      cellKey: json['cell_key']?.toString() ?? '',
      centerLat: _asDouble(json['center_lat']),
      centerLng: _asDouble(json['center_lng']),
      score: _asInt(json['score']),
      totalHechos: _asInt(json['total_hechos']),
      severity: json['severity']?.toString() ?? 'alta',
      radiusMeters: _asDouble(json['radius_meters'], fallback: 300),
      label: json['label']?.toString() ?? 'Zona de riesgo',
      topTipoHecho: json['top_tipo_hecho']?.toString(),
      sectores: _asStringList(json['sectores']),
      municipios: _asStringList(json['municipios']),
      lastEventAt: json['last_event_at']?.toString(),
      strokeColor: style['stroke_color']?.toString() ?? '#C62828',
      fillColor: style['fill_color']?.toString() ?? '#FF8A80',
      sampleHechos: rawSamples is List
          ? rawSamples
                .whereType<Map>()
                .map((item) => PeritoSampleHecho.fromJson(
                      Map<String, dynamic>.from(item),
                    ))
                .toList()
          : const <PeritoSampleHecho>[],
    );
  }
}

class PeritoSampleHecho {
  final int id;
  final String? folio;
  final String? tipoHecho;
  final String? fecha;
  final String? hora;

  const PeritoSampleHecho({
    required this.id,
    required this.folio,
    required this.tipoHecho,
    required this.fecha,
    required this.hora,
  });

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory PeritoSampleHecho.fromJson(Map<String, dynamic> json) {
    return PeritoSampleHecho(
      id: _asInt(json['id']),
      folio: json['folio']?.toString(),
      tipoHecho: json['tipo_hecho']?.toString(),
      fecha: json['fecha']?.toString(),
      hora: json['hora']?.toString(),
    );
  }
}

class PeritoWazeAlert {
  final int id;
  final String uuid;
  final double lat;
  final double lng;
  final String title;
  final String subtitle;
  final String? street;
  final String? city;
  final String? publishedAt;

  const PeritoWazeAlert({
    required this.id,
    required this.uuid,
    required this.lat,
    required this.lng,
    required this.title,
    required this.subtitle,
    required this.street,
    required this.city,
    required this.publishedAt,
  });

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  factory PeritoWazeAlert.fromJson(Map<String, dynamic> json) {
    return PeritoWazeAlert(
      id: _asInt(json['id']),
      uuid: json['uuid']?.toString() ?? '',
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      title: json['title']?.toString() ?? 'Choque Waze',
      subtitle: json['subtitle']?.toString() ?? 'Ubicación sin detalle',
      street: json['street']?.toString(),
      city: json['city']?.toString(),
      publishedAt: json['published_at']?.toString(),
    );
  }
}

class PeritoHechoDetail {
  final int id;
  final String? folio;
  final String? fecha;
  final String? hora;
  final String? tipoHecho;
  final String? sector;
  final String? municipio;
  final double? lat;
  final double? lng;
  final String? createdAt;
  final String? updatedAt;
  final List<Map<String, dynamic>> vehiculos;
  final List<Map<String, dynamic>> lesionados;

  const PeritoHechoDetail({
    required this.id,
    required this.folio,
    required this.fecha,
    required this.hora,
    required this.tipoHecho,
    required this.sector,
    required this.municipio,
    required this.lat,
    required this.lng,
    required this.createdAt,
    required this.updatedAt,
    required this.vehiculos,
    required this.lesionados,
  });

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  factory PeritoHechoDetail.fromJson(Map<String, dynamic> json) {
    final hecho = (json['hecho'] is Map<String, dynamic>)
        ? json['hecho'] as Map<String, dynamic>
        : <String, dynamic>{};

    return PeritoHechoDetail(
      id: _asInt(hecho['id']),
      folio: hecho['folio']?.toString(),
      fecha: hecho['fecha']?.toString(),
      hora: hecho['hora']?.toString(),
      tipoHecho: hecho['tipo_hecho']?.toString(),
      sector: hecho['sector']?.toString(),
      municipio: hecho['municipio']?.toString(),
      lat: _asNullableDouble(hecho['lat']),
      lng: _asNullableDouble(hecho['lng']),
      createdAt: hecho['created_at']?.toString(),
      updatedAt: hecho['updated_at']?.toString(),
      vehiculos: _asMapList(json['vehiculos']),
      lesionados: _asMapList(json['lesionados']),
    );
  }
}
