class ActividadNarrativaTemplateService {
  const ActividadNarrativaTemplateService._();

  static String build({
    required String categoriaNombre,
    required String? subcategoriaNombre,
    String? lugar,
    String? municipio,
    String? operationalGroupLabel,
    bool requiereFomentoCulturaVial = false,
  }) {
    final categoria = _clean(categoriaNombre);
    final subcategoria = _clean(subcategoriaNombre);
    final descriptor = _descriptor(categoria, subcategoria);
    final location = _locationPhrase(lugar: lugar, municipio: municipio);
    final groupSentence = _operationalGroupSentence(operationalGroupLabel);
    final text = _normalized('$categoria $subcategoria');

    if (requiereFomentoCulturaVial ||
        _containsAny(text, const [
          'FOMENTO',
          'CULTURA VIAL',
          'CAPACITACION',
          'CAMPANA',
          'TALLER',
          'GUIÑOL',
          'EDUCACION VIAL',
          'JORNADA',
          'VALORES CIVICOS',
        ])) {
      return _joinSentences([
        'Me permito informar que a la hora antes mencionada se lleva a cabo actividad de fomento a la cultura vial correspondiente a $descriptor $location.',
        groupSentence,
        'La actividad tiene por objeto fortalecer la educacion vial, promover habitos seguros de movilidad y atender a la poblacion participante.',
        'Se registra la poblacion atendida y se anexa evidencia fotografica para conocimiento de la superioridad.',
      ]);
    }

    if (_containsAny(text, const ['C5I', 'C5', 'REPORTE'])) {
      return _joinSentences([
        'Me permito informar que a la hora antes mencionada se atiende reporte de base de radio C5i relacionado con $descriptor $location.',
        groupSentence,
        'Al arribar al lugar se verifica la situacion, se brinda apoyo preventivo y se mantiene presencia para salvaguardar la integridad de las personas usuarias de la via.',
        'Se informa la novedad atendida, quedando pendiente de reportar cualquier actualizacion relevante.',
      ]);
    }

    if (_containsAny(text, const [
      'ABANDERAMIENTO',
      'PROTECCION',
      'HECHO DE TRANSITO',
      'SINIESTRO',
      'VOLCADURA',
      'CHOQUE',
      'ATROPELLAMIENTO',
    ])) {
      return _joinSentences([
        'Me permito informar que a la hora antes mencionada se activa protocolo de proteccion y abanderamiento por $descriptor $location.',
        groupSentence,
        'Se realiza cobertura preventiva para advertir a las personas usuarias de la via, ordenar la circulacion y prevenir incidentes secundarios.',
        _closingFor(text),
      ]);
    }

    if (_containsAny(text, const [
      'CIERRE',
      'BLOQUEO',
      'MANIFESTACION',
      'CONCENTRACION',
      'LIBERA CIRCULACION',
    ])) {
      return _joinSentences([
        'Me permito informar que a la hora antes mencionada se instala dispositivo de control vial por $descriptor $location.',
        groupSentence,
        'Se canaliza la circulacion, se orienta a conductores y peatones, y se mantiene vigilancia para reducir riesgos en la zona.',
        _closingFor(text),
      ]);
    }

    if (_containsAny(text, const [
      'AUXILIO',
      'CABALLERO',
      'FALLA',
      'PONCHADURA',
      'VARADO',
      'APOYO VIAL',
    ])) {
      return _joinSentences([
        'Me permito informar que a la hora antes mencionada se brinda auxilio vial correspondiente a $descriptor $location.',
        groupSentence,
        'Se implementan medidas de seguridad y abanderamiento, se orienta a la persona usuaria y se apoya para restablecer condiciones seguras de movilidad.',
        _closingFor(text),
      ]);
    }

    if (_containsAny(text, const [
      'OPERATIVO',
      'CINTURON',
      'CASCO',
      'ALCOHOL',
      'TELURIO',
      'INTERINSTITUCIONAL',
      'PLAN SISTEMATICO',
    ])) {
      return _joinSentences([
        'Me permito informar que a la hora antes mencionada se implementa operativo de seguridad vial correspondiente a $descriptor $location.',
        groupSentence,
        'La actividad se desarrolla con presencia preventiva, orientacion a usuarios de la via y acciones encaminadas a disminuir riesgos y prevenir hechos de transito.',
        _closingFor(text),
      ]);
    }

    if (_containsAny(text, const [
      'BALIZAMIENTO',
      'SENALAMIENTO',
      'SEÑALAMIENTO',
      'OBRA',
      'MOREBUS',
      'PAVIMENTACION',
      'LIMPIEZA',
    ])) {
      return _joinSentences([
        'Me permito informar que a la hora antes mencionada se brinda apoyo de seguridad vial durante trabajos relacionados con $descriptor $location.',
        groupSentence,
        'Se protege la zona de labores, se orienta a usuarios de la via y se mantiene vigilancia para prevenir riesgos durante la intervencion.',
        _closingFor(text),
      ]);
    }

    if (_containsAny(text, const [
      'DISPOSITIVO',
      'ESCUELA SEGURA',
      'PASO PEATONAL',
      'SEMAFORO',
      'DISTRIBUIDOR',
      'EVENTO',
      'DESFILE',
      'PEREGRINACION',
      'PROCESION',
    ])) {
      return _joinSentences([
        'Me permito informar que a la hora antes mencionada se instala dispositivo de vialidad correspondiente a $descriptor $location.',
        groupSentence,
        'Se agiliza el flujo vehicular, se brinda apoyo al paso peatonal y se refuerzan medidas preventivas para evitar siniestros viales.',
        _closingFor(text),
      ]);
    }

    if (_containsAny(text, const [
      'MONITOREO',
      'RECORRIDO',
      'PATRULLAJE',
      'VIGILANCIA',
      'CARRETERA SEGURA',
    ])) {
      return _joinSentences([
        'Me permito informar que a la hora antes mencionada se efectua monitoreo y recorrido preventivo correspondiente a $descriptor $location.',
        groupSentence,
        'Se mantiene presencia de seguridad, vigilancia y prevencion, verificando condiciones de movilidad y atendiendo cualquier riesgo detectado.',
        _closingFor(text),
      ]);
    }

    if (_containsAny(text, const [
      'ACOMPANAMIENTO',
      'ACOMPAÑAMIENTO',
      'ESCOLTA',
      'PASO LIBRE',
      'GIRA',
      'FUNCIONARIO',
      'INSTITUCIONAL',
    ])) {
      return _joinSentences([
        'Me permito informar que a la hora antes mencionada se realiza acompanamiento y apoyo de seguridad vial correspondiente a $descriptor $location.',
        groupSentence,
        'Se mantiene presencia preventiva, se ordenan movimientos vehiculares y se resguarda el desarrollo de la actividad.',
        _closingFor(text),
      ]);
    }

    if (_containsAny(text, const [
      'PROXIMIDAD',
      'APOYO CIUDADANO',
      'PERSONA EN RIESGO',
      'CRUCE SEGURO',
      'MOVILIDAD LIMITADA',
      'TERCERA EDAD',
    ])) {
      return _joinSentences([
        'Me permito informar que a la hora antes mencionada se brinda apoyo de proximidad vial correspondiente a $descriptor $location.',
        groupSentence,
        'Se auxilia a la persona usuaria, se protege su desplazamiento y se mantienen condiciones seguras de movilidad.',
        _closingFor(text),
      ]);
    }

    if (_containsAny(text, const [
      'ANTECEDENTE',
      'ASEGURAMIENTO',
      'DETENIDO',
      'REAPREHENSION',
      'REPORTE DE ROBO',
      'ROBO',
    ])) {
      return _joinSentences([
        'Me permito informar que a la hora antes mencionada se realiza verificacion preventiva y apoyo de seguridad vial relacionado con $descriptor $location.',
        groupSentence,
        'Se solicita informacion a la base correspondiente, se preserva la seguridad en el punto y se actua conforme a las indicaciones recibidas.',
        'Se informa la novedad para conocimiento de la superioridad.',
      ]);
    }

    if (_containsAny(text, const ['REUNION', 'MESA', 'CURSO', 'FORO'])) {
      return _joinSentences([
        'Me permito informar que a la hora antes mencionada se participa en actividad institucional correspondiente a $descriptor $location.',
        groupSentence,
        'Se da seguimiento a los acuerdos y temas relacionados con seguridad vial, coordinacion operativa y prevencion de riesgos.',
        'Se informa lo anterior para conocimiento de la superioridad.',
      ]);
    }

    final categoriaText = _sentenceLabel(categoria, fallback: 'actividades');
    return _joinSentences([
      'Me permito informar que a la hora antes mencionada se realiza actividad de $categoriaText correspondiente a $descriptor $location.',
      groupSentence,
      'La actividad se desarrolla con presencia preventiva, orientacion a usuarios de la via y acciones para mantener condiciones seguras de movilidad.',
      _closingFor(text),
    ]);
  }

  static bool looksAutoGenerated(String? value) {
    final text = _normalized(value ?? '');
    if (text.isEmpty) return false;

    return _containsAny(text, const [
      'ME PERMITO INFORMAR QUE A LA HORA ANTES MENCIONADA',
      'SE QUEDA PENDIENTE DE INFORMAR CUALQUIER NOVEDAD RELEVANTE',
      'SE REGISTRA LA POBLACION ATENDIDA',
      'REPORTE FENIX / PIE TIERRA',
      'ACTIVIDAD FENIX / PIE TIERRA',
      'PUNTO FRECUENTE FENIX / PIE TIERRA',
      'FENIX / PIE TIERRA',
      'REPORTE MOTOCICLISTA',
      'AGUILAS MOTOCICLETAS',
      'UNIDAD DE PROTECCION EN VIALIDADES URBANAS',
    ]);
  }

  static String _descriptor(String categoria, String subcategoria) {
    final sub = _sentenceLabel(subcategoria);
    if (sub.isNotEmpty) {
      return sub;
    }

    final cat = _sentenceLabel(categoria);
    if (cat.isNotEmpty) {
      return cat;
    }

    return 'la actividad registrada';
  }

  static String _locationPhrase({String? lugar, String? municipio}) {
    final cleanLugar = _clean(lugar);
    final cleanMunicipio = _clean(municipio);

    if (cleanLugar.isNotEmpty && cleanMunicipio.isNotEmpty) {
      return 'en $cleanLugar, municipio de $cleanMunicipio';
    }
    if (cleanLugar.isNotEmpty) {
      return 'en $cleanLugar';
    }
    if (cleanMunicipio.isNotEmpty) {
      return 'en el municipio de $cleanMunicipio';
    }
    return 'en el lugar registrado';
  }

  static String _operationalGroupSentence(String? operationalGroupLabel) {
    final group = _clean(operationalGroupLabel);
    if (group.isEmpty) return '';
    return 'Interviene personal de $group para dar seguimiento al servicio.';
  }

  static String _closingFor(String normalizedText) {
    if (_containsAny(normalizedText, const [
      'CONCLUYE',
      'FINALIZA',
      'TERMINA',
      'SE RETIRA',
      'LIBERA CIRCULACION',
    ])) {
      return 'La actividad concluye sin novedad relevante que reportar, anexando evidencia fotografica para conocimiento de la superioridad.';
    }

    return 'Se queda pendiente de informar cualquier novedad relevante, anexando evidencia fotografica para conocimiento de la superioridad.';
  }

  static String _sentenceLabel(String value, {String fallback = ''}) {
    final clean = _clean(value);
    if (clean.isEmpty) {
      return fallback;
    }
    return clean.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(_normalized(needle))) {
        return true;
      }
    }
    return false;
  }

  static String _normalized(String value) {
    const accents = <String, String>{
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'Ü': 'U',
      'Ñ': 'N',
      'á': 'A',
      'é': 'E',
      'í': 'I',
      'ó': 'O',
      'ú': 'U',
      'ü': 'U',
      'ñ': 'N',
    };

    final buffer = StringBuffer();
    for (final char in value.trim().split('')) {
      buffer.write(accents[char] ?? char.toUpperCase());
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _joinSentences(List<String> sentences) {
    return sentences
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.isNotEmpty)
        .join('\n\n');
  }

  static String _clean(String? value) {
    return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
