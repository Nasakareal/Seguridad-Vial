/// Catálogo mínimo incorporado en la app para que Conduce con Legalidad pueda
/// mostrar y encolar fundamentos aun en una instalación sin conexión previa.
///
/// Los ids son locales y negativos a propósito. Al sincronizar, el backend
/// resuelve el registro vigente por `codigo`, evitando depender de los ids
/// autoincrementales de cada servidor.
final List<Map<String, dynamic>> conduceLegalidadLocalFundamentos =
    <Map<String, String?>>[
          _item(
            'ART333_RIESGO_GRAVE_CONDUCCION_CONDICION',
            '333',
            null,
            'Conducción o condición física evidentemente peligrosa que representa grave riesgo',
            'Ley de Movilidad y Seguridad Vial del Estado de Michoacán de Ocampo, artículo 333: deberán retirarse de la circulación los vehículos cuya conducción o condición física evidentemente peligrosa represente un grave riesgo para personas peatonas, ocupantes o demás vehículos.',
          ),
          _item(
            'ART328_FI_SIN_PLACAS_PERMISO_ALTERADAS_OBSTRUIDAS',
            '328',
            'I',
            'Sin ambas placas o permiso temporal; placas alteradas u obstruidas',
            'Ley de Movilidad y Seguridad Vial del Estado de Michoacán de Ocampo, artículo 328, fracción I.',
          ),
          _item(
            'ART328_FII_LICENCIA_SUSPENDIDA_CANCELADA',
            '328',
            'II',
            'Licencia suspendida o cancelada',
            'Ley de Movilidad y Seguridad Vial del Estado de Michoacán de Ocampo, artículo 328, fracción II.',
          ),
          _item(
            'ART328_FV_SIN_TARJETA_CIRCULACION_CONSTANCIA',
            '328',
            'V',
            'Sin tarjeta de circulación ni constancia de robo o extravío',
            'Ley de Movilidad y Seguridad Vial del Estado de Michoacán de Ocampo, artículo 328, fracción V.',
          ),
          _item(
            'ART328_FVII_USO_DISTINTO_AUTORIZADO',
            '328',
            'VII',
            'Vehículo utilizado para fines distintos a los autorizados',
            'Ley de Movilidad y Seguridad Vial del Estado de Michoacán de Ocampo, artículo 328, fracción VII.',
          ),
          _item(
            'ART328_FVIII_EMISION_HUMO_NOTORIA',
            '328',
            'VIII',
            'Emisión de humo visiblemente notoria',
            'Ley de Movilidad y Seguridad Vial del Estado de Michoacán de Ocampo, artículo 328, fracción VIII.',
          ),
          _item(
            'ART328_FXV_BAJA_ADMINISTRATIVA_SIN_PERMISO',
            '328',
            'XV',
            'Vehículo con baja administrativa y sin permiso para circular',
            'Ley de Movilidad y Seguridad Vial del Estado de Michoacán de Ocampo, artículo 328, fracción XV.',
          ),
          _item(
            'ART328_FXVI_INSTRUMENTO_OBJETO_DELITO',
            '328',
            'XVI',
            'Vehículo instrumento u objeto de delito',
            'Ley de Movilidad y Seguridad Vial del Estado de Michoacán de Ocampo, artículo 328, fracción XVI.',
          ),
          _item(
            'ART328_FXVIII_ORDEN_JUDICIAL_ADMINISTRATIVA',
            '328',
            'XVIII',
            'Retiro por orden judicial o administrativa',
            'Ley de Movilidad y Seguridad Vial del Estado de Michoacán de Ocampo, artículo 328, fracción XVIII.',
          ),
          _item(
            'ART328_FXIX_CONDUCTOR_APREHENSION_SIN_RESGUARDO',
            '328',
            'XIX',
            'Aprehensión, arresto o comparecencia del conductor sin persona para resguardar la unidad',
            'Ley de Movilidad y Seguridad Vial del Estado de Michoacán de Ocampo, artículo 328, fracción XIX.',
          ),
          _item(
            'ART422_FI_I_PLACAS_NO_COINCIDEN',
            '422',
            'I',
            'Placas o datos no coinciden con calcomanía, tarjeta o REV',
            'Reglamento de la Ley de Movilidad y Seguridad Vial, artículo 422, fracción I, inciso c).',
            inciso: 'c',
          ),
          _item(
            'ART425_USO_INDEBIDO_PLACAS_TARJETA',
            '425',
            null,
            'Usar tarjeta, placas, calcomanías u hologramas en vehículo diverso',
            'Reglamento de la Ley de Movilidad y Seguridad Vial, artículo 425.',
          ),
          _item(
            'ART440_FI_MOTO_ACERAS_PEATONES',
            '440',
            'I',
            'Motocicleta circula sobre aceras o áreas peatonales',
            'Reglamento de la Ley de Movilidad y Seguridad Vial, artículos 440, fracción I, y 702, fracción I, inciso d).',
            ambito: 'motocicleta',
          ),
          _item(
            'ART440_FII_MOTO_VIA_CICLISTA',
            '440',
            'II',
            'Motocicleta circula por vías exclusivas para ciclistas',
            'Reglamento de la Ley de Movilidad y Seguridad Vial, artículo 440, fracción II.',
            ambito: 'motocicleta',
          ),
          _item(
            'ART465_FII_SIRENAS_TORRETAS',
            '465',
            'II',
            'Sirenas, torretas, estrobos o códigos reservados',
            'Reglamento de la Ley de Movilidad y Seguridad Vial, artículo 465, fracción II.',
          ),
          _item(
            'ART465_FVI_ANTIRADARES',
            '465',
            'VI',
            'Sistemas antirradares o detectores de radares',
            'Reglamento de la Ley de Movilidad y Seguridad Vial, artículo 465, fracción VI.',
          ),
          _item(
            'ART465_FX_CROMATICA_PROHIBIDA',
            '465',
            'X',
            'Vehículo particular con cromática reservada o similar',
            'Reglamento de la Ley de Movilidad y Seguridad Vial, artículo 465, fracción X.',
          ),
          _item(
            'OP_CL_SIN_LICENCIA_SIN_HABILITADO',
            '402',
            null,
            'Persona sin licencia y sin persona habilitada inmediata',
            'Fundamento operativo compuesto: artículo 402 y artículos 700 y 702. El retiro sólo se asienta cuando no existe una persona legalmente habilitada que pueda hacerse cargo inmediato del vehículo.',
          ),
          _item(
            'ART419_FII_I_MOTO_EXCESO_PERSONAS',
            '419',
            'II',
            'Motocicleta con más personas que la tarjeta de circulación',
            'Reglamento de la Ley de Movilidad y Seguridad Vial, artículo 419, fracción II, inciso b).',
            inciso: 'b',
            ambito: 'motocicleta',
          ),
          _item(
            'ART419_FII_I_MOTO_CASCO_PROTECTOR',
            '419',
            'II',
            'Motocicleta sin casco protector conforme a especificaciones',
            'Reglamento de la Ley de Movilidad y Seguridad Vial, artículo 419, fracción II, inciso d).',
            inciso: 'd',
            ambito: 'motocicleta',
          ),
          _item(
            'ART420_FIII_I_MOTO_PASAJERO_ENTRE_MANUBRIO',
            '420',
            'III',
            'Motocicleta con pasajero entre conductor y manubrio',
            'Reglamento de la Ley de Movilidad y Seguridad Vial, artículo 420, fracción III, inciso c).',
            inciso: 'c',
            ambito: 'motocicleta',
          ),
          _item(
            'ART420_FIII_I_MOTO_MENOR_DOCE',
            '420',
            'III',
            'Motocicleta transporta menor de doce años',
            'Reglamento de la Ley de Movilidad y Seguridad Vial, artículo 420, fracción III, inciso d).',
            inciso: 'd',
            ambito: 'motocicleta',
          ),
          _item(
            'ART642_FII_COMPETENCIAS_MANIOBRAS_RIESGOSAS',
            '642',
            'II',
            'Organizar o participar en competencias, acrobacias o maniobras riesgosas',
            'Reglamento de la Ley de Movilidad y Seguridad Vial, artículo 642, fracción II.',
          ),
          _item(
            'ART642_FIII_OBJETOS_RESIDUOS_CIRCULACION',
            '642',
            'III',
            'Colocar, arrojar o abandonar objetos o residuos que entorpezcan la circulación',
            'Reglamento de la Ley de Movilidad y Seguridad Vial, artículo 642, fracción III.',
          ),
          _item(
            'ART642_FIV_DANAR_SENALIZACION',
            '642',
            'IV',
            'Utilizar inadecuadamente, obstruir, dañar o destruir señalización vial',
            'Reglamento de la Ley de Movilidad y Seguridad Vial, artículo 642, fracción IV.',
          ),
        ]
        .asMap()
        .entries
        .map((entry) {
          final item = entry.value;
          return <String, dynamic>{
            'id': -(entry.key + 1),
            'codigo': item['codigo'],
            'nombre': item['nombre'],
            'articulo': item['articulo'],
            'fraccion': item['fraccion'],
            'inciso': item['inciso'],
            'ambito_vehiculo': item['ambito'],
            'puntos': 0,
            'retencion_vehiculo': true,
            'descripcion': item['nombre'],
            'fundamento_legal': item['fundamento'],
          };
        })
        .toList(growable: false);

Map<String, String?> _item(
  String codigo,
  String articulo,
  String? fraccion,
  String nombre,
  String fundamento, {
  String? inciso,
  String ambito = 'general',
}) => <String, String?>{
  'codigo': codigo,
  'articulo': articulo,
  'fraccion': fraccion,
  'inciso': inciso,
  'ambito': ambito,
  'nombre': nombre,
  'fundamento': fundamento,
};
