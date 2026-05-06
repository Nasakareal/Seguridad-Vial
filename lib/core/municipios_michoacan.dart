class MunicipiosMichoacan {
  const MunicipiosMichoacan._();

  static const List<String> options = <String>[
    'ACUITZIO',
    'AGUILILLA',
    'ALVARO OBREGON',
    'ANGAMACUTIRO',
    'ANGANGUEO',
    'APATZINGAN',
    'APORO',
    'AQUILA',
    'ARIO',
    'ARTEAGA',
    'BRISENAS',
    'BUENAVISTA',
    'CARACUARO',
    'COAHUAYANA',
    'COALCOMAN DE VAZQUEZ PALLARES',
    'COENEO',
    'CONTEPEC',
    'COPANDARO',
    'COTIJA',
    'CUITZEO',
    'CHARAPAN',
    'CHARO',
    'CHAVINDA',
    'CHERAN',
    'CHILCHOTA',
    'CHINICUILA',
    'CHUCANDIRO',
    'CHURINTZIO',
    'CHURUMUCO',
    'ECUANDUREO',
    'EPITACIO HUERTA',
    'ERONGARICUARO',
    'GABRIEL ZAMORA',
    'HIDALGO',
    'LA HUACANA',
    'HUANDACAREO',
    'HUANIQUEO',
    'HUETAMO',
    'HUIRAMBA',
    'INDAPARAPEO',
    'IRIMBO',
    'IXTLAN',
    'JACONA',
    'JIMENEZ',
    'JIQUILPAN',
    'JOSE SIXTO VERDUZCO',
    'JUAREZ',
    'JUNGAPEO',
    'LAGUNILLAS',
    'MADERO',
    'MARAVATIO',
    'MARCOS CASTELLANOS',
    'LAZARO CARDENAS',
    'MORELIA',
    'MORELOS',
    'MUGICA',
    'NAHUATZEN',
    'NOCUPETARO',
    'NUEVO PARANGARICUTIRO',
    'NUEVO URECHO',
    'NUMARAN',
    'OCAMPO',
    'PAJACUARAN',
    'PANINDICUARO',
    'PARACUARO',
    'PARACHO',
    'PATZCUARO',
    'PENJAMILLO',
    'PERIBAN',
    'LA PIEDAD',
    'PUREPERO',
    'PURUANDIRO',
    'QUERENDARO',
    'QUIROGA',
    'COJUMATLAN DE REGULES',
    'LOS REYES',
    'SAHUAYO',
    'SAN LUCAS',
    'SANTA ANA MAYA',
    'SALVADOR ESCALANTE',
    'SENGUIO',
    'SUSUPUATO',
    'TACAMBARO',
    'TANCITARO',
    'TANGAMANDAPIO',
    'TANGANCICUARO',
    'TANHUATO',
    'TARETAN',
    'TARIMBARO',
    'TEPALCATEPEC',
    'TINGAMBATO',
    'TINGUINDIN',
    'TIQUICHEO DE NICOLAS ROMERO',
    'TLALPUJAHUA',
    'TLAZAZALCA',
    'TOCUMBO',
    'TUMBISCATIO',
    'TURICATO',
    'TUXPAN',
    'TUZANTLA',
    'TZINTZUNTZAN',
    'TZITZIO',
    'URUAPAN',
    'VENUSTIANO CARRANZA',
    'VILLAMAR',
    'VISTA HERMOSA',
    'YURECUARO',
    'ZACAPU',
    'ZAMORA',
    'ZINAPARO',
    'ZINAPECUARO',
    'ZIRACUARETIRO',
    'ZITACUARO',
  ];

  static const Map<String, String> _aliases = <String, String>{
    'BUENAVISTA': 'BUENAVISTA',
    'BUENAVISTATOMATLAN': 'BUENAVISTA',
    'BUENAVISTATOMICHLAN': 'BUENAVISTA',
    'BUENAVISTA TOMATLAN': 'BUENAVISTA',
    'BUENAVISTATOMATLANMICHOACAN': 'BUENAVISTA',
    'BUENAVISTA TOMATLAN MICHOACAN': 'BUENAVISTA',
    'BUENAVISTA TOMATLAN MICHOACAN DE OCAMPO': 'BUENAVISTA',
    'BUENAVISTA TOMATLAN MICH': 'BUENAVISTA',
    'BUENAVISTAMICH': 'BUENAVISTA',
    'BUENA VISTA': 'BUENAVISTA',
    'BUENAVISTA MICHOACAN': 'BUENAVISTA',
    'HUACANA LA': 'LA HUACANA',
    'HUACANALA': 'LA HUACANA',
    'LAPIEDAD': 'LA PIEDAD',
    'PIEDAD LA': 'LA PIEDAD',
    'PIEDADLA': 'LA PIEDAD',
    'REYES LOS': 'LOS REYES',
    'REYESLOS': 'LOS REYES',
    'LOSCREYES': 'LOS REYES',
    'MUNICIPIODEMORELIA': 'MORELIA',
    'MORELIAMICHOACAN': 'MORELIA',
    'MORELIAMICH': 'MORELIA',
    'MUJICA': 'MUGICA',
    'MUGICAMICHOACAN': 'MUGICA',
    'SANLUCASMICH': 'SAN LUCAS',
    'SANTAANAMAYAMICH': 'SANTA ANA MAYA',
    'SANTACLARA': 'SALVADOR ESCALANTE',
    'SANTACLARADELCOBRE': 'SALVADOR ESCALANTE',
    'SANTACLARADELCOBREMICHOACAN': 'SALVADOR ESCALANTE',
  };

  static final Map<String, String> _byToken = <String, String>{
    for (final option in options) normalizeToken(option): option,
    for (final entry in _aliases.entries)
      normalizeToken(entry.key): entry.value,
  };

  static String? canonical(dynamic value) {
    final token = normalizeToken(value);
    if (token.isEmpty) return null;

    final direct = _byToken[token];
    if (direct != null) return direct;

    for (final suffix in const <String>[
      'MICHOACANDEOCAMPO',
      'MICHOACAN',
      'MICH',
    ]) {
      if (token.endsWith(suffix) && token.length > suffix.length) {
        final stripped = token.substring(0, token.length - suffix.length);
        final match = _byToken[stripped];
        if (match != null) return match;
      }
    }

    return null;
  }

  static List<String> search(String query, {int limit = 14}) {
    final token = normalizeToken(query);
    if (token.isEmpty) return options;

    final startsWith = <String>[];
    final contains = <String>[];

    for (final option in options) {
      final optionToken = normalizeToken(option);
      if (optionToken.startsWith(token)) {
        startsWith.add(option);
      } else if (optionToken.contains(token)) {
        contains.add(option);
      }
    }

    final matches = <String>[...startsWith, ...contains];
    if (matches.length <= limit) return matches;
    return matches.take(limit).toList();
  }

  static bool isKnown(dynamic value) => canonical(value) != null;

  static String normalizeToken(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return '';

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
