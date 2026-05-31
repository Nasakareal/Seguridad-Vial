import 'dart:math' as math;

enum PendienteFrenado { nivel, ascendente, descendente }

class VelocidadFrenadoInput {
  final double distanciaMetros;
  final double coeficienteFriccion;
  final double pendientePorcentaje;
  final PendienteFrenado pendiente;

  const VelocidadFrenadoInput({
    required this.distanciaMetros,
    required this.coeficienteFriccion,
    this.pendientePorcentaje = 0,
    this.pendiente = PendienteFrenado.nivel,
  });
}

class VelocidadFrenadoResult {
  final double factorArrastre;
  final double velocidadMetrosSegundo;
  final double velocidadKilometrosHora;

  const VelocidadFrenadoResult({
    required this.factorArrastre,
    required this.velocidadMetrosSegundo,
    required this.velocidadKilometrosHora,
  });

  double get velocidadMillasHora => velocidadKilometrosHora * 0.6213711922;
}

class VelocidadFrenadoService {
  static const double gravedadMetrosSegundo2 = 9.80665;

  const VelocidadFrenadoService._();

  static VelocidadFrenadoResult calcular(VelocidadFrenadoInput input) {
    if (input.distanciaMetros <= 0) {
      throw ArgumentError.value(
        input.distanciaMetros,
        'distanciaMetros',
        'La distancia debe ser mayor a cero.',
      );
    }

    if (input.coeficienteFriccion <= 0) {
      throw ArgumentError.value(
        input.coeficienteFriccion,
        'coeficienteFriccion',
        'El coeficiente de fricción debe ser mayor a cero.',
      );
    }

    if (input.pendientePorcentaje < 0) {
      throw ArgumentError.value(
        input.pendientePorcentaje,
        'pendientePorcentaje',
        'La pendiente no puede ser negativa.',
      );
    }

    if (input.pendiente == PendienteFrenado.nivel &&
        input.pendientePorcentaje > 0) {
      throw ArgumentError.value(
        input.pendientePorcentaje,
        'pendientePorcentaje',
        'Selecciona si la pendiente es ascendente o descendente.',
      );
    }

    final factorArrastre = calcularFactorArrastre(
      coeficienteFriccion: input.coeficienteFriccion,
      pendientePorcentaje: input.pendientePorcentaje,
      pendiente: input.pendiente,
    );

    if (factorArrastre <= 0) {
      throw ArgumentError(
        'La combinación de pendiente descendente y fricción no permite '
        'calcular un frenado físicamente válido.',
      );
    }

    final velocidadMs = math.sqrt(
      2 * gravedadMetrosSegundo2 * factorArrastre * input.distanciaMetros,
    );

    return VelocidadFrenadoResult(
      factorArrastre: factorArrastre,
      velocidadMetrosSegundo: velocidadMs,
      velocidadKilometrosHora: velocidadMs * 3.6,
    );
  }

  static double calcularFactorArrastre({
    required double coeficienteFriccion,
    required double pendientePorcentaje,
    required PendienteFrenado pendiente,
  }) {
    final grado = pendientePorcentaje.abs() / 100;

    return switch (pendiente) {
      PendienteFrenado.nivel => coeficienteFriccion,
      PendienteFrenado.ascendente => coeficienteFriccion + grado,
      PendienteFrenado.descendente => coeficienteFriccion - grado,
    };
  }
}
