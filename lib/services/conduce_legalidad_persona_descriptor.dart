class ConduceLegalidadPersonaDescriptor {
  static const String _noApreciable = 'No apreciable';

  static const List<String> edadAproximadaOptions = <String>[
    'Menor de 12 anos',
    '12 a 17 anos',
    '18 a 24 anos',
    '25 a 34 anos',
    '35 a 44 anos',
    '45 a 54 anos',
    '55 a 64 anos',
    '65 anos o mas',
    'No apreciable',
  ];

  static const List<String> nacionalidadOptions = <String>[
    'Mexico',
    'America del Norte',
    'Centroamerica',
    'Sudamerica',
    'Europa',
    'Asia',
    'Africa',
    'Oceania',
    'No apreciable',
  ];

  static const List<String> complexionOptions = <String>[
    'No apreciable',
    'Delgada',
    'Media',
    'Robusta',
    'Atletica',
  ];

  static const List<String> estaturaOptions = <String>[
    'No apreciable',
    'Baja',
    'Media',
    'Alta',
  ];

  static const List<String> tezOptions = <String>[
    'No apreciable',
    'Clara',
    'Morena clara',
    'Morena',
    'Oscura',
  ];

  static const List<String> cabelloOptions = <String>[
    'No apreciable',
    'Corto',
    'Largo',
    'Lacio',
    'Ondulado',
    'Rizado',
    'Rapado',
    'Canoso',
    'Calvo',
    'Tenido',
  ];

  static const List<String> prendaSuperiorOptions = <String>[
    'No apreciable',
    'Playera',
    'Camisa',
    'Blusa',
    'Sudadera',
    'Chamarra',
    'Chaleco',
    'Uniforme',
    'Vestido',
  ];

  static const List<String> prendaInferiorOptions = <String>[
    'No apreciable',
    'Pantalon de mezclilla',
    'Pantalon de vestir',
    'Pants',
    'Short',
    'Bermuda',
    'Falda',
    'Vestido',
  ];

  static const List<String> calzadoOptions = <String>[
    'No apreciable',
    'Tenis',
    'Botas',
    'Zapatos',
    'Sandalias',
    'Huaraches',
    'Sin calzado',
  ];

  static const List<String> colorOptions = <String>[
    'No apreciable',
    'Negro',
    'Blanco',
    'Azul',
    'Rojo',
    'Gris',
    'Verde',
    'Cafe',
    'Beige',
    'Amarillo',
    'Naranja',
    'Morado',
    'Rosa',
    'Multicolor',
  ];

  static const String rasgoSinRasgos = 'Sin rasgos visibles';
  static const String rasgoNoApreciable = 'No apreciable';

  static const List<String> rasgosOptions = <String>[
    rasgoSinRasgos,
    rasgoNoApreciable,
    'Barba',
    'Bigote',
    'Tatuajes',
    'Cicatrices',
    'Lunares',
    'Perforaciones',
    'Lentes',
    'Aparatos dentales',
    'Lesion visible',
  ];

  static String? buildDescription({
    String? edadAproximada,
    String? complexion,
    String? estatura,
    String? tez,
    String? cabello,
    String? prendaSuperior,
    String? colorSuperior,
    String? prendaInferior,
    String? colorInferior,
    String? calzado,
    String? colorCalzado,
    Iterable<String> rasgos = const <String>[],
  }) {
    final lines = <String>[];

    final edad = _clean(edadAproximada);
    if (edad != null) {
      lines.add('Edad aproximada: $edad.');
    }

    final mediaFiliacion = <String>[
      if (_clean(complexion) != null) 'complexion ${_clean(complexion)}',
      if (_clean(estatura) != null) 'estatura ${_clean(estatura)}',
      if (_clean(tez) != null) 'tez ${_clean(tez)}',
      if (_clean(cabello) != null) 'cabello ${_clean(cabello)}',
    ];
    if (mediaFiliacion.isNotEmpty) {
      lines.add('Media filiacion: ${mediaFiliacion.join(', ')}.');
    }

    final vestimenta = <String>[
      if (_clothing(prendaSuperior, colorSuperior) != null)
        'parte superior ${_clothing(prendaSuperior, colorSuperior)}',
      if (_clothing(prendaInferior, colorInferior) != null)
        'parte inferior ${_clothing(prendaInferior, colorInferior)}',
      if (_clothing(calzado, colorCalzado) != null)
        'calzado ${_clothing(calzado, colorCalzado)}',
    ];
    if (vestimenta.isNotEmpty) {
      lines.add('Vestimenta: ${vestimenta.join('; ')}.');
    }

    final rasgosClean = _cleanRasgos(rasgos);
    if (rasgosClean.isNotEmpty) {
      lines.add('Rasgos visibles: ${rasgosClean.join(', ')}.');
    }

    return lines.isEmpty ? null : lines.join(' ');
  }

  static int? edadAproximadaToInt(String? edadAproximada) {
    switch (_clean(edadAproximada)) {
      case 'Menor de 12 anos':
        return 11;
      case '12 a 17 anos':
        return 15;
      case '18 a 24 anos':
        return 21;
      case '25 a 34 anos':
        return 30;
      case '35 a 44 anos':
        return 40;
      case '45 a 54 anos':
        return 50;
      case '55 a 64 anos':
        return 60;
      case '65 anos o mas':
        return 65;
    }
    return null;
  }

  static String? _clothing(String? garment, String? color) {
    final garmentText = _clean(garment);
    final colorText = _clean(color);
    final garmentUnknown = _isNoApreciable(garmentText);
    final colorUnknown = _isNoApreciable(colorText);
    if (garmentText == null && colorText == null) return null;
    if ((garmentText == null || garmentUnknown) &&
        (colorText == null || colorUnknown)) {
      return 'no apreciable';
    }
    if (garmentText == null || garmentUnknown) return 'color $colorText';
    if (colorText == null || colorUnknown) return garmentText;
    return '$garmentText color $colorText';
  }

  static List<String> _cleanRasgos(Iterable<String> rasgos) {
    final seen = <String>{};
    final clean = <String>[];
    for (final rasgo in rasgos) {
      final text = _clean(rasgo);
      if (text == null || !seen.add(text.toUpperCase())) continue;
      clean.add(text);
    }
    return clean;
  }

  static String? _clean(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }

  static bool _isNoApreciable(String? value) {
    return _clean(value)?.toUpperCase() == _noApreciable.toUpperCase();
  }
}
