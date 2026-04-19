class AseguradorasVehiculo {
  static const List<String> opciones = [
    'Qualitas',
    'GNP',
    'AXA',
    'Banorte',
    'HDI',
    'Mapfre',
    'Zurich',
    'BBVA',
    'Afirme',
    'Inbursa',
    'Chubb',
    'Potosí',
    'General de Seguros',
    'ANA',
    'Primero Seguros',
    'Miituo',
    'AIG',
    'Insignia Life',
    'Thona Seguros',
    'Ve por Más Seguros (BX+)',
  ];

  static String? valueFromAny(String? input) {
    final normalized = _normalize(input ?? '');
    if (normalized.isEmpty) return null;

    for (final option in opciones) {
      if (_normalize(option) == normalized) return option;
    }

    return null;
  }

  static String _normalize(String value) {
    var text = value.trim().toUpperCase();
    if (text.isEmpty) return '';

    text = text
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N');
    text = text.replaceAll(RegExp(r'[^A-Z0-9]+'), '');
    return text;
  }
}
