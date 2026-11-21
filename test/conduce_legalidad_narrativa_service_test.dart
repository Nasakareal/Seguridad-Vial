import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/conduce_legalidad.dart';
import 'package:seguridad_vial_app/services/conduce_legalidad_narrativa_service.dart';

void main() {
  test('combina las narrativas seleccionadas sin duplicarlas', () {
    const primero = ConduceLegalidadFundamento(
      id: 1,
      nombre: 'Sin casco',
      puntos: 0,
      retencionVehiculo: false,
      narrativaSugerida: 'Se detecta motocicleta sin casco protector.',
    );
    const repetido = ConduceLegalidadFundamento(
      id: 2,
      nombre: 'Casco',
      puntos: 0,
      retencionVehiculo: false,
      narrativaSugerida: ' Se detecta motocicleta sin casco protector. ',
    );
    const segundo = ConduceLegalidadFundamento(
      id: 3,
      nombre: 'Sin licencia',
      puntos: 0,
      retencionVehiculo: false,
      narrativaSugerida: 'La persona conductora no presenta licencia vigente.',
    );

    expect(
      ConduceLegalidadNarrativaService.build([primero, repetido, segundo]),
      'Al encontrarse en labores de vigilancia, el agente observó una motocicleta sin casco protector, motivo por el cual le indicó el alto a la persona conductora y realizó la intervención correspondiente.\n\n'
      'Durante la revisión derivada de la intervención, también se constató que la persona conductora no presenta licencia vigente.\n\n'
      'Se informó a la persona conductora el motivo de la intervención y los fundamentos aplicables, y se continuó con el procedimiento correspondiente.',
    );
  });

  test('genera un texto sencillo cuando el catálogo no trae sugerencia', () {
    const fundamento = ConduceLegalidadFundamento(
      id: 4,
      nombre: 'Placas no vigentes',
      puntos: 0,
      retencionVehiculo: false,
    );

    expect(
      ConduceLegalidadNarrativaService.build([fundamento]),
      'Al encontrarse en labores de vigilancia, el agente observó la conducta consistente en placas no vigentes, motivo por el cual le indicó el alto a la persona conductora y realizó la intervención correspondiente.\n\n'
      'Se informó a la persona conductora el motivo de la intervención y los fundamentos aplicables, y se continuó con el procedimiento correspondiente.',
    );
  });

  test('reconoce la narrativa correspondiente a la selección actual', () {
    const fundamento = ConduceLegalidadFundamento(
      id: 5,
      nombre: 'Sin casco',
      puntos: 0,
      retencionVehiculo: false,
      narrativaSugerida: 'Narrativa automática.',
    );

    expect(
      ConduceLegalidadNarrativaService.matchesSelection(
        ConduceLegalidadNarrativaService.build([fundamento]),
        [fundamento],
      ),
      isTrue,
    );
    expect(
      ConduceLegalidadNarrativaService.matchesSelection(
        'Texto corregido por el usuario.',
        [fundamento],
      ),
      isFalse,
    );
  });
}
