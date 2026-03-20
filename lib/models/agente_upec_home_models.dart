class AgenteUpecHomeMapData {
  final double centerLat;
  final double centerLng;
  final double zoom;
  final String? generatedAt;
  final String? timezone;
  final int total;
  final int choques;
  final int cierres;
  final List<AgenteUpecAlert> alerts;

  const AgenteUpecHomeMapData({
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.generatedAt,
    required this.timezone,
    required this.total,
    required this.choques,
    required this.cierres,
    required this.alerts,
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

  factory AgenteUpecHomeMapData.fromJson(Map<String, dynamic> json) {
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

    final rawAlerts = layers['waze_alerts'];

    return AgenteUpecHomeMapData(
      centerLat: _asDouble(center['lat'], fallback: 19.70595),
      centerLng: _asDouble(center['lng'], fallback: -101.194983),
      zoom: _asDouble(map['zoom'], fallback: 13),
      generatedAt: meta['generated_at']?.toString(),
      timezone: meta['timezone']?.toString(),
      total: _asInt(counts['total']),
      choques: _asInt(counts['choques']),
      cierres: _asInt(counts['cierres']),
      alerts: rawAlerts is List
          ? rawAlerts
                .whereType<Map>()
                .map(
                  (item) =>
                      AgenteUpecAlert.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const <AgenteUpecAlert>[],
    );
  }
}

class AgenteUpecAlert {
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
  final double? distanceMeters;

  const AgenteUpecAlert({
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
    required this.distanceMeters,
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

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  factory AgenteUpecAlert.fromJson(Map<String, dynamic> json) {
    return AgenteUpecAlert(
      id: _asInt(json['id']),
      uuid: json['uuid']?.toString() ?? '',
      type: json['type']?.toString() ?? 'waze_accident',
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      title: json['title']?.toString() ?? 'Incidencia',
      subtitle: json['subtitle']?.toString() ?? 'Ubicación sin detalle',
      street: json['street']?.toString(),
      city: json['city']?.toString(),
      publishedAt: json['published_at']?.toString(),
      distanceMeters: _asNullableDouble(
        json['distance_meters'] ?? json['distance'],
      ),
    );
  }

  AgenteUpecAlert copyWith({double? distanceMeters}) {
    return AgenteUpecAlert(
      id: id,
      uuid: uuid,
      type: type,
      lat: lat,
      lng: lng,
      title: title,
      subtitle: subtitle,
      street: street,
      city: city,
      publishedAt: publishedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }
}
