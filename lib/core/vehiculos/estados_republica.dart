class EstadosRepublica {
  static const List<Map<String, String>> estados = [
    {'value': 'AGUASCALIENTES', 'label': 'Aguascalientes'},
    {'value': 'BAJA_CALIFORNIA', 'label': 'Baja California'},
    {'value': 'BAJA_CALIFORNIA_SUR', 'label': 'Baja California Sur'},
    {'value': 'CAMPECHE', 'label': 'Campeche'},
    {'value': 'CHIAPAS', 'label': 'Chiapas'},
    {'value': 'CHIHUAHUA', 'label': 'Chihuahua'},
    {'value': 'CIUDAD_DE_MEXICO', 'label': 'Ciudad de México'},
    {'value': 'COAHUILA', 'label': 'Coahuila'},
    {'value': 'COLIMA', 'label': 'Colima'},
    {'value': 'DURANGO', 'label': 'Durango'},
    {'value': 'GUANAJUATO', 'label': 'Guanajuato'},
    {'value': 'GUERRERO', 'label': 'Guerrero'},
    {'value': 'HIDALGO', 'label': 'Hidalgo'},
    {'value': 'JALISCO', 'label': 'Jalisco'},
    {'value': 'MEXICO', 'label': 'Estado de México'},
    {'value': 'MICHOACAN', 'label': 'Michoacán'},
    {'value': 'MORELOS', 'label': 'Morelos'},
    {'value': 'NAYARIT', 'label': 'Nayarit'},
    {'value': 'NUEVO_LEON', 'label': 'Nuevo León'},
    {'value': 'OAXACA', 'label': 'Oaxaca'},
    {'value': 'PUEBLA', 'label': 'Puebla'},
    {'value': 'QUERETARO', 'label': 'Querétaro'},
    {'value': 'QUINTANA_ROO', 'label': 'Quintana Roo'},
    {'value': 'SAN_LUIS_POTOSI', 'label': 'San Luis Potosí'},
    {'value': 'SINALOA', 'label': 'Sinaloa'},
    {'value': 'SONORA', 'label': 'Sonora'},
    {'value': 'TABASCO', 'label': 'Tabasco'},
    {'value': 'TAMAULIPAS', 'label': 'Tamaulipas'},
    {'value': 'TLAXCALA', 'label': 'Tlaxcala'},
    {'value': 'VERACRUZ', 'label': 'Veracruz'},
    {'value': 'YUCATAN', 'label': 'Yucatán'},
    {'value': 'ZACATECAS', 'label': 'Zacatecas'},
  ];

  static const List<String> values = [
    'AGUASCALIENTES',
    'BAJA_CALIFORNIA',
    'BAJA_CALIFORNIA_SUR',
    'CAMPECHE',
    'CHIAPAS',
    'CHIHUAHUA',
    'CIUDAD_DE_MEXICO',
    'COAHUILA',
    'COLIMA',
    'DURANGO',
    'GUANAJUATO',
    'GUERRERO',
    'HIDALGO',
    'JALISCO',
    'MEXICO',
    'MICHOACAN',
    'MORELOS',
    'NAYARIT',
    'NUEVO_LEON',
    'OAXACA',
    'PUEBLA',
    'QUERETARO',
    'QUINTANA_ROO',
    'SAN_LUIS_POTOSI',
    'SINALOA',
    'SONORA',
    'TABASCO',
    'TAMAULIPAS',
    'TLAXCALA',
    'VERACRUZ',
    'YUCATAN',
    'ZACATECAS',
  ];

  static String? labelFromValue(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final v = value.trim().toUpperCase();
    for (final e in estados) {
      if ((e['value'] ?? '') == v) return e['label'];
    }
    return null;
  }

  static String? valueFromAny(String? input) {
    final s = (input ?? '').trim();
    if (s.isEmpty) return null;

    final up = s.toUpperCase();

    for (final e in estados) {
      if ((e['value'] ?? '') == up) return e['value'];
    }

    String norm(String x) {
      var t = x.toUpperCase().trim();
      t = t.replaceAll(RegExp(r'[\s\-\._,]+'), '_');
      t = t.replaceAll('Á', 'A');
      t = t.replaceAll('É', 'E');
      t = t.replaceAll('Í', 'I');
      t = t.replaceAll('Ó', 'O');
      t = t.replaceAll('Ú', 'U');
      t = t.replaceAll('Ü', 'U');
      t = t.replaceAll('Ñ', 'N');
      t = t.replaceAll(RegExp(r'_+'), '_');
      return t;
    }

    final n = norm(s);

    if (n == 'CDMX' || n == 'CIUDAD_DE_MEXICO' || n == 'DISTRITO_FEDERAL') {
      return 'CIUDAD_DE_MEXICO';
    }
    if (n == 'EDOMEX' || n == 'ESTADO_DE_MEXICO') {
      return 'MEXICO';
    }
    if (n == 'NUEVOLEON') return 'NUEVO_LEON';
    if (n == 'SANLUISPOTOSI') return 'SAN_LUIS_POTOSI';
    if (n == 'BAJACALIFORNIA') return 'BAJA_CALIFORNIA';
    if (n == 'BAJACALIFORNIASUR') return 'BAJA_CALIFORNIA_SUR';
    if (n == 'QUINTANAROO') return 'QUINTANA_ROO';

    for (final e in estados) {
      final ev = (e['value'] ?? '');
      if (ev == n) return ev;

      final el = norm(e['label'] ?? '');
      if (el == n) return ev;
    }

    return null;
  }
}
