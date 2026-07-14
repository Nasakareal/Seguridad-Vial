/// Plantilla editable para la narrativa precargada de una actividad.
///
/// Los textos pueden usar estas variables:
/// - `{descriptor}`: subcategoria seleccionada (o categoria si no hay una).
/// - `{location}`: lugar y/o municipio capturados.
/// - `{operationalGroup}`: grupo operativo que interviene, cuando aplica.
/// - `{closing}`: cierre pendiente o concluido segun la seleccion.
/// - `{categoria}`: nombre de la categoria seleccionada.
class ActividadNarrativaDefinition {
  final String nombre;
  final List<String> palabrasClave;
  final List<String> parrafos;
  final bool priorizarCoincidenciaDeCategoria;

  const ActividadNarrativaDefinition({
    required this.nombre,
    required this.palabrasClave,
    required this.parrafos,
    this.priorizarCoincidenciaDeCategoria = false,
  });
}

/// Catalogo central de narrativas precargadas.
///
/// Para corregir una narrativa, edita los parrafos de la definicion
/// correspondiente. El orden de [porCategoriaOSubcategoria] importa: se usa
/// la primera definicion cuyas palabras clave coincidan.
class ActividadNarrativas {
  const ActividadNarrativas._();

  // Solo se usa cuando la pantalla confirma que el usuario pertenece a
  // Fomento a la Cultura Vial y la categoria requiere su panel especializado.
  static const ActividadNarrativaDefinition
  fomentoCulturaVial = ActividadNarrativaDefinition(
    nombre: 'Fomento a la cultura vial',
    palabrasClave: [
      'FOMENTO',
      'CULTURA VIAL',
      'CAPACITACION',
      'CAMPANA',
      'TALLER',
      'GUIÑOL',
      'EDUCACION VIAL',
      'JORNADA',
      'VALORES CIVICOS',
    ],
    parrafos: [
      'Me permito informar que a la hora antes mencionada se lleva a cabo actividad de fomento a la cultura vial correspondiente a {descriptor} {location}.',
      '{operationalGroup}',
      'La actividad tiene por objeto fortalecer la educacion vial, promover habitos seguros de movilidad y atender a la poblacion participante.',
      'Se registra la poblacion atendida y se anexa evidencia fotografica para conocimiento de la superioridad.',
    ],
  );

  static const List<ActividadNarrativaDefinition> porCategoriaOSubcategoria = [
    ActividadNarrativaDefinition(
      nombre: 'Reportes C5i',
      palabrasClave: ['C5I', 'C5', 'REPORTE'],
      priorizarCoincidenciaDeCategoria: true,
      parrafos: [
        'Me permito informar que a la hora antes mencionada se atiende reporte de base de radio C5i relacionado con {descriptor} {location}.',
        '{operationalGroup}',
        'Al arribar al lugar se verifica la situacion, se brinda apoyo preventivo y se mantiene presencia para salvaguardar la integridad de las personas usuarias de la via.',
        'Se informa la novedad atendida, quedando pendiente de reportar cualquier actualizacion relevante.',
      ],
    ),
    ActividadNarrativaDefinition(
      nombre: 'Proteccion y abanderamiento',
      palabrasClave: [
        'ABANDERAMIENTO',
        'PROTECCION',
        'HECHO DE TRANSITO',
        'SINIESTRO',
        'VOLCADURA',
        'CHOQUE',
        'ATROPELLAMIENTO',
      ],
      parrafos: [
        'Me permito informar que a la hora antes mencionada se activa protocolo de proteccion y abanderamiento por {descriptor} {location}.',
        '{operationalGroup}',
        'Se realiza cobertura preventiva para advertir a las personas usuarias de la via, ordenar la circulacion y prevenir incidentes secundarios.',
        '{closing}',
      ],
    ),
    ActividadNarrativaDefinition(
      nombre: 'Cierres y bloqueos',
      palabrasClave: [
        'CIERRE',
        'BLOQUEO',
        'MANIFESTACION',
        'CONCENTRACION',
        'LIBERA CIRCULACION',
      ],
      parrafos: [
        'Me permito informar que a la hora antes mencionada se instala dispositivo de control vial por {descriptor} {location}.',
        '{operationalGroup}',
        'Se canaliza la circulacion, se orienta a conductores y peatones, y se mantiene vigilancia para reducir riesgos en la zona.',
        '{closing}',
      ],
    ),
    ActividadNarrativaDefinition(
      nombre: 'Auxilio vial',
      palabrasClave: [
        'AUXILIO',
        'CABALLERO',
        'FALLA',
        'PONCHADURA',
        'VARADO',
        'APOYO VIAL',
      ],
      parrafos: [
        'Me permito informar que a la hora antes mencionada se brinda auxilio vial correspondiente a {descriptor} {location}.',
        '{operationalGroup}',
        'Se implementan medidas de seguridad y abanderamiento, se orienta a la persona usuaria y se apoya para restablecer condiciones seguras de movilidad.',
        '{closing}',
      ],
    ),
    ActividadNarrativaDefinition(
      nombre: 'Operativos de seguridad vial',
      palabrasClave: [
        'OPERATIVO',
        'CINTURON',
        'CASCO',
        'ALCOHOL',
        'TELURIO',
        'INTERINSTITUCIONAL',
        'PLAN SISTEMATICO',
      ],
      parrafos: [
        'Me permito informar que a la hora antes mencionada se implementa operativo de seguridad vial correspondiente a {descriptor} {location}.',
        '{operationalGroup}',
        'La actividad se desarrolla con presencia preventiva, orientacion a usuarios de la via y acciones encaminadas a disminuir riesgos y prevenir hechos de transito.',
        '{closing}',
      ],
    ),
    ActividadNarrativaDefinition(
      nombre: 'Trabajos y balizamiento',
      palabrasClave: [
        'BALIZAMIENTO',
        'SENALAMIENTO',
        'SEÑALAMIENTO',
        'OBRA',
        'MOREBUS',
        'PAVIMENTACION',
        'LIMPIEZA',
      ],
      parrafos: [
        'Me permito informar que a la hora antes mencionada se brinda apoyo de seguridad vial durante trabajos relacionados con {descriptor} {location}.',
        '{operationalGroup}',
        'Se protege la zona de labores, se orienta a usuarios de la via y se mantiene vigilancia para prevenir riesgos durante la intervencion.',
        '{closing}',
      ],
    ),
    ActividadNarrativaDefinition(
      nombre: 'Dispositivos de vialidad',
      palabrasClave: [
        'DISPOSITIVO',
        'ESCUELA SEGURA',
        'PASO PEATONAL',
        'SEMAFORO',
        'DISTRIBUIDOR',
        'EVENTO',
        'DESFILE',
        'PEREGRINACION',
        'PROCESION',
      ],
      parrafos: [
        'Me permito informar que a la hora antes mencionada se instala dispositivo de vialidad correspondiente a {descriptor} {location}.',
        '{operationalGroup}',
        'Se agiliza el flujo vehicular, se brinda apoyo al paso peatonal y se refuerzan medidas preventivas para evitar siniestros viales.',
        '{closing}',
      ],
    ),
    ActividadNarrativaDefinition(
      nombre: 'Monitoreos y recorridos',
      palabrasClave: [
        'MONITOREO',
        'RECORRIDO',
        'PATRULLAJE',
        'VIGILANCIA',
        'CARRETERA SEGURA',
      ],
      parrafos: [
        'Me permito informar que a la hora antes mencionada se efectua monitoreo y recorrido preventivo correspondiente a {descriptor} {location}.',
        '{operationalGroup}',
        'Se mantiene presencia de seguridad, vigilancia y prevencion, verificando condiciones de movilidad y atendiendo cualquier riesgo detectado.',
        '{closing}',
      ],
    ),
    ActividadNarrativaDefinition(
      nombre: 'Acompañamientos',
      palabrasClave: [
        'ACOMPANAMIENTO',
        'ACOMPAÑAMIENTO',
        'ESCOLTA',
        'PASO LIBRE',
        'GIRA',
        'FUNCIONARIO',
        'INSTITUCIONAL',
      ],
      parrafos: [
        'Me permito informar que a la hora antes mencionada se realiza acompanamiento y apoyo de seguridad vial correspondiente a {descriptor} {location}.',
        '{operationalGroup}',
        'Se mantiene presencia preventiva, se ordenan movimientos vehiculares y se resguarda el desarrollo de la actividad.',
        '{closing}',
      ],
    ),
    ActividadNarrativaDefinition(
      nombre: 'Proximidad vial',
      palabrasClave: [
        'PROXIMIDAD',
        'APOYO CIUDADANO',
        'PERSONA EN RIESGO',
        'CRUCE SEGURO',
        'MOVILIDAD LIMITADA',
        'TERCERA EDAD',
      ],
      parrafos: [
        'Me permito informar que a la hora antes mencionada se brinda apoyo de proximidad vial correspondiente a {descriptor} {location}.',
        '{operationalGroup}',
        'Se auxilia a la persona usuaria, se protege su desplazamiento y se mantienen condiciones seguras de movilidad.',
        '{closing}',
      ],
    ),
    ActividadNarrativaDefinition(
      nombre: 'Verificacion y aseguramiento',
      palabrasClave: [
        'ANTECEDENTE',
        'ASEGURAMIENTO',
        'DETENIDO',
        'REAPREHENSION',
        'REPORTE DE ROBO',
        'ROBO',
      ],
      parrafos: [
        'Me permito informar que a la hora antes mencionada se realiza verificacion preventiva y apoyo de seguridad vial relacionado con {descriptor} {location}.',
        '{operationalGroup}',
        'Se solicita informacion a la base correspondiente, se preserva la seguridad en el punto y se actua conforme a las indicaciones recibidas.',
        'Se informa la novedad para conocimiento de la superioridad.',
      ],
    ),
    ActividadNarrativaDefinition(
      nombre: 'Actividades institucionales',
      palabrasClave: ['REUNION', 'MESA', 'CURSO', 'FORO'],
      parrafos: [
        'Me permito informar que a la hora antes mencionada se participa en actividad institucional correspondiente a {descriptor} {location}.',
        '{operationalGroup}',
        'Se da seguimiento a los acuerdos y temas relacionados con seguridad vial, coordinacion operativa y prevencion de riesgos.',
        'Se informa lo anterior para conocimiento de la superioridad.',
      ],
    ),
  ];

  static const ActividadNarrativaDefinition
  predeterminada = ActividadNarrativaDefinition(
    nombre: 'Actividad general',
    palabrasClave: [],
    parrafos: [
      'Me permito informar que a la hora antes mencionada se realiza actividad de {categoria} correspondiente a {descriptor} {location}.',
      '{operationalGroup}',
      'La actividad se desarrolla con presencia preventiva, orientacion a usuarios de la via y acciones para mantener condiciones seguras de movilidad.',
      '{closing}',
    ],
  );

  static const List<String> marcadoresDeNarrativaAutomatica = [
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
  ];
}
