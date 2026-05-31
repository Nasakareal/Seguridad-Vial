import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/velocidad_deformacion_service.dart';

void main() {
  test('calcula energia y EES con perfil uniforme sin G explicito', () {
    final resultado = VelocidadDeformacionService.calcular(
      const VelocidadDeformacionInput(
        masaKg: 1500,
        anchoDanoMetros: 1.5,
        coeficienteAKnPorMetro: 300,
        coeficienteBKnPorMetro2: 1500,
        coeficienteGKjPorMetro: 0,
        deformacionesCm: [20, 20, 20, 20, 20, 20],
      ),
    );

    expect(resultado.energiaKj, closeTo(135, 0.01));
    expect(resultado.velocidadEquivalenteKmh, closeTo(48.3, 0.1));
  });

  test('calcula G desde A y B cuando no se captura explicitamente', () {
    final resultado = VelocidadDeformacionService.calcular(
      const VelocidadDeformacionInput(
        masaKg: 1500,
        anchoDanoMetros: 1.5,
        coeficienteAKnPorMetro: 300,
        coeficienteBKnPorMetro2: 1500,
        deformacionesCm: [20, 20, 20, 20, 20, 20],
      ),
    );

    expect(resultado.coeficienteGUsadoKjPorMetro, closeTo(30, 0.01));
    expect(resultado.energiaKj, closeTo(180, 0.01));
    expect(resultado.velocidadEquivalenteKmh, closeTo(55.7, 0.2));
  });

  test('rechaza entradas sin sentido fisico', () {
    expect(
      () => VelocidadDeformacionService.calcular(
        const VelocidadDeformacionInput(
          masaKg: 0,
          anchoDanoMetros: 1.5,
          coeficienteAKnPorMetro: 300,
          coeficienteBKnPorMetro2: 1500,
          deformacionesCm: [20, 20],
        ),
      ),
      throwsArgumentError,
    );

    expect(
      () => VelocidadDeformacionService.calcular(
        const VelocidadDeformacionInput(
          masaKg: 1500,
          anchoDanoMetros: 1.5,
          coeficienteAKnPorMetro: 300,
          coeficienteBKnPorMetro2: 1500,
          deformacionesCm: [0, 0, 0, 0, 0, 0],
        ),
      ),
      throwsArgumentError,
    );
  });
}
