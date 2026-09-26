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
      'Se detecta motocicleta sin casco protector.\n\n'
      'La persona conductora no presenta licencia vigente.',
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
      'Durante la intervención se detecta la conducta: Placas no vigentes.',
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
        'Narrativa automática.',
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
