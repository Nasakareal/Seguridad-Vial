class PuestaDisposicionItem {
  final int id;
  final String numeroPuesta;
  final int? anio;
  final String fechaPuesta;
  final String tipoPuesta;
  final String motivo;
  final String nombrePolicia;
  final String oficio;
  final int? unidadId;
  final int? delegacionId;
  final int? hechoId;

  const PuestaDisposicionItem({
    required this.id,
    required this.numeroPuesta,
    required this.anio,
    required this.fechaPuesta,
    required this.tipoPuesta,
    required this.motivo,
    required this.nombrePolicia,
    required this.oficio,
    required this.unidadId,
    required this.delegacionId,
    required this.hechoId,
  });

  factory PuestaDisposicionItem.fromMap(Map<String, dynamic> raw) {
    return PuestaDisposicionItem(
      id: _asInt(raw['id']) ?? 0,
      numeroPuesta: _asText(
        raw['numero_puesta'] ?? raw['numero'] ?? raw['folio'],
      ),
      anio: _asInt(raw['anio']),
      fechaPuesta: _asText(raw['fecha_puesta'] ?? raw['fecha']),
      tipoPuesta: _asText(raw['tipo_puesta'] ?? raw['tipo']),
      motivo: _asText(raw['motivo']),
      nombrePolicia: _asText(raw['nombre_policia'] ?? raw['policia']),
      oficio: _asText(raw['oficio']),
      unidadId: _readId(raw, 'unidad_id', 'unidad'),
      delegacionId: _readId(raw, 'delegacion_id', 'delegacion'),
      hechoId: _readId(raw, 'hecho_id', 'hecho'),
    );
  }

  bool get hasLinkedHecho => (hechoId ?? 0) > 0;

  String get title {
    final number = numeroPuesta.trim().isEmpty ? '#$id' : numeroPuesta.trim();
    final year = anio == null ? '' : '/$anio';
    return 'Puesta $number$year';
  }

  String get label {
    final parts = <String>[
      title,
      if (_displayDate(fechaPuesta).isNotEmpty) _displayDate(fechaPuesta),
      if (nombrePolicia.trim().isNotEmpty) nombrePolicia.trim(),
      if (motivo.trim().isNotEmpty) motivo.trim(),
    ];
    return parts.join(' - ');
  }

  String get detail {
    final parts = <String>[
      if (tipoPuesta.trim().isNotEmpty) tipoPuesta.trim(),
      if (oficio.trim().isNotEmpty) 'Oficio ${oficio.trim()}',
      if (hasLinkedHecho) 'Hecho #$hechoId',
    ];
    return parts.join(' - ');
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static String _asText(dynamic value) {
    return (value ?? '').toString().trim();
  }

  static int? _readId(
    Map<String, dynamic> raw,
    String directKey,
    String nestedKey,
  ) {
    final direct = _asInt(raw[directKey]);
    if (direct != null && direct > 0) return direct;

    final nested = raw[nestedKey];
    if (nested is Map) {
      return _asInt(nested['id'] ?? nested[directKey]);
    }

    return null;
  }

  static String _displayDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.trim();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year}';
  }
}
