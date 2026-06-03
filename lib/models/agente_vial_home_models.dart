class AgenteVialHomeMapData {
  final double centerLat;
  final double centerLng;
  final double zoom;
  final String? generatedAt;
  final String? timezone;
  final String city;
  final int targetHour;
  final String targetHourLabel;
  final int wazeHours;
  final int historyDays;
  final int wazeAlertsCount;
  final int choques;
  final int cierres;
  final int chaosCellsCount;
  final int riskCellsCount;
  final double topCrashProbability;
  final List<AgenteVialAlert> alerts;
  final List<AgenteVialChaosCell> chaosCells;
  final List<AgenteVialRiskCell> riskCells;
  final List<AgenteVialHourlyBucket> hourly;

  const AgenteVialHomeMapData({
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.generatedAt,
    required this.timezone,
    required this.city,
    required this.targetHour,
    required this.targetHourLabel,
    required this.wazeHours,
    required this.historyDays,
    required this.wazeAlertsCount,
    required this.choques,
    required this.cierres,
    required this.chaosCellsCount,
    required this.riskCellsCount,
    required this.topCrashProbability,
    required this.alerts,
    required this.chaosCells,
    required this.riskCells,
    required this.hourly,
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

  static List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (raw is! List) return <T>[];
    return raw
        .whereType<Map>()
        .map((item) => parser(Map<String, dynamic>.from(item)))
        .toList();
  }

  factory AgenteVialHomeMapData.fromJson(Map<String, dynamic> json) {
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
    final summary = (json['summary'] is Map<String, dynamic>)
        ? json['summary'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AgenteVialHomeMapData(
      centerLat: _asDouble(center['lat'], fallback: 19.70595),
      centerLng: _asDouble(center['lng'], fallback: -101.194983),
      zoom: _asDouble(map['zoom'], fallback: 12.5),
      generatedAt: meta['generated_at']?.toString(),
      timezone: meta['timezone']?.toString(),
      city: meta['city']?.toString() ?? 'Morelia',
      targetHour: _asInt(meta['target_hour']),
      targetHourLabel: meta['target_hour_label']?.toString() ?? '00:00',
      wazeHours: _asInt(meta['waze_hours'], fallback: 6),
      historyDays: _asInt(meta['history_days'], fallback: 90),
      wazeAlertsCount: _asInt(counts['waze_alerts']),
      choques: _asInt(counts['choques']),
      cierres: _asInt(counts['cierres']),
      chaosCellsCount: _asInt(counts['chaos_cells']),
      riskCellsCount: _asInt(counts['risk_cells']),
      topCrashProbability: _asDouble(counts['top_crash_probability']),
      alerts: _parseList(layers['waze_alerts'], AgenteVialAlert.fromJson),
      chaosCells: _parseList(
        layers['chaos_cells'],
        AgenteVialChaosCell.fromJson,
      ),
      riskCells: _parseList(layers['risk_cells'], AgenteVialRiskCell.fromJson),
      hourly: _parseList(summary['hourly'], AgenteVialHourlyBucket.fromJson),
    );
  }
}

class AgenteVialAlert {
  final int id;
  final String uuid;
  final String type;
  final double lat;
  final double lng;
  final String title;
  final String subtitle;
  final String? street;
  final String? city;
  final String? publishedAt;

  const AgenteVialAlert({
    required this.id,
    required this.uuid,
    required this.type,
    required this.lat,
    required this.lng,
    required this.title,
    required this.subtitle,
    required this.street,
    required this.city,
    required this.publishedAt,
  });

  bool get isCierre => type == 'waze_road_closed';

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

  factory AgenteVialAlert.fromJson(Map<String, dynamic> json) {
    return AgenteVialAlert(
      id: _asInt(json['id']),
      uuid: json['uuid']?.toString() ?? '',
      type: json['type']?.toString() ?? 'waze_accident',
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      title: json['title']?.toString() ?? 'Alerta Waze Morelia',
      subtitle: json['subtitle']?.toString() ?? 'Ubicación sin detalle',
      street: json['street']?.toString(),
      city: json['city']?.toString(),
      publishedAt: json['published_at']?.toString(),
    );
  }
}

class AgenteVialChaosCell {
  final String cellKey;
  final double lat;
  final double lng;
  final double score;
  final String nivel;
  final String nivelLabel;
  final String color;
  final String accion;
  final double radiusMeters;
  final int total;
  final int choques;
  final int cierres;
  final String? lastWazeAt;

  const AgenteVialChaosCell({
    required this.cellKey,
    required this.lat,
    required this.lng,
    required this.score,
    required this.nivel,
    required this.nivelLabel,
    required this.color,
    required this.accion,
    required this.radiusMeters,
    required this.total,
    required this.choques,
    required this.cierres,
    required this.lastWazeAt,
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

  factory AgenteVialChaosCell.fromJson(Map<String, dynamic> json) {
    return AgenteVialChaosCell(
      cellKey: json['cell_key']?.toString() ?? '',
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      score: _asDouble(json['score']),
      nivel: json['nivel']?.toString() ?? 'medio',
      nivelLabel: json['nivel_label']?.toString() ?? 'Caos activo',
      color: json['color']?.toString() ?? '#F59E0B',
      accion: json['accion']?.toString() ?? 'Monitoreo activo',
      radiusMeters: _asDouble(json['radius_meters'], fallback: 260),
      total: _asInt(json['total']),
      choques: _asInt(json['choques']),
      cierres: _asInt(json['cierres']),
      lastWazeAt: json['last_waze_at']?.toString(),
    );
  }
}

class AgenteVialRiskCell {
  final String cellKey;
  final double lat;
  final double lng;
  final double score;
  final String nivel;
  final String nivelLabel;
  final String color;
  final String accion;
  final double radiusMeters;
  final double crashProbability;
  final int crashProbabilityPct;
  final int historicTotal;
  final int historicCrashes;
  final int recentWazeTotal;
  final int recentChoques;
  final int recentCierres;
  final String? lastEventAt;

  const AgenteVialRiskCell({
    required this.cellKey,
    required this.lat,
    required this.lng,
    required this.score,
    required this.nivel,
    required this.nivelLabel,
    required this.color,
    required this.accion,
    required this.radiusMeters,
    required this.crashProbability,
    required this.crashProbabilityPct,
    required this.historicTotal,
    required this.historicCrashes,
    required this.recentWazeTotal,
    required this.recentChoques,
    required this.recentCierres,
    required this.lastEventAt,
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

  factory AgenteVialRiskCell.fromJson(Map<String, dynamic> json) {
    return AgenteVialRiskCell(
      cellKey: json['cell_key']?.toString() ?? '',
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      score: _asDouble(json['score']),
      nivel: json['nivel']?.toString() ?? 'latente',
      nivelLabel: json['nivel_label']?.toString() ?? 'Latente',
      color: json['color']?.toString() ?? '#2563EB',
      accion: json['accion']?.toString() ?? 'Observación preventiva',
      radiusMeters: _asDouble(json['radius_meters'], fallback: 260),
      crashProbability: _asDouble(json['crash_probability']),
      crashProbabilityPct: _asInt(json['crash_probability_pct']),
      historicTotal: _asInt(json['historic_total']),
      historicCrashes: _asInt(json['historic_crashes']),
      recentWazeTotal: _asInt(json['recent_waze_total']),
      recentChoques: _asInt(json['recent_choques']),
      recentCierres: _asInt(json['recent_cierres']),
      lastEventAt: json['last_event_at']?.toString(),
    );
  }
}

class AgenteVialHourlyBucket {
  final int hour;
  final String label;
  final int total;
  final int choques;

  const AgenteVialHourlyBucket({
    required this.hour,
    required this.label,
    required this.total,
    required this.choques,
  });

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  factory AgenteVialHourlyBucket.fromJson(Map<String, dynamic> json) {
    return AgenteVialHourlyBucket(
      hour: _asInt(json['hour']),
      label: json['label']?.toString() ?? '00:00',
      total: _asInt(json['total']),
      choques: _asInt(json['choques']),
    );
  }
}
