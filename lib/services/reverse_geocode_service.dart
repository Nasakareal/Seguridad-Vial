import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ReverseGeocodeResult {
  final String? municipio;
  final String? calle;
  final String? colonia;
  final String? ubicacionFormateada;
  final String? placeId;

  const ReverseGeocodeResult({
    required this.municipio,
    required this.calle,
    required this.colonia,
    required this.ubicacionFormateada,
    required this.placeId,
  });

  bool get hasUsefulAddress =>
      (municipio?.trim().isNotEmpty ?? false) ||
      (calle?.trim().isNotEmpty ?? false) ||
      (colonia?.trim().isNotEmpty ?? false);
}

class ReverseGeocodeService {
  static final Map<String, ReverseGeocodeResult> _memoryCache =
      <String, ReverseGeocodeResult>{};

  static Future<ReverseGeocodeResult> lookup({
    required double lat,
    required double lng,
  }) async {
    final cacheKey = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    final cached = _memoryCache[cacheKey];
    if (cached != null) return cached;

    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': lat.toStringAsFixed(7),
      'lon': lng.toStringAsFixed(7),
      'format': 'jsonv2',
      'addressdetails': '1',
      'zoom': '18',
      'accept-language': 'es-MX,es',
    });

    final response = await http
        .get(
          uri,
          headers: const <String, String>{
            'Accept': 'application/json',
            'Accept-Language': 'es-MX,es;q=0.9',
            'User-Agent': 'SeguridadVialApp/1.15.26 (reverse-geocode)',
          },
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception(
        'No se pudo resolver la dirección (${response.statusCode}).',
      );
    }

    final raw = jsonDecode(response.body);
    if (raw is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida al resolver la dirección.');
    }

    final result = _fromNominatim(raw);
    _memoryCache[cacheKey] = result;
    return result;
  }

  static ReverseGeocodeResult _fromNominatim(Map<String, dynamic> raw) {
    final address = raw['address'] is Map
        ? Map<String, dynamic>.from(raw['address'] as Map)
        : const <String, dynamic>{};
    final displayName = _cleanText(raw['display_name']);

    final municipio = _firstText(address, <String>[
      'city',
      'town',
      'municipality',
      'county',
      'city_district',
      'village',
      'state_district',
    ]);

    final calle = _firstText(address, <String>[
      'road',
      'pedestrian',
      'residential',
      'path',
      'footway',
      'cycleway',
    ]);

    final colonia = _extractColonia(
      address,
      displayName: displayName,
      calle: calle,
      municipio: municipio,
    );

    return ReverseGeocodeResult(
      municipio: municipio,
      calle: calle,
      colonia: colonia,
      ubicacionFormateada: displayName,
      placeId: _cleanText(raw['place_id']),
    );
  }

  static String? _extractColonia(
    Map<String, dynamic> address, {
    required String? displayName,
    required String? calle,
    required String? municipio,
  }) {
    final direct = _firstText(address, <String>[
      'suburb',
      'neighbourhood',
      'quarter',
      'borough',
      'residential',
      'city_district',
      'district',
      'hamlet',
    ]);
    final cleanedDirect = _cleanAreaName(direct);
    if (_isUsefulArea(cleanedDirect, calle: calle, municipio: municipio)) {
      return cleanedDirect;
    }

    if (displayName == null || displayName.isEmpty) return null;

    final ignored = <String>{
      _normalizeToken(calle),
      _normalizeToken(municipio),
      _normalizeToken(address['state']),
      _normalizeToken(address['country']),
      _normalizeToken(address['postcode']),
      _normalizeToken(address['road']),
      _normalizeToken(address['city']),
      _normalizeToken(address['town']),
      _normalizeToken(address['municipality']),
    }..removeWhere((item) => item.isEmpty);

    final parts = displayName
        .split(',')
        .map((part) => _cleanAreaName(part))
        .whereType<String>()
        .toList();

    for (final part in parts.skip(1)) {
      final normalized = _normalizeToken(part);
      if (normalized.isEmpty || ignored.contains(normalized)) continue;
      if (!_looksLikeArea(part)) continue;
      return part;
    }

    return null;
  }

  static String? _firstText(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = _cleanText(source[key]);
      if (value != null) return value;
    }
    return null;
  }

  static String? _cleanText(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _cleanAreaName(dynamic value) {
    final text = _cleanText(value);
    if (text == null) return null;

    final cleaned = text
        .replaceFirst(
          RegExp(
            r'^(colonia|col\.?|fracc\.?|fraccionamiento)\s+',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned.isEmpty ? null : cleaned;
  }

  static bool _isUsefulArea(
    String? value, {
    required String? calle,
    required String? municipio,
  }) {
    final normalized = _normalizeToken(value);
    if (normalized.isEmpty) return false;
    if (normalized == _normalizeToken(calle)) return false;
    if (normalized == _normalizeToken(municipio)) return false;
    return _looksLikeArea(value!);
  }

  static bool _looksLikeArea(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    if (text.length > 80) return false;

    final normalized = _normalizeToken(text);
    if (normalized.isEmpty) return false;
    if (RegExp(r'^\d+$').hasMatch(normalized)) return false;

    final lower = text.toLowerCase();
    if (lower == 'mexico' || lower == 'méxico') return false;
    if (lower == 'michoacan' || lower == 'michoacán') return false;

    return true;
  }

  static String _normalizeToken(dynamic value) {
    final text = _cleanText(value) ?? '';
    return text
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }
}
