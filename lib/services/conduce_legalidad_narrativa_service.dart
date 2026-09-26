import '../models/conduce_legalidad.dart';

class ConduceLegalidadNarrativaService {
  const ConduceLegalidadNarrativaService._();

  static String build(Iterable<ConduceLegalidadFundamento> fundamentos) {
    final bloques = <String>[];
    final vistos = <String>{};

    for (final fundamento in fundamentos) {
      final sugerida = (fundamento.narrativaSugerida ?? '').trim();
      final texto = sugerida.isNotEmpty
          ? sugerida
          : _fallback(fundamento.nombre);
      final clave = _normalizar(texto);
      if (texto.isEmpty || !vistos.add(clave)) continue;
      bloques.add(texto);
    }

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

  static String _fallback(String nombre) {
    final conducta = nombre.trim();
    if (conducta.isEmpty) return '';
    return 'Durante la intervención se detecta la conducta: $conducta.';
  }

  static String _normalizar(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
