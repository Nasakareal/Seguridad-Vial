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

    final municipio = _extractMunicipio(address, displayName: displayName);

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
      'municipality',
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
    }..removeWhere((item) => item.isEmpty);

    for (final key in <String>['city', 'town', 'county', 'municipality']) {
      final value = _cleanAreaName(address[key]);
      if (_isKnownMunicipio(value)) {
        ignored.add(_normalizeToken(value));
      }
    }

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

  static String? _extractMunicipio(
    Map<String, dynamic> address, {
    required String? displayName,
  }) {
    final candidates = <String>[
      'city',
      'town',
      'county',
      'municipality',
      'village',
      'state_district',
      'city_district',
    ];

    for (final key in candidates) {
      final value = _cleanText(address[key]);
      final canonical = _canonicalMunicipio(value);
      if (canonical != null) return canonical;
    }

    final displayParts = (displayName ?? '')
        .split(',')
        .map((part) => _cleanText(part))
        .whereType<String>();
    for (final part in displayParts) {
      final canonical = _canonicalMunicipio(part);
      if (canonical != null) return canonical;
    }

    return _firstText(address, candidates);
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

  static bool _isKnownMunicipio(String? value) {
    return _canonicalMunicipio(value) != null;
  }

  static String? _canonicalMunicipio(String? value) {
    final token = _normalizeToken(value);
    if (token.isEmpty) return null;
    return _municipiosMichoacan[token];
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

  static const Map<String, String> _municipiosMichoacan = {
    'ACUITZIO': 'ACUITZIO',
    'AGUILILLA': 'AGUILILLA',
    'ALVAROOBREGON': 'ALVARO OBREGON',
    'ANGAMACUTIRO': 'ANGAMACUTIRO',
    'ANGANGUEO': 'ANGANGUEO',
    'APATZINGAN': 'APATZINGAN',
    'APORO': 'APORO',
    'AQUILA': 'AQUILA',
    'ARIO': 'ARIO',
    'ARTEAGA': 'ARTEAGA',
    'BRISENAS': 'BRISENAS',
    'BUENAVISTA': 'BUENAVISTA',
    'CARACUARO': 'CARACUARO',
    'COAHUAYANA': 'COAHUAYANA',
    'COALCOMANDEVAZQUEZPALLARES': 'COALCOMAN DE VAZQUEZ PALLARES',
    'COENEO': 'COENEO',
    'CONTEPEC': 'CONTEPEC',
    'COPANDARO': 'COPANDARO',
    'COTIJA': 'COTIJA',
    'CUITZEO': 'CUITZEO',
    'CHARAPAN': 'CHARAPAN',
    'CHARO': 'CHARO',
    'CHAVINDA': 'CHAVINDA',
    'CHERAN': 'CHERAN',
    'CHILCHOTA': 'CHILCHOTA',
    'CHINICUILA': 'CHINICUILA',
    'CHUCANDIRO': 'CHUCANDIRO',
    'CHURINTZIO': 'CHURINTZIO',
    'CHURUMUCO': 'CHURUMUCO',
    'ECUANDUREO': 'ECUANDUREO',
    'EPITACIOHUERTA': 'EPITACIO HUERTA',
    'ERONGARICUARO': 'ERONGARICUARO',
    'GABRIELZAMORA': 'GABRIEL ZAMORA',
    'HIDALGO': 'HIDALGO',
    'LAHUACANA': 'LA HUACANA',
    'HUANDACAREO': 'HUANDACAREO',
    'HUANIQUEO': 'HUANIQUEO',
    'HUETAMO': 'HUETAMO',
    'HUIRAMBA': 'HUIRAMBA',
    'INDAPARAPEO': 'INDAPARAPEO',
    'IRIMBO': 'IRIMBO',
    'IXTLAN': 'IXTLAN',
    'JACONA': 'JACONA',
    'JIMENEZ': 'JIMENEZ',
    'JIQUILPAN': 'JIQUILPAN',
    'JOSE SIXTO VERDUZCO': 'JOSE SIXTO VERDUZCO',
    'JOSESIXTOVERDUZCO': 'JOSE SIXTO VERDUZCO',
    'JUAREZ': 'JUAREZ',
    'JUNGAPEO': 'JUNGAPEO',
    'LAGUNILLAS': 'LAGUNILLAS',
    'MADERO': 'MADERO',
    'MARAVATIO': 'MARAVATIO',
    'MARCOSCASTELLANOS': 'MARCOS CASTELLANOS',
    'LAZARO CARDENAS': 'LAZARO CARDENAS',
    'LAZAROCARDENAS': 'LAZARO CARDENAS',
    'MORELIA': 'MORELIA',
    'MORELOS': 'MORELOS',
    'MUGICA': 'MUGICA',
    'NAHUATZEN': 'NAHUATZEN',
    'NOCUPETARO': 'NOCUPETARO',
    'NUEVOPARANGARICUTIRO': 'NUEVO PARANGARICUTIRO',
    'NUEVOURECHO': 'NUEVO URECHO',
    'NUMARAN': 'NUMARAN',
    'OCAMPO': 'OCAMPO',
    'PAJACUARAN': 'PAJACUARAN',
    'PANINDICUARO': 'PANINDICUARO',
    'PARACUARO': 'PARACUARO',
    'PARACHO': 'PARACHO',
    'PATZCUARO': 'PATZCUARO',
    'PENJAMILLO': 'PENJAMILLO',
    'PERIBAN': 'PERIBAN',
    'LAPIEDAD': 'LA PIEDAD',
    'PUREPERO': 'PUREPERO',
    'PURUANDIRO': 'PURUANDIRO',
    'QUERENDARO': 'QUERENDARO',
    'QUIROGA': 'QUIROGA',
    'COJUMATLAN DE REGULES': 'COJUMATLAN DE REGULES',
    'COJUMATLANDEREGULES': 'COJUMATLAN DE REGULES',
    'LOSCREYES': 'LOS REYES',
    'SAHUAYO': 'SAHUAYO',
    'SANLUCAS': 'SAN LUCAS',
    'SANTACLARA': 'SANTA CLARA',
    'SALVADORESCALANTE': 'SALVADOR ESCALANTE',
    'SENGUIO': 'SENGUIO',
    'SUSUPUATO': 'SUSUPUATO',
    'TACAMBARO': 'TACAMBARO',
    'TANCITARO': 'TANCITARO',
    'TANGAMANDAPIO': 'TANGAMANDAPIO',
    'TANGANCICUARO': 'TANGANCICUARO',
    'TANHUATO': 'TANHUATO',
    'TARETAN': 'TARETAN',
    'TARIMBARO': 'TARIMBARO',
    'TEPALCATEPEC': 'TEPALCATEPEC',
    'TINGAMBATO': 'TINGAMBATO',
    'TINGUINDIN': 'TINGUINDIN',
    'TIQUICHEODE NICOLAS ROMERO': 'TIQUICHEO DE NICOLAS ROMERO',
    'TIQUICHEODENICOLASROMERO': 'TIQUICHEO DE NICOLAS ROMERO',
    'TLALPUJAHUA': 'TLALPUJAHUA',
    'TLAZAZALCA': 'TLAZAZALCA',
    'TOCUMBO': 'TOCUMBO',
    'TUMBISCATIO': 'TUMBISCATIO',
    'TURICATO': 'TURICATO',
    'TUXPAN': 'TUXPAN',
    'TUZANTLA': 'TUZANTLA',
    'TZINTZUNTZAN': 'TZINTZUNTZAN',
    'TZITZIO': 'TZITZIO',
    'URUAPAN': 'URUAPAN',
    'VENUSTIANOCARRANZA': 'VENUSTIANO CARRANZA',
    'VILLAMAR': 'VILLAMAR',
    'VISTAHERMOSA': 'VISTA HERMOSA',
    'YURECUARO': 'YURECUARO',
    'ZACAPU': 'ZACAPU',
    'ZAMORA': 'ZAMORA',
    'ZINAPARO': 'ZINAPARO',
    'ZINAPECUARO': 'ZINAPECUARO',
    'ZIRACUARETIRO': 'ZIRACUARETIRO',
    'ZITACUARO': 'ZITACUARO',
    'JOSEMARIA MORELOS': 'JOSE MARIA MORELOS',
    'JOSEMARIAMORELOS': 'JOSE MARIA MORELOS',
  };
}
