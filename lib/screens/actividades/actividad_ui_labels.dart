import '../../models/actividad_categoria.dart';
import '../../models/actividad_subcategoria.dart';

class ActividadUiLabels {
  const ActividadUiLabels._();

  static String subcategoriaNombre(
    ActividadSubcategoria? subcategoria, {
    required bool isFomentoUser,
    String fallback = '—',
  }) {
    final nombre = (subcategoria?.nombre ?? '').trim();
    if (nombre.isEmpty) return fallback;

    if (isFomentoUser && _looksLikeTallerSeguridadVial(nombre)) {
      return 'Talleres';
    }

    return nombre;
  }

  static int? defaultFomentoCategoriaId(List<ActividadCategoria> categorias) {
    for (final categoria in categorias) {
      final slug = (categoria.slug ?? '').trim().toLowerCase();
      final nombre = _normalize(categoria.nombre);
      if (slug == 'capacitaciones' || nombre == 'CAPACITACIONES') {
        return categoria.id;
      }
    }

    for (final categoria in categorias) {
      if (categoria.requiereFomentoCulturaVial) return categoria.id;
    }

    return null;
  }

  static bool _looksLikeTallerSeguridadVial(String value) {
    final normalized = _normalize(value);
    return normalized.contains('TALLER') &&
        normalized.contains('SEGURIDAD VIAL');
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
