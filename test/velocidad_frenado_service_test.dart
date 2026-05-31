import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/velocidad_frenado_service.dart';

void main() {
  test('calcula velocidad en camino nivelado', () {
    final resultado = VelocidadFrenadoService.calcular(
      const VelocidadFrenadoInput(
        distanciaMetros: 20,
        coeficienteFriccion: 0.7,
      ),
    );

    expect(resultado.factorArrastre, closeTo(0.7, 0.0001));
    expect(resultado.velocidadKilometrosHora, closeTo(59.7, 0.2));
    expect(resultado.velocidadMetrosSegundo, closeTo(16.6, 0.1));
  });

  test('suma pendiente ascendente al factor de arrastre', () {
    final resultado = VelocidadFrenadoService.calcular(
      const VelocidadFrenadoInput(
        distanciaMetros: 20,
        coeficienteFriccion: 0.7,
        pendientePorcentaje: 10,
        pendiente: PendienteFrenado.ascendente,
      ),
    );

    expect(resultado.factorArrastre, closeTo(0.8, 0.0001));
  });

  test('resta pendiente descendente al factor de arrastre', () {
    final resultado = VelocidadFrenadoService.calcular(
      const VelocidadFrenadoInput(
        distanciaMetros: 20,
        coeficienteFriccion: 0.7,
        pendientePorcentaje: 10,
        pendiente: PendienteFrenado.descendente,
      ),
    );

    expect(resultado.factorArrastre, closeTo(0.6, 0.0001));
  });

  test('requiere sentido de pendiente cuando no es cero', () {
    expect(
      () => VelocidadFrenadoService.calcular(
        const VelocidadFrenadoInput(
          distanciaMetros: 20,
          coeficienteFriccion: 0.7,
          pendientePorcentaje: 5,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('rechaza combinaciones descendentes fisicamente invalidas', () {
    expect(
      () => VelocidadFrenadoService.calcular(
        const VelocidadFrenadoInput(
          distanciaMetros: 20,
          coeficienteFriccion: 0.08,
          pendientePorcentaje: 10,
          pendiente: PendienteFrenado.descendente,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('rechaza distancia o friccion sin valor fisico', () {
    expect(
      () => VelocidadFrenadoService.calcular(
        const VelocidadFrenadoInput(
          distanciaMetros: 0,
          coeficienteFriccion: 0.7,
        ),
      ),
      throwsArgumentError,
    );

    expect(
      () => VelocidadFrenadoService.calcular(
        const VelocidadFrenadoInput(
          distanciaMetros: 20,
          coeficienteFriccion: 0,
        ),
      ),
      throwsArgumentError,
    );
  });
}
