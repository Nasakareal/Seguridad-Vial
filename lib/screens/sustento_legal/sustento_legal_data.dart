class LegalItem {
  final String id;
  final String categoriaId;
  final String titulo;
  final String resumen;
  final String reglaRapida;
  final List<String> aplicaCuando;
  final List<String> fundamento;
  final List<String> requisitos;
  final List<String> permite;
  final List<String> noPermite;
  final List<String> documenta;
  final List<String> pasos;
  final List<String> erroresComunes;
  final List<String> keywords;

  const LegalItem({
    required this.id,
    required this.categoriaId,
    required this.titulo,
    required this.resumen,
    this.reglaRapida = '',
    this.aplicaCuando = const [],
    required this.fundamento,
    this.requisitos = const [],
    required this.permite,
    required this.noPermite,
    this.documenta = const [],
    required this.pasos,
    this.erroresComunes = const [],
    required this.keywords,
  });
}

const List<LegalItem> kLegalItems = [
  LegalItem(
    id: 'siniestro_resguardo',
    categoriaId: 'aseguramiento',
    titulo: 'Siniestro: resguardo/remisión (corralón y depósito)',
    resumen:
        'Cuándo NO procede corralón en solo daños y qué debes hacer si sí procede remisión.',
    reglaRapida:
        'Solo daños + docs vigentes + convenio/desistimiento = NO corralón (334).',
    aplicaCuando: ['Hecho de tránsito.', 'Intervención de perito o agente.'],
    fundamento: [
      'Ley de Movilidad y Seguridad Vial de Michoacán Mich. 115',
      'Ley de Movilidad y Seguridad Vial de Michoacán Mich. 116',
      'Ley de Movilidad y Seguridad Vial de Michoacán Mich. 117',
      'Ley de Movilidad y Seguridad Vial de Michoacán Mich. 333',
      'Ley de Movilidad y Seguridad Vial de Michoacán Mich. 334',
      'Ley de Movilidad y Seguridad Vial de Michoacán Mich. 352',
    ],
    requisitos: [
      'Determinar si hay solo daños o hay lesionados/riesgo.',
      'Verificar documentos y condiciones del caso.',
    ],
    permite: [
      'Generar información del hecho y documentación mínima.',
      'Resguardar/retirar de circulación si hay condición evidentemente peligrosa.',
      'Remitir a depósito cuando legalmente proceda, con inventario y sellado.',
    ],
    noPermite: [
      'Remitir al corralón en solo daños cuando hay convenio/desistimiento y documentos vigentes.',
      'Arrastrar/remitir sin inventario y sellado previo (si procede remisión).',
    ],
    documenta: [
      'Geolocalización y datos del hecho.',
      'Fotografías/video del estado final o constancia si se movieron por emergencia.',
      'Convenio/desistimiento (si aplica).',
      'Inventario y sellado antes de arrastre (si aplica).',
    ],
    pasos: [
      'Asegurar la escena.',
      'Recabar información mínima del hecho.',
      'Determinar si procede remisión o no.',
      'Si procede remisión: sellar e inventariar antes del arrastre.',
    ],
    erroresComunes: [
      'Mandar al corralón “por si acaso” en solo daños.',
      'No dejar constancia cuando se movieron vehículos por emergencia.',
      'No hacer inventario/sellado cuando procede remisión.',
    ],
    keywords: [
      'siniestro',
      'resguardo',
      'corralón',
      'depósito',
      'lmsv',
      '334',
      '352',
    ],
  ),

  // =====================
  // SINIESTROS / TRANSITO
  // =====================
  LegalItem(
    id: 'sin_boleta_fundada',
    categoriaId: 'infraccion',
    titulo: 'Boleta de infracción: debe estar fundada y motivada',
    resumen:
        'La infracción debe emitirse por agente/inspector acreditado, con identificación visible, fundando y motivando la causa legal, y dando derecho a manifestar lo que convenga.',
    reglaRapida:
        'Sin fundamento/motivación y sin identificación visible = riesgo de nulidad.',
    aplicaCuando: [
      'Se detecta una infracción de tránsito.',
      'Se va a emitir boleta en vía pública.',
    ],
    fundamento: ['Ley de Movilidad y Seguridad Vial de Michoacán Art. 340'],
    requisitos: [
      'Agente/inspector acreditado e identificado.',
      'Causa legal fundada y motivada.',
      'Entregar boleta por escrito; permitir manifestaciones si está presente.',
    ],
    permite: [
      'Emitir boleta de infracción conforme a ley.',
      'Asentar manifestaciones del presunto infractor.',
    ],
    noPermite: [
      'Infraccionar sin identificación visible.',
      'Infraccionar sin fundar y motivar la causa legal.',
    ],
    documenta: [
      'Datos del vehículo/conductor.',
      'Lugar, fecha, hora.',
      'Hechos que constituyen la infracción.',
      'Fundamento legal (artículo) y motivación.',
    ],
    pasos: [
      'Identificarte con credencial visible.',
      'Explicar el motivo y el fundamento.',
      'Emitir boleta completa y entregar copia.',
    ],
    erroresComunes: [
      'No poner el artículo correcto.',
      'No describir hechos (solo “por infracción”).',
    ],
    keywords: ['boleta', 'fundar', 'motivar', '340', 'infracción'],
  ),

  LegalItem(
    id: 'sin_garantia_pago',
    categoriaId: 'infraccion',
    titulo:
        'Prohibido retener documentos/placas/vehículo como garantía de pago',
    resumen:
        'No se puede retener licencia, tarjeta de circulación, placa o vehículo como medio de garantía del pago de multa.',
    reglaRapida: 'Multa ≠ “me dejas la licencia/placas”.',
    aplicaCuando: [
      'Se impone una multa por infracción de tránsito.',
      'La persona no puede o no quiere pagar en el momento.',
    ],
    fundamento: ['Ley de Movilidad y Seguridad Vial de Michoacán Art. 344'],
    requisitos: ['Levantamiento de boleta conforme a ley.'],
    permite: [
      'Imponer la sanción y tramitarla por el procedimiento administrativo aplicable.',
    ],
    noPermite: [
      'Retener licencia.',
      'Retener tarjeta de circulación.',
      'Retener placas.',
      'Retener vehículo solo para garantizar pago.',
    ],
    documenta: ['Boleta de infracción completa.'],
    pasos: [
      'Emitir boleta.',
      'Informar el medio de pago y plazos.',
      'Canalizar a procedimiento administrativo si no paga.',
    ],
    erroresComunes: ['Amenazar con retener documentos para que “pague ya”.'],
    keywords: ['garantía', 'retener', 'licencia', 'placas', '344'],
  ),

  LegalItem(
    id: 'sin_alcohol',
    categoriaId: 'siniestros_transito',
    titulo: 'Conducción en estado de ebriedad / sustancias',
    resumen:
        'Conducir en ebriedad o bajo efectos de sustancias implica sanción (multa o arresto hasta 36h) conforme a los valores y el reglamento aplicable.',
    reglaRapida:
        'Alcohol/drogas + conducción = sanción fuerte y documentar bien.',
    aplicaCuando: [
      'Conductor con signos de ebriedad.',
      'Siniestro con sospecha de alcohol o sustancias.',
    ],
    fundamento: ['Ley de Movilidad y Seguridad Vial de Michoacán Art. 345'],
    requisitos: [
      'Actuación conforme a reglamento/protocolo aplicable.',
      'Documentar signos, circunstancias y actuaciones.',
    ],
    permite: [
      'Aplicar la infracción/sanción conforme a normativa.',
      'Asegurar condiciones de seguridad vial.',
    ],
    noPermite: [
      'Inventar signos no observados.',
      'Omitir la documentación del motivo.',
    ],
    documenta: [
      'Hora, lugar y hechos.',
      'Signos observables (olor, coordinación, habla, etc.).',
      'Datos del vehículo y conductor.',
    ],
    pasos: [
      'Asegurar escena y seguridad vial.',
      'Documentar signos y motivo de intervención.',
      'Proceder conforme a reglamento/protocolo.',
    ],
    erroresComunes: [
      'No describir signos objetivos.',
      'No asentar circunstancias del contacto.',
    ],
    keywords: ['alcohol', 'ebriedad', '345', 'sustancias', 'tránsito'],
  ),

  LegalItem(
    id: 'sin_remision_sellado_inventario',
    categoriaId: 'aseguramiento',
    titulo: 'Remisión a depósito: sellado e inventario antes del arrastre',
    resumen:
        'Si procede remisión al depósito, antes de iniciar el arrastre se debe sellar el vehículo y elaborar inventario. Si no, hay responsabilidad solidaria por daños/pérdidas.',
    reglaRapida: 'Si va a depósito: primero sello + inventario, luego grúa.',
    aplicaCuando: [
      'Procede remisión del vehículo al depósito/corralón.',
      'Intervención por siniestro o infracción que amerita depósito.',
    ],
    fundamento: ['Ley de Movilidad y Seguridad Vial de Michoacán Art. 352'],
    requisitos: [
      'Determinar que legalmente procede remisión.',
      'Sellado previo.',
      'Inventario previo.',
    ],
    permite: [
      'Remitir al depósito cuando proceda legalmente.',
      'Proteger pertenencias/objetos dentro del vehículo.',
    ],
    noPermite: [
      'Arrastrar sin sellado previo.',
      'Arrastrar sin inventario previo.',
    ],
    documenta: [
      'Inventario del vehículo (interior/exterior).',
      'Sellos colocados.',
      'Evidencia fotográfica si aplica.',
    ],
    pasos: [
      'Confirmar procedencia legal de remisión.',
      'Sellar vehículo.',
      'Levantar inventario completo.',
      'Autorizar arrastre/remisión.',
    ],
    erroresComunes: [
      '“Se lo llevó la grúa” sin inventario.',
      'No asentar objetos dentro del vehículo.',
    ],
    keywords: ['depósito', 'corralón', 'sellado', 'inventario', '352'],
  ),

  LegalItem(
    id: 'sin_impugna_infraccion',
    categoriaId: 'infraccion',
    titulo: 'Impugnación: inconformidad por infracción o retiro a depósito',
    resumen:
        'La persona puede inconformarse por infracción o cuando el vehículo fue retirado y resguardado en depósitos autorizados, mediante medios de impugnación en justicia administrativa.',
    reglaRapida: 'Siempre informa: “hay medios de impugnación”.',
    aplicaCuando: [
      'La persona cuestiona la infracción.',
      'La persona cuestiona el retiro/remisión a depósito.',
    ],
    fundamento: ['Ley de Movilidad y Seguridad Vial de Michoacán Art. 348'],
    requisitos: ['Boleta y actuaciones debidamente documentadas.'],
    permite: ['Orientar sobre vías de impugnación (sin obstaculizar).'],
    noPermite: ['Negar u ocultar el derecho a impugnar.'],
    documenta: [
      'Boleta completa.',
      'Motivación del retiro/remisión si ocurrió.',
    ],
    pasos: [
      'Entregar boleta y explicar motivo.',
      'Indicar que puede impugnar por la vía administrativa correspondiente.',
    ],
    erroresComunes: [
      'No entregar copia de boleta.',
      'No describir motivo del retiro/remisión.',
    ],
    keywords: [
      'impugnación',
      'inconformidad',
      '348',
      'justicia administrativa',
    ],
  ),

  LegalItem(
    id: 'sin_queja_asuntos_internos',
    categoriaId: 'derechos',
    titulo: 'Queja contra agente: canalización a Asuntos Internos',
    resumen:
        'Las personas pueden presentar queja verbal o por escrito ante Asuntos Internos si alegan delito o violaciones a derechos por un agente en funciones.',
    reglaRapida: 'Queja = orientar y no obstaculizar.',
    aplicaCuando: [
      'La persona refiere abuso, extorsión o violación de derechos.',
      'Se solicita dónde denunciar conducta del agente.',
    ],
    fundamento: ['Ley de Movilidad y Seguridad Vial de Michoacán Art. 349'],
    requisitos: ['Trato respetuoso y orientación clara.'],
    permite: ['Orientar a la vía de queja/denuncia.'],
    noPermite: [
      'Intimidar para que no denuncie.',
      'Retener datos o negar identificación.',
    ],
    documenta: ['Si aplica: datos del servicio y actuaciones (bitácora).'],
    pasos: [
      'Identificarte correctamente.',
      'Orientar a Asuntos Internos (queja verbal o escrita).',
    ],
    erroresComunes: ['Negarse a identificarse.', 'Responder con amenazas.'],
    keywords: ['asuntos internos', 'queja', '349', 'derechos'],
  ),
  LegalItem(
    id: 'control_preventivo_identificacion',
    categoriaId: 'control_preventivo',
    titulo: 'Control preventivo: identificación de personas',
    resumen:
        'Cuándo puedes solicitar identificación y cómo hacerlo sin vulnerar derechos.',
    reglaRapida:
        'Control preventivo ≠ detención. Solo solicitud de identificación, sin retención indebida.',
    aplicaCuando: [
      'Conducta atípica o indicios razonables.',
      'Operativos preventivos autorizados.',
    ],
    fundamento: [
      'Constitución Política de los Estados Unidos Mexicanos Art. 16',
      'Ley Nacional sobre el Uso de la Fuerza Art. 9',
      'Ley del Sistema Estatal de Seguridad Pública de Michoacán',
    ],
    requisitos: [
      'Existir motivo objetivo y razonable.',
      'Identificarse como autoridad.',
      'Explicar el motivo del control.',
    ],
    permite: [
      'Solicitar nombre e identificación.',
      'Verificar datos de manera preventiva.',
      'Realizar inspección visual externa.',
    ],
    noPermite: [
      'Retener a la persona sin causa.',
      'Revisar pertenencias sin consentimiento o flagrancia.',
      'Trasladar a instalaciones policiales.',
    ],
    documenta: [
      'Motivo del control.',
      'Hora y lugar.',
      'Resultado del contacto.',
    ],
    pasos: [
      'Identificarse.',
      'Explicar el motivo.',
      'Solicitar identificación.',
      'Finalizar contacto si no hay indicios.',
    ],
    erroresComunes: [
      'Convertir el control en detención.',
      'No explicar el motivo.',
      'Amenazar o intimidar.',
    ],
    keywords: ['control', 'preventivo', 'identificación', 'art16'],
  ),
];
