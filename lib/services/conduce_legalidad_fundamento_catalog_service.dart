import '../models/conduce_legalidad.dart';

abstract final class ConduceLegalidadFundamentoCatalogService {
  static const String resguardoRequeridoMensaje =
      'No puedes guardar únicamente con fundamentos informativos, como luces, reflejantes o ruido. Agrega al menos un fundamento que amerite resguardo del vehículo: retención, depósito o arresto. Para esta validación, cualquier fundamento con arresto sí permite continuar.';
  static const Set<String> _fundamentosExcluidos = <String>{
    'ART420_FIII_I_MOTO_PASAJERO_MENOR',
    'ART421_FI_I_PARTICULAR_MENOR_SIN_PERMISO',
    'ART421_FI_IA_PARTICULAR_MENOR_SIN_PERMISO',
    'ART440_FIV_MOTO_PUENTE_PEATONAL',
    'ART402_LICENCIA_FORANEA_REINCIDENCIA',
    'ART432_FVII_REBASAR_IZQUIERDA_SEPARACION',
    'ART432_FVIII_ALINEARSE_DERECHA',
    'ART432_FIX_DISTANCIA_RAZONABLE',
    'ART432_FX_DIRECCIONALES',
    'ART432_FXI_PERMITIR_INCORPORACION',
    'ART432_FXII_CEDER_SERVICIO_SOCIAL',
    'ART432_FXV_VIAS_FERREAS',
    'ART432_FXVI_ASCENSO_CARRIL_ACERA',
    'ART432_FXVII_PORTAR_REGLAMENTO',
    'ART432_FXIX_CARAVANA_ESPACIO',
    'ART437_SERVICIO_SOCIAL_USO_INDEBIDO_SENALES',
    'ART439_FII_MOTO_REBASE_IZQUIERDA',
    'ART459_FII_I_MOTORIZADO_CINTURONES_SEGURIDAD',
    'ART459_FII_I_MOTORIZADO_LIMPIAPARABRISAS',
    'ART459_FII_I_MOTORIZADO_HERRAMIENTA_LLANTAS',
  };
  static const String _menorConduciendoCodigo =
      'ART421_FI_IA_PARTICULAR_MENOR_SIN_PERMISO';
  static const String grupoLicencia = 'Licencia y habilitación para conducir';
  static const String grupoDocumentos =
      'Documentos, placas y registro del vehículo';
  static const String grupoSituacionLegal = 'Situación legal o administrativa';
  static const String grupoVisibles = 'Otras causas visibles';
  static const String grupoOtras = 'Otras causas y condiciones del vehículo';
  static const String grupoLicenciaSuspendida =
      'Licencia suspendida o cancelada';

  static List<ConduceLegalidadFundamento> causasVisibles(
    Iterable<ConduceLegalidadFundamento> fundamentos,
  ) {
    final result = fundamentos
        .where(_estaDisponible)
        .where(esCausaVisible)
        .map(_presentarParaCaptura)
        .toList();
    result.sort((a, b) {
      final byPriority = _visiblePriority(a).compareTo(_visiblePriority(b));
      if (byPriority != 0) return byPriority;
      return _text(a).compareTo(_text(b));
    });
    return result;
  }

  static List<ConduceLegalidadFundamento> fundamentosAdicionales(
    Iterable<ConduceLegalidadFundamento> fundamentos,
  ) {
    final result = fundamentos
        .where(_estaDisponible)
        .map(_presentarParaCaptura)
        .toList();
    result.sort((a, b) {
      final aSuspended = esLicenciaSuspendida(a);
      final bSuspended = esLicenciaSuspendida(b);
      if (aSuspended != bSuspended) return aSuspended ? 1 : -1;

      final byGroup = _groupPriority(a).compareTo(_groupPriority(b));
      if (byGroup != 0) return byGroup;
      return _text(a).compareTo(_text(b));
    });
    return result;
  }

  static bool ameritaResguardo(ConduceLegalidadFundamento fundamento) {
    return fundamento.retencionVehiculo ||
        fundamento.depositoSiSinPersonaHabilitada ||
        fundamento.arrestoPersona;
  }

  static bool seleccionAmeritaResguardo(
    Iterable<ConduceLegalidadFundamento> fundamentos,
  ) {
    return fundamentos.any(ameritaResguardo);
  }

  static bool esCausaVisible(ConduceLegalidadFundamento fundamento) {
    final text = _text(fundamento);
    final ambito = (fundamento.ambitoVehiculo ?? '').trim().toLowerCase();
    final menorConduciendoMotocicleta = _esMenorConduciendoMotocicleta(
      fundamento,
    );
    if (ambito.isNotEmpty &&
        ambito != 'general' &&
        ambito != 'motocicleta' &&
        !menorConduciendoMotocicleta) {
      return false;
    }

    return _containsAny(text, const [
          'CASCO',
          'PASAJERO ENTRE CONDUCTOR Y MANUBRIO',
          'PASAJERO ENTRE MANUBRIO',
          'EXCESO PERSONAS',
          'MAS PERSONAS',
          'MENOR DE DOCE',
          'MENORES DE DOCE',
          'MENOR DOCE',
          'MENOR DE EDAD SIN PERMISO',
          'MENOR CONDUCIENDO',
          'SIN AMBAS PLACAS',
          'SIN PLACAS',
          'PLACAS ALTERADAS',
          'PLACAS OBSTRUIDAS',
          'OBSTRUYAN PLACAS',
          'EMISION DE HUMO',
          'HUMO VISIBLEMENTE',
          'SIRENAS',
          'TORRETAS',
          'ESTROBOS',
          'CROMATICA',
          'ANTIRADAR',
          'ACERAS',
          'AREAS PEATONALES',
          'VIAS EXCLUSIVAS PARA CICLISTAS',
          'CARRILES CONFINADOS',
          'CARRILES CENTRALES',
          'ENTRE CARRILES',
          'VIAS PRIMARIAS',
          'VIAS RESTRINGIDAS',
          'CENTRO DEL CARRIL',
          'REBASA POR LADO',
          'PREFERENCIA DE PASO',
          'REGLAS DE CIRCULACION DE CARRIL',
          'SIN LUCES TRASERAS',
          'SIN LUCES DELANTERAS',
          'LUCES DELANTERAS Y TRASERAS',
          'ADITAMENTOS LUMINOSOS',
          'BANDAS REFLEJANTES',
          'CARGA QUE IMPIDE CONTROL',
          'SUJETA A OTRO VEHICULO',
          'PLACA EN LUGAR NO VISIBLE',
          'INCLINACION INDEBIDA',
          'COMPETENCIAS',
          'ACROBACIAS',
          'MANIOBRAS RIESGOSAS',
          'CONDICION FISICA EVIDENTEMENTE PELIGROSA',
          'RUIDO EXCESIVO',
          'VOLUMEN EXCESIVO',
          'SILENCIADOR DE ESCAPE',
          'SISTEMA DE ESCAPE',
          'CLAXON',
          'BOCINA',
        ]) ||
        menorConduciendoMotocicleta;
  }

  static bool esLicenciaSuspendida(ConduceLegalidadFundamento fundamento) {
    final text = _text(fundamento);
    return text.contains('LICENCIA') &&
        (text.contains('SUSPENDIDA') || text.contains('CANCELADA'));
  }

  static bool _estaDisponible(ConduceLegalidadFundamento fundamento) {
    return !_fundamentosExcluidos.contains(
      (fundamento.codigo ?? '').trim().toUpperCase(),
    );
  }

  static ConduceLegalidadFundamento _presentarParaCaptura(
    ConduceLegalidadFundamento fundamento,
  ) {
    final esMenorConduciendo = _esMenorConduciendoMotocicleta(fundamento);
    if (!esMenorConduciendo) {
      return fundamento;
    }

    return fundamento.copyWith(
      nombre: 'Persona menor de edad conduciendo motocicleta',
      etiquetaOperativa: 'Menor conduciendo motocicleta',
      textoOperativo: 'Persona menor de edad conduciendo motocicleta',
      descripcion:
          'Una persona menor de edad se encuentra conduciendo una motocicleta.',
      narrativaSugerida:
          fundamento.narrativaSugerida ??
          'Se detecta a una persona menor de edad conduciendo una motocicleta.',
    );
  }

  static String grupo(ConduceLegalidadFundamento fundamento) {
    if (esLicenciaSuspendida(fundamento)) {
      return grupoLicenciaSuspendida;
    }

    final text = _text(fundamento);
    if (_containsAny(text, const [
      'LICENCIA',
      'SIN PERSONA HABILITADA',
      'HABILITACION JURIDICA',
    ])) {
      return grupoLicencia;
    }
    if (_containsAny(text, const [
      'PLACA',
      'TARJETA DE CIRCULACION',
      'CALCOMANIA',
      'REGISTRO',
      'REV',
      'BAJA ADMINISTRATIVA',
      'PERMISO TEMPORAL',
    ])) {
      return grupoDocumentos;
    }
    if (_containsAny(text, const [
      'DELITO',
      'ORDEN JUDICIAL',
      'ORDEN ADMINISTRATIVA',
      'APREHENSION',
      'ARRESTO',
      'COMPARECENCIA',
    ])) {
      return grupoSituacionLegal;
    }
    if (esCausaVisible(fundamento)) return grupoVisibles;
    return grupoOtras;
  }

  static int _visiblePriority(ConduceLegalidadFundamento fundamento) {
    final text = _text(fundamento);
    if (text.contains('CASCO')) return 10;
    if (text.contains('MENOR') && text.contains('CONDUC')) return 20;
    if (text.contains('MENOR') && text.contains('DOCE')) return 30;
    if (text.contains('PASAJERO ENTRE')) return 40;
    if (text.contains('EXCESO PERSONAS') || text.contains('MAS PERSONAS')) {
      return 50;
    }
    if (text.contains('SIN PLACAS') || text.contains('SIN AMBAS PLACAS')) {
      return 60;
    }
    return 100;
  }

  static int _groupPriority(ConduceLegalidadFundamento fundamento) {
    return switch (grupo(fundamento)) {
      grupoLicencia => 10,
      grupoDocumentos => 20,
      grupoSituacionLegal => 30,
      grupoVisibles => 40,
      _ => 50,
    };
  }

  static bool _containsAny(String text, Iterable<String> values) {
    return values.any(text.contains);
  }

  static String _text(ConduceLegalidadFundamento fundamento) {
    return _normalize(
      <String?>[
        fundamento.codigo,
        fundamento.nombre,
        fundamento.etiquetaOperativa,
        fundamento.textoOperativo,
        fundamento.descripcion,
      ].whereType<String>().join(' '),
    );
  }

  static bool _esMenorConduciendoMotocicleta(
    ConduceLegalidadFundamento fundamento,
  ) {
    final codigo = (fundamento.codigo ?? '').trim().toUpperCase();
    if (codigo == _menorConduciendoCodigo ||
        (codigo.startsWith('ART421_') &&
            codigo.contains('PARTICULAR_MENOR_SIN_PERMISO'))) {
      return true;
    }

    final text = _text(fundamento);
    return text.contains('MENOR CONDUCIENDO MOTOCICLETA') ||
        text.contains('MENOR DE EDAD CONDUCIENDO MOTOCICLETA') ||
        text.contains(
          'MENOR DE EDAD SIN PERMISO VIGENTE O CONDUCIENDO MOTOCICLETA',
        );
  }

  static String _normalize(String value) {
    return value
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
