class DelegacionesHomeMapData {
  static const Duration maxWazeAge = Duration(minutes: 30);

  final double centerLat;
  final double centerLng;
  final double zoom;
  final String? generatedAt;
  final String? timezone;
  final bool fallbackOnly;
  final List<DelegacionesRiskZone> riskZones;
  final List<DelegacionesWazeAlert> wazeAlerts;

  const DelegacionesHomeMapData({
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.generatedAt,
    required this.timezone,
    required this.fallbackOnly,
    required this.riskZones,
    required this.wazeAlerts,
  });

  int get riskZonesCount => riskZones.length;
  int get wazeAlertsCount => wazeAlerts.length;
  int get choques => wazeAlerts.where((alert) => alert.isAccident).length;
  int get cierres => wazeAlerts.where((alert) => alert.isClosure).length;
  int get trafico => wazeAlerts.where((alert) => alert.isJam).length;

  static const double fallbackLat = 19.70595;
  static const double fallbackLng = -101.194983;

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<DelegacionesWazeAlert> _recentWazeAlerts(
    List<DelegacionesWazeAlert> alerts,
  ) {
    final now = DateTime.now();
    return alerts
        .where((alert) => alert.isRecent(maxWazeAge, now: now))
        .toList();
  }

  DelegacionesHomeMapData copyWith({
    double? centerLat,
    double? centerLng,
    double? zoom,
    String? generatedAt,
    String? timezone,
    bool? fallbackOnly,
    List<DelegacionesRiskZone>? riskZones,
    List<DelegacionesWazeAlert>? wazeAlerts,
  }) {
    return DelegacionesHomeMapData(
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      zoom: zoom ?? this.zoom,
      generatedAt: generatedAt ?? this.generatedAt,
      timezone: timezone ?? this.timezone,
      fallbackOnly: fallbackOnly ?? this.fallbackOnly,
      riskZones: riskZones ?? this.riskZones,
      wazeAlerts: wazeAlerts ?? this.wazeAlerts,
    );
  }

  factory DelegacionesHomeMapData.empty() {
    return DelegacionesHomeMapData(
      centerLat: fallbackLat,
      centerLng: fallbackLng,
      zoom: 12.5,
      generatedAt: null,
      timezone: null,
      fallbackOnly: true,
      riskZones: const <DelegacionesRiskZone>[],
      wazeAlerts: const <DelegacionesWazeAlert>[],
    );
  }

  factory DelegacionesHomeMapData.fromJson(Map<String, dynamic> json) {
    final map = _asMap(json['map']);
    final center = _asMap(map['center']);
    final meta = _asMap(json['meta']);
    final layers = _asMap(json['layers']);

    var riskZones = _asMapList(layers['risk_zones'])
        .map(DelegacionesRiskZone.fromRiskZoneJson)
        .where((zone) => zone.hasValidLocation)
        .toList();

    if (riskZones.isEmpty) {
      riskZones = _asMapList(json['riesgo_cells'])
          .map(DelegacionesRiskZone.fromPredictiveCellJson)
          .where((zone) => zone.hasValidLocation)
          .toList();
    }

    if (riskZones.isEmpty) {
      riskZones = _asMapList(json['data'])
          .map(DelegacionesRiskZone.fromIncidenciasClusterJson)
          .where((zone) => zone.hasValidLocation)
          .toList();
    }

    var wazeAlerts = _asMapList(layers['waze_alerts'])
        .map(DelegacionesWazeAlert.fromJson)
        .where((alert) => alert.hasValidLocation)
        .toList();

    if (wazeAlerts.isEmpty) {
      wazeAlerts = _asMapList(json['waze_points'])
          .map(DelegacionesWazeAlert.fromJson)
          .where((alert) => alert.hasValidLocation)
          .toList();
    }
    wazeAlerts = _recentWazeAlerts(wazeAlerts);

    final firstWaze = wazeAlerts.isNotEmpty ? wazeAlerts.first : null;
    final firstRisk = riskZones.isNotEmpty ? riskZones.first : null;

    final centerLat = _asDouble(
      center['lat'],
      fallback: firstWaze?.lat ?? firstRisk?.centerLat ?? fallbackLat,
    );
    final centerLng = _asDouble(
      center['lng'],
      fallback: firstWaze?.lng ?? firstRisk?.centerLng ?? fallbackLng,
    );

    return DelegacionesHomeMapData(
      centerLat: centerLat,
      centerLng: centerLng,
      zoom: _asDouble(map['zoom'], fallback: 12.5),
      generatedAt: meta['generated_at']?.toString(),
      timezone: meta['timezone']?.toString(),
      fallbackOnly: false,
      riskZones: riskZones,
      wazeAlerts: wazeAlerts,
    );
  }

  factory DelegacionesHomeMapData.fromIncidenciasJson(
    Map<String, dynamic> json,
  ) {
    final riskZones = _asMapList(json['data'])
        .map(DelegacionesRiskZone.fromIncidenciasClusterJson)
        .where((zone) => zone.hasValidLocation)
        .toList();

    final firstRisk = riskZones.isNotEmpty ? riskZones.first : null;

    return DelegacionesHomeMapData(
      centerLat: firstRisk?.centerLat ?? fallbackLat,
      centerLng: firstRisk?.centerLng ?? fallbackLng,
      zoom: 12.5,
      generatedAt: DateTime.now().toIso8601String(),
      timezone: null,
      fallbackOnly: true,
      riskZones: riskZones,
      wazeAlerts: const <DelegacionesWazeAlert>[],
    );
  }
}

class DelegacionesRiskZone {
  final double centerLat;
  final double centerLng;
  final double score;
  final int totalHechos;
  final int wazeTotal;
  final String severity;
  final String label;
  final String? action;
  final String? lastEventAt;
  final String strokeColor;
  final String fillColor;
  final double radiusMeters;

  const DelegacionesRiskZone({
    required this.centerLat,
    required this.centerLng,
    required this.score,
    required this.totalHechos,
    required this.wazeTotal,
    required this.severity,
    required this.label,
    required this.action,
    required this.lastEventAt,
    required this.strokeColor,
    required this.fillColor,
    required this.radiusMeters,
  });

  bool get hasValidLocation => centerLat != 0 && centerLng != 0;

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

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

  static String _severityLabel(String severity) {
    switch (severity) {
      case 'critico':
        return 'Riesgo critico';
      case 'alto':
      case 'alta':
        return 'Riesgo alto';
      case 'muy_alta':
        return 'Riesgo muy alto';
      case 'vigilancia':
        return 'Vigilancia';
      default:
        return 'Observacion';
    }
  }

  static String _colorForSeverity(String severity) {
    switch (severity) {
      case 'critico':
      case 'muy_alta':
        return '#E11D48';
      case 'alto':
      case 'alta':
        return '#F97316';
      case 'vigilancia':
        return '#0EA5E9';
      default:
        return '#22C55E';
    }
  }

  static double _radiusFromScore(double score, int total) {
    final base = 180 + (score.clamp(0, 100) * 5);
    final byTotal = 160 + (total.clamp(0, 30) * 22);
    final radius = base > byTotal ? base : byTotal.toDouble();
    return radius.clamp(220, 760).toDouble();
  }

  factory DelegacionesRiskZone.fromRiskZoneJson(Map<String, dynamic> json) {
    final style = _asMap(json['style']);
    final severity = (json['severity'] ?? 'alta').toString();
    final score = _asDouble(json['score']);
    final total = _asInt(json['total_hechos'] ?? json['total']);
    final color =
        style['stroke_color']?.toString() ?? _colorForSeverity(severity);

    return DelegacionesRiskZone(
      centerLat: _asDouble(json['center_lat'] ?? json['lat']),
      centerLng: _asDouble(json['center_lng'] ?? json['lng']),
      score: score,
      totalHechos: total,
      wazeTotal: _asInt(json['waze_total']),
      severity: severity,
      label: json['label']?.toString() ?? _severityLabel(severity),
      action: json['accion']?.toString(),
      lastEventAt: json['last_event_at']?.toString(),
      strokeColor: color,
      fillColor: style['fill_color']?.toString() ?? color,
      radiusMeters: _asDouble(
        json['radius_meters'],
        fallback: _radiusFromScore(score, total),
      ),
    );
  }

  factory DelegacionesRiskZone.fromPredictiveCellJson(
    Map<String, dynamic> json,
  ) {
    final severity = (json['nivel'] ?? 'latente').toString();
    final score = _asDouble(json['score']);
    final total = _asInt(json['hechos_hist'] ?? json['total']);
    final color = json['color']?.toString() ?? _colorForSeverity(severity);

    return DelegacionesRiskZone(
      centerLat: _asDouble(json['lat']),
      centerLng: _asDouble(json['lng']),
      score: score,
      totalHechos: total,
      wazeTotal:
          _asInt(json['waze_total']) +
          _asInt(json['jams_now']) +
          _asInt(json['accidents_now']),
      severity: severity,
      label: json['nivel_label']?.toString() ?? _severityLabel(severity),
      action: json['accion']?.toString(),
      lastEventAt:
          json['last_waze_at']?.toString() ?? json['last_match_at']?.toString(),
      strokeColor: color,
      fillColor: color,
      radiusMeters: _radiusFromScore(score, total),
    );
  }

  factory DelegacionesRiskZone.fromIncidenciasClusterJson(
    Map<String, dynamic> json,
  ) {
    final severity = (json['categoria'] ?? 'base').toString();
    final total = _asInt(json['total']);
    final score = _asDouble(json['score'], fallback: total.toDouble());
    final color = _colorForSeverity(
      severity == 'critico'
          ? 'critico'
          : (severity == 'alerta' ? 'alto' : 'vigilancia'),
    );

    return DelegacionesRiskZone(
      centerLat: _asDouble(json['lat']),
      centerLng: _asDouble(json['lng']),
      score: score,
      totalHechos: total,
      wazeTotal: 0,
      severity: severity,
      label: total == 1 ? '1 incidencia' : '$total incidencias',
      action: null,
      lastEventAt: json['fecha_max']?.toString(),
      strokeColor: color,
      fillColor: color,
      radiusMeters: _radiusFromScore(score, total),
    );
  }
}

class DelegacionesWazeAlert {
  final int id;
  final String uuid;
  final String type;
  final String subtype;
  final double lat;
  final double lng;
  final String title;
  final String subtitle;
  final String? street;
  final String? city;
  final String? publishedAt;

  const DelegacionesWazeAlert({
    required this.id,
    required this.uuid,
    required this.type,
    required this.subtype,
    required this.lat,
    required this.lng,
    required this.title,
    required this.subtitle,
    required this.street,
    required this.city,
    required this.publishedAt,
  });

  bool get hasValidLocation => lat != 0 && lng != 0;

  bool get isClosure {
    final raw = '$type $subtype'.toUpperCase();
    return raw.contains('ROAD_CLOSED') || raw.contains('CLOSED');
  }

  bool get isJam {
    final raw = '$type $subtype'.toUpperCase();
    return raw.contains('JAM') || raw.contains('TRAFFIC');
  }

  bool get isAccident {
    final raw = '$type $subtype'.toUpperCase();
    return raw.contains('ACCIDENT') ||
        raw.contains('CRASH') ||
        raw.contains('CHOQUE');
  }

  DateTime? get publishedDate {
    final value = publishedAt?.trim() ?? '';
    if (value.isEmpty) return null;

    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool isRecent(Duration maxAge, {DateTime? now}) {
    final published = publishedDate;
    if (published == null) return false;

    final reference = now ?? DateTime.now();
    return !published.isBefore(reference.subtract(maxAge)) &&
        !published.isAfter(reference.add(const Duration(minutes: 3)));
  }

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

  static String _fallbackTitle(String type, String subtype) {
    final alert = DelegacionesWazeAlert(
      id: 0,
      uuid: '',
      type: type,
      subtype: subtype,
      lat: 0,
      lng: 0,
      title: '',
      subtitle: '',
      street: null,
      city: null,
      publishedAt: null,
    );

    if (alert.isClosure) return 'CIERRE WAZE';
    if (alert.isAccident) return 'CHOQUE WAZE';
    if (alert.isJam) return 'TRAFICO WAZE';
    return 'INCIDENCIA WAZE';
  }

  factory DelegacionesWazeAlert.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? json['waze_type'] ?? '').toString();
    final subtype = (json['subtype'] ?? json['waze_subtype'] ?? '').toString();
    final street = (json['street'] ?? json['street_norm'])?.toString();
    final city = json['city']?.toString();
    final subtitle = json['subtitle']?.toString().trim().isNotEmpty == true
        ? json['subtitle'].toString()
        : ((street ?? '').trim().isNotEmpty
              ? street!
              : ((city ?? '').trim().isNotEmpty
                    ? city!
                    : 'Ubicacion sin calle'));

    return DelegacionesWazeAlert(
      id: _asInt(json['id']),
      uuid: json['uuid']?.toString() ?? '',
      type: type,
      subtype: subtype,
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      title: json['title']?.toString() ?? _fallbackTitle(type, subtype),
      subtitle: subtitle,
      street: street,
      city: city,
      publishedAt:
          json['published_at']?.toString() ?? json['created_at']?.toString(),
    );
  }
}
