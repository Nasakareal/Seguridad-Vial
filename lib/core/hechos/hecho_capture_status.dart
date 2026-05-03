class HechoCaptureStatus {
  const HechoCaptureStatus._();

  static List<String> detallesFaltantes(Map<String, dynamic> hecho) {
    final backendDetails = _detallesFaltantesDelBackend(hecho);
    if (backendDetails.isNotEmpty) return backendDetails;

    final detalles = <String>[];

    _appendGap(
      detalles,
      expected: _firstInt(hecho, const [
        'vehiculos_esperados',
        'vehiculosEsperados',
        'vehiculos_previstos',
        'vehiculosPrevistos',
      ]),
      captured: _vehiculosCapturados(hecho),
      singular: 'vehículo',
      plural: 'vehículos',
    );

    _appendGap(
      detalles,
      expected: _firstInt(hecho, const [
        'conductores_esperados',
        'conductoresEsperados',
        'conductores_previstos',
        'conductoresPrevistos',
      ]),
      captured: _conductoresCapturados(hecho),
      singular: 'conductor',
      plural: 'conductores',
    );

    _appendGap(
      detalles,
      expected: _firstInt(hecho, const [
        'lesionados_esperados',
        'lesionadosEsperados',
        'lesionados_previstos',
        'lesionadosPrevistos',
      ]),
      captured: _lesionadosCapturados(hecho),
      singular: 'lesionado',
      plural: 'lesionados',
    );

    return detalles;
  }

  static void _appendGap(
    List<String> detalles, {
    required int? expected,
    required int? captured,
    required String singular,
    required String plural,
  }) {
    if (expected == null || captured == null) return;

    final faltantes = expected - captured;
    if (faltantes <= 0) return;

    detalles.add(_formatCount(faltantes, singular, plural));
  }

  static int? _vehiculosCapturados(Map<String, dynamic> hecho) {
    return _firstInt(hecho, const [
          'vehiculos_capturados',
          'vehiculosCapturados',
          'vehiculos_registrados',
          'vehiculosRegistrados',
          'vehiculos_count',
          'vehiculosCount',
          'total_vehiculos',
          'totalVehiculos',
        ]) ??
        _collectionCount(hecho['vehiculos']);
  }

  static int? _conductoresCapturados(Map<String, dynamic> hecho) {
    final direct = _firstInt(hecho, const [
      'conductores_capturados',
      'conductoresCapturados',
      'conductores_registrados',
      'conductoresRegistrados',
      'conductores_count',
      'conductoresCount',
      'total_conductores',
      'totalConductores',
    ]);
    if (direct != null) return direct;

    final directCollection = _collectionCount(hecho['conductores']);
    if (directCollection != null) return directCollection;

    final vehiculos = _collectionItems(hecho['vehiculos']);
    if (vehiculos == null) return null;

    var total = 0;
    var foundConductorInfo = false;

    for (final item in vehiculos) {
      if (item is! Map) continue;
      final vehiculo = Map<String, dynamic>.from(item);
      final conductores = _collectionItems(vehiculo['conductores']);

      if (conductores != null) {
        foundConductorInfo = true;
        total += conductores.length;
        continue;
      }

      if (_hasConductor(vehiculo)) {
        foundConductorInfo = true;
        total++;
      }
    }

    return foundConductorInfo ? total : null;
  }

  static int? _lesionadosCapturados(Map<String, dynamic> hecho) {
    return _firstInt(hecho, const [
          'lesionados_capturados',
          'lesionadosCapturados',
          'lesionados_registrados',
          'lesionadosRegistrados',
          'lesionados_count',
          'lesionadosCount',
          'total_lesionados',
          'totalLesionados',
        ]) ??
        _collectionCount(hecho['lesionados']);
  }

  static List<String> _detallesFaltantesDelBackend(Map<String, dynamic> hecho) {
    final raw =
        hecho['captura_faltantes'] ??
        hecho['faltantes_captura'] ??
        hecho['faltantesCaptura'];

    if (raw is List) {
      return raw
          .map((item) => (item ?? '').toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (raw is! Map) return const [];

    final detalles = <String>[];
    raw.forEach((key, value) {
      final detail = _backendGapDetail(key.toString(), value);
      if (detail != null) detalles.add(detail);
    });

    return detalles;
  }

  static String? _backendGapDetail(String key, dynamic value) {
    final labels = _labelsForKey(key);
    final count = _parseInt(value);

    if (labels != null && count != null && count > 0) {
      return _formatCount(count, labels.$1, labels.$2);
    }

    final text = (value ?? '').toString().trim();
    if (count == null && text.isNotEmpty) return text;

    return null;
  }

  static (String, String)? _labelsForKey(String key) {
    final normalized = key
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '');

    if (normalized.contains('vehiculo')) return ('vehículo', 'vehículos');
    if (normalized.contains('conductor')) return ('conductor', 'conductores');
    if (normalized.contains('lesionado')) return ('lesionado', 'lesionados');

    return null;
  }

  static int? _firstInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (!map.containsKey(key)) continue;

      final parsed = _parseInt(map[key]);
      if (parsed != null) return parsed;
    }

    return null;
  }

  static int? _collectionCount(dynamic value) {
    final items = _collectionItems(value);
    if (items != null) return items.length;

    if (value is Map) {
      return _parseInt(value['count']) ??
          _parseInt(value['total']) ??
          _parseInt(value['length']);
    }

    return null;
  }

  static List<dynamic>? _collectionItems(dynamic value) {
    if (value is List) return value;

    if (value is Map) {
      final data = value['data'];
      if (data is List) return data;

      final items = value['items'];
      if (items is List) return items;
    }

    return null;
  }

  static bool _hasConductor(Map<String, dynamic> vehiculo) {
    final id = _firstInt(vehiculo, const ['conductor_id', 'conductorId']);
    if (id != null && id > 0) return true;

    for (final key in const [
      'conductor_nombre',
      'conductorNombre',
      'nombre_conductor',
      'nombreConductor',
    ]) {
      if (_hasText(vehiculo[key])) return true;
    }

    final conductor = vehiculo['conductor'];
    if (conductor is Map) {
      return conductor.values.any(_hasText);
    }

    return _hasText(conductor);
  }

  static bool _hasText(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isNotEmpty && text != '-' && text != '—';
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    return int.tryParse(text);
  }

  static String _formatCount(int count, String singular, String plural) {
    return '$count ${count == 1 ? singular : plural}';
  }
}
