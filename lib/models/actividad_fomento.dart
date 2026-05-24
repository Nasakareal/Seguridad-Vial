class ActividadFomentoPrograma {
  final int id;
  final String nombre;

  const ActividadFomentoPrograma({required this.id, required this.nombre});

  factory ActividadFomentoPrograma.fromJson(Map<String, dynamic> json) {
    return ActividadFomentoPrograma(
      id: _asInt(json['id']),
      nombre: _asNullableString(json['nombre']) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre};
}

class ActividadFomentoNumericField {
  final String key;
  final String label;

  const ActividadFomentoNumericField(this.key, this.label);
}

class ActividadFomentoDetalle {
  static const int maxCount = 999999;

  static const List<String> nivelesEducativos = <String>[
    'PREESCOLAR',
    'PRIMARIA',
    'SECUNDARIA',
    'MEDIA SUPERIOR',
    'SUPERIOR',
    'SECTOR PRIVADO',
    'SECTOR PUBLICO',
    'MEDIO RURAL',
  ];

  static const List<String> sectores = <String>[
    'CICLISTAS',
    'MOTOCICLISTAS',
    'PARTICULARES',
    'TRANSPORTE PUBLICO Y ESCOLAR',
  ];

  static const List<ActividadFomentoNumericField> numericFields =
      <ActividadFomentoNumericField>[
        ActividadFomentoNumericField('ninas', 'Niñas'),
        ActividadFomentoNumericField('ninos', 'Niños'),
        ActividadFomentoNumericField(
          'adolescentes_mujeres',
          'Adolescentes mujeres',
        ),
        ActividadFomentoNumericField(
          'adolescentes_hombres',
          'Adolescentes hombres',
        ),
        ActividadFomentoNumericField('docentes_hombres', 'Docentes hombres'),
        ActividadFomentoNumericField('docentes_mujeres', 'Docentes mujeres'),
        ActividadFomentoNumericField('hombres', 'Hombres'),
        ActividadFomentoNumericField('mujeres', 'Mujeres'),
      ];

  final int? programaId;
  final String? programaNombre;
  final String? nivelEducativo;
  final String? sector;
  final int ninas;
  final int ninos;
  final int adolescentesMujeres;
  final int adolescentesHombres;
  final int docentesHombres;
  final int docentesMujeres;
  final int hombres;
  final int mujeres;
  final int totalPoblacionAtendida;

  const ActividadFomentoDetalle({
    this.programaId,
    this.programaNombre,
    this.nivelEducativo,
    this.sector,
    this.ninas = 0,
    this.ninos = 0,
    this.adolescentesMujeres = 0,
    this.adolescentesHombres = 0,
    this.docentesHombres = 0,
    this.docentesMujeres = 0,
    this.hombres = 0,
    this.mujeres = 0,
    this.totalPoblacionAtendida = 0,
  });

  factory ActividadFomentoDetalle.fromJson(Map<String, dynamic> json) {
    return ActividadFomentoDetalle(
      programaId:
          _asNullableInt(json['fomento_cultura_vial_programa_id']) ??
          _asNullableInt(json['programa_id']),
      programaNombre:
          _asNullableString(json['programa_nombre']) ??
          _asNestedNullableString(json['programa']),
      nivelEducativo: _asNullableString(json['nivel_educativo']),
      sector: _asNullableString(json['sector']),
      ninas: _asInt(json['ninas']),
      ninos: _asInt(json['ninos']),
      adolescentesMujeres: _asInt(json['adolescentes_mujeres']),
      adolescentesHombres: _asInt(json['adolescentes_hombres']),
      docentesHombres: _asInt(json['docentes_hombres']),
      docentesMujeres: _asInt(json['docentes_mujeres']),
      hombres: _asInt(json['hombres']),
      mujeres: _asInt(json['mujeres']),
      totalPoblacionAtendida: _asInt(json['total_poblacion_atendida']),
    );
  }

  int get computedTotal =>
      ninas +
      ninos +
      adolescentesMujeres +
      adolescentesHombres +
      docentesHombres +
      docentesMujeres +
      hombres +
      mujeres;

  int valueFor(String key) {
    switch (key) {
      case 'ninas':
        return ninas;
      case 'ninos':
        return ninos;
      case 'adolescentes_mujeres':
        return adolescentesMujeres;
      case 'adolescentes_hombres':
        return adolescentesHombres;
      case 'docentes_hombres':
        return docentesHombres;
      case 'docentes_mujeres':
        return docentesMujeres;
      case 'hombres':
        return hombres;
      case 'mujeres':
        return mujeres;
    }
    return 0;
  }

  Map<String, dynamic> toJson() => {
    'programa_id': programaId,
    'programa_nombre': programaNombre,
    'nivel_educativo': nivelEducativo,
    'sector': sector,
    'ninas': ninas,
    'ninos': ninos,
    'adolescentes_mujeres': adolescentesMujeres,
    'adolescentes_hombres': adolescentesHombres,
    'docentes_hombres': docentesHombres,
    'docentes_mujeres': docentesMujeres,
    'hombres': hombres,
    'mujeres': mujeres,
    'total_poblacion_atendida': computedTotal,
  };
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _asNullableString(dynamic value) {
  if (value == null || value is Map) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String? _asNestedNullableString(dynamic value) {
  if (value is! Map) return null;
  return _asNullableString(value['nombre'] ?? value['name'] ?? value['label']);
}
