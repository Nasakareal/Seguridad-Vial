class ColoresVehiculo {
  static const List<String> opciones = [
    'Blanco',
    'Blanco perla',
    'Negro',
    'Gris',
    'Gris Oxford',
    'Plata',
    'Rojo',
    'Vino',
    'Azul',
    'Azul marino',
    'Verde',
    'Verde oscuro',
    'Arena',
    'Beige',
    'Café',
    'Dorado',
    'Naranja',
    'Amarillo',
    'Morado',
    'Rosa',
    'Guinda',
    'Bronce',
    'Champagne',
  ];

  static String? valueFromAny(String? input) {
    final normalized = _normalize(input ?? '');
    if (normalized.isEmpty) return null;

    for (final option in opciones) {
      if (_normalize(option) == normalized) return option;
    }

    return null;
  }

  static String normalizeUnknown(String input) {
    final value = input.trim();
    if (value.isEmpty) return '';
    final known = valueFromAny(value);
    if (known != null) return known;
    return value;
  }

  static List<String> opcionesConActual(String actual) {
    final value = normalizeUnknown(actual);
    if (value.isEmpty || opciones.contains(value)) return opciones;
    return [value, ...opciones];
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
