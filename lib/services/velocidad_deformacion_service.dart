import 'dart:math' as math;

class VelocidadDeformacionInput {
  final double masaKg;
  final double anchoDanoMetros;
  final double coeficienteAKnPorMetro;
  final double coeficienteBKnPorMetro2;
  final double? coeficienteGKjPorMetro;
  final List<double> deformacionesCm;

  const VelocidadDeformacionInput({
    required this.masaKg,
    required this.anchoDanoMetros,
    required this.coeficienteAKnPorMetro,
    required this.coeficienteBKnPorMetro2,
    this.coeficienteGKjPorMetro,
    required this.deformacionesCm,
  });
}

class VelocidadDeformacionResult {
  final double energiaKj;
  final double velocidadEquivalenteMs;
  final double velocidadEquivalenteKmh;
  final double coeficienteGUsadoKjPorMetro;

  const VelocidadDeformacionResult({
    required this.energiaKj,
    required this.velocidadEquivalenteMs,
    required this.velocidadEquivalenteKmh,
    required this.coeficienteGUsadoKjPorMetro,
  });

  double get velocidadEquivalenteMph => velocidadEquivalenteKmh * 0.6213711922;
}

class VelocidadDeformacionService {
  const VelocidadDeformacionService._();

  static VelocidadDeformacionResult calcular(VelocidadDeformacionInput input) {
    if (input.masaKg <= 0) {
      throw ArgumentError.value(
        input.masaKg,
        'masaKg',
        'La masa del vehículo debe ser mayor a cero.',
      );
    }

    if (input.anchoDanoMetros <= 0) {
      throw ArgumentError.value(
        input.anchoDanoMetros,
        'anchoDanoMetros',
        'El ancho dañado debe ser mayor a cero.',
      );
    }

    if (input.coeficienteAKnPorMetro < 0) {
      throw ArgumentError.value(
        input.coeficienteAKnPorMetro,
        'coeficienteAKnPorMetro',
        'El coeficiente A no puede ser negativo.',
      );
    }

    if (input.coeficienteBKnPorMetro2 <= 0) {
      throw ArgumentError.value(
        input.coeficienteBKnPorMetro2,
        'coeficienteBKnPorMetro2',
        'El coeficiente B debe ser mayor a cero.',
      );
    }

    if (input.deformacionesCm.length < 2) {
      throw ArgumentError.value(
        input.deformacionesCm,
        'deformacionesCm',
        'Captura al menos dos mediciones de deformación.',
      );
    }

    if (input.deformacionesCm.any((value) => value < 0)) {
      throw ArgumentError.value(
        input.deformacionesCm,
        'deformacionesCm',
        'Las deformaciones no pueden ser negativas.',
      );
    }

    if (!input.deformacionesCm.any((value) => value > 0)) {
      throw ArgumentError.value(
        input.deformacionesCm,
        'deformacionesCm',
        'Captura al menos una deformación mayor a cero.',
      );
    }

    final g =
        input.coeficienteGKjPorMetro ??
        calcularG(
          coeficienteAKnPorMetro: input.coeficienteAKnPorMetro,
          coeficienteBKnPorMetro2: input.coeficienteBKnPorMetro2,
        );

    if (g < 0) {
      throw ArgumentError.value(
        g,
        'coeficienteGKjPorMetro',
        'El coeficiente G no puede ser negativo.',
      );
    }

    final deformacionesMetros = input.deformacionesCm
        .map((value) => value / 100)
        .toList(growable: false);
    final separacionMetros =
        input.anchoDanoMetros / (deformacionesMetros.length - 1);

    var energiaKj = 0.0;
    for (var i = 0; i < deformacionesMetros.length - 1; i++) {
      final e1 = _energiaPorMetroKj(
        deformacionMetros: deformacionesMetros[i],
        coeficienteAKnPorMetro: input.coeficienteAKnPorMetro,
        coeficienteBKnPorMetro2: input.coeficienteBKnPorMetro2,
        coeficienteGKjPorMetro: g,
      );
      final e2 = _energiaPorMetroKj(
        deformacionMetros: deformacionesMetros[i + 1],
        coeficienteAKnPorMetro: input.coeficienteAKnPorMetro,
        coeficienteBKnPorMetro2: input.coeficienteBKnPorMetro2,
        coeficienteGKjPorMetro: g,
      );
      energiaKj += ((e1 + e2) / 2) * separacionMetros;
    }

    final velocidadMs = math.sqrt((2 * energiaKj * 1000) / input.masaKg);

    return VelocidadDeformacionResult(
      energiaKj: energiaKj,
      velocidadEquivalenteMs: velocidadMs,
      velocidadEquivalenteKmh: velocidadMs * 3.6,
      coeficienteGUsadoKjPorMetro: g,
    );
  }

  static double calcularG({
    required double coeficienteAKnPorMetro,
    required double coeficienteBKnPorMetro2,
  }) {
    if (coeficienteBKnPorMetro2 <= 0) return 0;
    return (coeficienteAKnPorMetro * coeficienteAKnPorMetro) /
        (2 * coeficienteBKnPorMetro2);
  }

  static double _energiaPorMetroKj({
    required double deformacionMetros,
    required double coeficienteAKnPorMetro,
    required double coeficienteBKnPorMetro2,
    required double coeficienteGKjPorMetro,
  }) {
    if (deformacionMetros <= 0) return 0;

    return (coeficienteAKnPorMetro * deformacionMetros) +
        (0.5 *
            coeficienteBKnPorMetro2 *
            deformacionMetros *
            deformacionMetros) +
        coeficienteGKjPorMetro;
  }
}
