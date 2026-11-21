import '../models/conduce_legalidad.dart';

class ConduceLegalidadNarrativaService {
  const ConduceLegalidadNarrativaService._();

  static String build(Iterable<ConduceLegalidadFundamento> fundamentos) {
    final conductas = <String>[];
    final vistos = <String>{};

    for (final fundamento in fundamentos) {
      final texto = _textoNarrable(fundamento);
      final clave = _normalizar(texto);
      if (texto.isEmpty || !vistos.add(clave)) continue;
      conductas.add(texto);
    }

    if (conductas.isEmpty) return '';

    final bloques = <String>[
      'Al encontrarse en labores de vigilancia, el agente observó ${_comoClausula(conductas.first)}, motivo por el cual le indicó el alto a la persona conductora y realizó la intervención correspondiente.',
    ];

    for (final conducta in conductas.skip(1)) {
      bloques.add(
        'Durante la revisión derivada de la intervención, también se constató ${_comoClausula(conducta)}.',
      );
    }

    bloques.add(
      'Se informó a la persona conductora el motivo de la intervención y los fundamentos aplicables, y se continuó con el procedimiento correspondiente.',
    );

    return bloques.join('\n\n');
  }

  static bool matchesSelection(
    String? narrativa,
    Iterable<ConduceLegalidadFundamento> fundamentos,
  ) {
    final actual = (narrativa ?? '').trim();
    if (actual.isEmpty) return false;
    return actual == build(fundamentos);
  }

  static String _conductaCatalogo(ConduceLegalidadFundamento fundamento) {
    return (fundamento.descripcion ?? '').trim().isNotEmpty
        ? fundamento.descripcion!.trim()
        : fundamento.nombre.trim();
  }

  static String _textoNarrable(ConduceLegalidadFundamento fundamento) {
    final sugerida = (fundamento.narrativaSugerida ?? '').trim();
    final normalizada = sugerida.toLowerCase();
    if (sugerida.isNotEmpty &&
        sugerida.length < 300 &&
        !normalizada.startsWith('se hace constar')) {
      return sugerida;
    }
    return _conductaCatalogo(fundamento);
  }

  static String _comoClausula(String value) {
    var texto = value.trim().replaceFirst(RegExp(r'[.!?]+$'), '');
    texto = texto.replaceFirst(
      RegExp(
        r'^se (?:detecta|detectó|observa|observó)\s+',
        caseSensitive: false,
      ),
      '',
    );
    if (texto.isEmpty) return 'la conducta asentada';

    if (texto.toLowerCase().startsWith('motocicleta ')) {
      texto = 'una $texto';
    }

    final lower = texto.toLowerCase();
    final esFraseDirecta =
        lower.startsWith('a una persona ') ||
        lower.startsWith('a un conductor ') ||
        lower.startsWith('una motocicleta ') ||
        lower.startsWith('un vehículo ');
    if (esFraseDirecta) return _lowerFirst(texto);

    final yaEsClausula =
        lower.startsWith('que ') ||
        lower.startsWith('la persona ') ||
        lower.startsWith('el conductor ') ||
        lower.startsWith('la conductora ') ||
        lower.startsWith('el vehículo ');

    final clausula = _lowerFirst(texto);
    return yaEsClausula || lower.startsWith('que ')
        ? (lower.startsWith('que ') ? clausula : 'que $clausula')
        : 'la conducta consistente en $clausula';
  }

  static String _lowerFirst(String value) {
    if (value.isEmpty) return value;
    return value[0].toLowerCase() + value.substring(1);
  }

  static String _normalizar(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
