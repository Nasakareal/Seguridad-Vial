class HechosCatalogos {
  static const List<String> sectoresUi = [
    'REVOLUCIÓN',
    'NUEVA ESPAÑA',
    'INDEPENDENCIA',
    'REPÚBLICA',
    'CENTRO',
  ];

  static const List<String> tiemposUi = [
    'Día',
    'Noche',
    'Amanecer',
    'Atardecer',
  ];

  static const List<String> climasUi = ['Bueno', 'Malo', 'Nublado', 'Lluvioso'];

  static const List<String> condicionesUi = ['Bueno', 'Regular', 'Malo'];

  static const List<String> situaciones = [
    'RESUELTO',
    'PENDIENTE',
    'TURNADO',
    'REPORTE',
  ];

  static const List<String> tiposHecho = [
    'VOLCADURA',
    'SALIDA DE SUPERFICIE DE RODAMIENTO',
    'SUBIDA AL CAMELLÓN',
    'CAIDA DE MOTOCICLETA',
    'COLISIÓN CON PEATÓN',
    'COLISIÓN POR ALCANCE',
    'COLISIÓN POR NO RESPETAR SEMÁFORO',
    'COLISIÓN POR INVASIÓN DE CARRIL',
    'COLISIÓN POR CORTE DE CIRCULACIÓN',
    'COLISIÓN POR CAMBIO DE CARRIL',
    'COLISIÓN POR MANIOBRA DE REVERSA',
    'COLISIÓN CONTRA OBJETO FIJO',
    'CAIDA ACUATICA DE VEHÍCULO',
    'DESBARRANCAMIENTO',
    'INCENDIO',
    'EXPLOSIÓN',
  ];

  // -----------------------------
  // NUEVOS SELECTS
  // -----------------------------

  static const List<String> superficiesViaUi = [
    'Asfalto',
    'Concreto',
    'Adoquín',
    'Terracería',
    'Empedrado',
    'Grava',
  ];

  static const List<String> controlesTransitoUi = [
    'Semáforo',
    'Señalamiento vertical',
    'Marca vial',
    'Agente de tránsito',
    'Reductor de velocidad',
    'Glorieta',
    'Ninguno',
  ];

  static const List<String> causasUi = [
    'Velocidad mayor de la permitida',
    'No conservar distancia',
    'Corte de circulación',
    'Invasión de carril',
    'No respetar semáforo',
    'Maniobra de reversa',
    'Derecho de vía',
    'No asegurar vehículo',
    'Cambio de carril',
    'Falla mecánica',
    'Condiciones de la vía',
    'No calcular dimensiones',
    'Pérdida de control',
    'No ceder el paso al peatón',
  ];

  static const List<String> colisionCaminoUi = [
    'Vehículos',
    'Semovientes',
    'Objeto fijo',
    'Peatón',
    'Bicicleta',
  ];

  static const List<String> responsablesUi = [
    'Vehículo A',
    'Vehículo B',
    'Vehículo C',
    'Vehículo D',
    'Vehículo E',
    'Vehículo F',
  ];

  // -----------------------------
  // NORMALIZADORES
  // -----------------------------

  static String normalizeSector(String v) {
    final x = v.trim().toUpperCase();
    switch (x) {
      case 'REVOLUCIÓN':
      case 'REVOLUCION':
        return 'REVOLUCION';
      case 'NUEVA ESPAÑA':
      case 'NUEVA ESPANA':
        return 'NUEVA ESPANA';
      case 'REPÚBLICA':
      case 'REPUBLICA':
        return 'REPUBLICA';
      case 'INDEPENDENCIA':
        return 'INDEPENDENCIA';
      case 'CENTRO':
        return 'CENTRO';
      default:
        return removeAccents(x);
    }
  }

  static String normalizeTiempo(String v) {
    final x = removeAccents(v.trim().toUpperCase());
    if (x == 'DIA') return 'DIA';
    if (x == 'NOCHE') return 'NOCHE';
    if (x == 'AMANECER') return 'AMANECER';
    if (x == 'ATARDECER') return 'ATARDECER';
    return x;
  }

  static String normalizeClima(String v) {
    final x = removeAccents(v.trim().toUpperCase());
    if (x == 'BUENO') return 'BUENO';
    if (x == 'MALO') return 'MALO';
    if (x == 'NUBLADO') return 'NUBLADO';
    if (x == 'LLUVIOSO') return 'LLUVIOSO';
    return x;
  }

  static String normalizeCondiciones(String v) {
    final x = removeAccents(v.trim().toUpperCase());
    if (x == 'BUENO') return 'BUENO';
    if (x == 'REGULAR') return 'REGULAR';
    if (x == 'MALO') return 'MALO';
    return x;
  }

  static String normalizeSuperficieVia(String v) {
    return removeAccents(v.trim().toUpperCase());
  }

  static String normalizeControlTransito(String v) {
    return removeAccents(v.trim().toUpperCase());
  }

  static String normalizeCausa(String v) {
    return removeAccents(v.trim().toUpperCase());
  }

  static String normalizeColisionCamino(String v) {
    return removeAccents(v.trim().toUpperCase());
  }

  static String removeAccents(String s) {
    const map = {
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'À': 'A',
      'È': 'E',
      'Ì': 'I',
      'Ò': 'O',
      'Ù': 'U',
      'Â': 'A',
      'Ê': 'E',
      'Î': 'I',
      'Ô': 'O',
      'Û': 'U',
      'Ä': 'A',
      'Ë': 'E',
      'Ï': 'I',
      'Ö': 'O',
      'Ü': 'U',
      'Ñ': 'N',
      'Ç': 'C',
    };

    final up = s.toUpperCase();
    final sb = StringBuffer();
    for (final ch in up.split('')) {
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }
}
