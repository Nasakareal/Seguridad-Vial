import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/agente_upec_home_models.dart';
import 'auth_service.dart';

class AgenteUpecHomeService {
  static const int defaultWazeHours = 6;
  static const int defaultRadiusKm = 10;
  static const int defaultLimit = 40;

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String _parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map<String, dynamic>) {
        final message = raw['message']?.toString().trim() ?? '';
        if (message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }

  static Future<AgenteUpecHomeMapData> fetchMapa({
    double? lat,
    double? lng,
    int radiusKm = defaultRadiusKm,
    int limit = defaultLimit,
    int wazeHours = defaultWazeHours,
    String tipo = 'TODOS',
  }) async {
    final normalizedTipo = tipo.trim().toUpperCase();
    final uri = Uri.parse('${AuthService.baseUrl}/agente-upec-home/mapa')
        .replace(
          queryParameters: <String, String>{
            'radius_km': radiusKm.toString(),
            'limit': limit.toString(),
            'waze_hours': wazeHours.toString(),
            'tipo': normalizedTipo,
            if (lat != null) 'lat': lat.toString(),
            if (lng != null) 'lng': lng.toString(),
          },
        );

    final res = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception(_parseBackendError(res.body, res.statusCode));
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida al cargar incidencias cercanas.');
    }

    final mapData = AgenteUpecHomeMapData.fromJson(decoded);
    return _sortByDistance(mapData, lat: lat, lng: lng, limit: limit);
  }

  static AgenteUpecHomeMapData _sortByDistance(
    AgenteUpecHomeMapData mapData, {
    required double? lat,
    required double? lng,
    required int limit,
  }) {
    if (lat == null || lng == null) {
      return AgenteUpecHomeMapData(
        centerLat: mapData.centerLat,
        centerLng: mapData.centerLng,
        zoom: mapData.zoom,
        generatedAt: mapData.generatedAt,
        timezone: mapData.timezone,
        total: mapData.total,
        choques: mapData.choques,
        cierres: mapData.cierres,
        alerts: mapData.alerts.take(limit).toList(),
      );
    }

    final sorted =
        mapData.alerts.map((alert) {
          final distance =
              alert.distanceMeters ??
              Geolocator.distanceBetween(lat, lng, alert.lat, alert.lng);
          return alert.copyWith(distanceMeters: distance);
        }).toList()..sort((a, b) {
          final da = a.distanceMeters ?? double.infinity;
          final db = b.distanceMeters ?? double.infinity;
          return da.compareTo(db);
        });

    return AgenteUpecHomeMapData(
      centerLat: lat,
      centerLng: lng,
      zoom: mapData.zoom,
      generatedAt: mapData.generatedAt,
      timezone: mapData.timezone,
      total: mapData.total,
      choques: mapData.choques,
      cierres: mapData.cierres,
      alerts: sorted.take(limit).toList(),
    );
  }
}
