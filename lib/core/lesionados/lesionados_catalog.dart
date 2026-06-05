class LesionadosCatalog {
  static const List<String> tiposVictima = <String>[
    'Conductor',
    'Pasajero',
    'Peatón',
    'Motociclista',
    'Ciclista',
  ];

  static String? tipoVictimaValue(dynamic value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return null;

    for (final option in tiposVictima) {
      if (_normalize(option) == normalized) return option;
    }

    return null;
  }

  static String _normalize(dynamic value) {
    return (value ?? '')
        .toString()
        .trim()
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N');
  }
}
