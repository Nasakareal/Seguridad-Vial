import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/conduce_legalidad_persona_descriptor.dart';

void main() {
  test('builds detained person description from selected options', () {
    final description = ConduceLegalidadPersonaDescriptor.buildDescription(
      edadAproximada: '25 a 34 anos',
      complexion: 'Media',
      estatura: 'Alta',
      tez: 'Morena',
      cabello: 'Corto',
      prendaSuperior: 'Playera',
      colorSuperior: 'Negro',
      prendaInferior: 'Pantalon de mezclilla',
      colorInferior: 'Azul',
      calzado: 'Tenis',
      colorCalzado: 'Blanco',
      rasgos: const <String>['Barba', 'Tatuajes', 'Cicatrices'],
    );

    expect(description, contains('Edad aproximada: 25 a 34 anos.'));
    expect(description, contains('complexion Media'));
    expect(description, contains('parte superior Playera color Negro'));
    expect(description, contains('parte inferior Pantalon de mezclilla'));
    expect(description, contains('calzado Tenis color Blanco'));
    expect(description, contains('Rasgos visibles: Barba, Tatuajes'));
  });

  test('maps selected age range to approximate integer age', () {
    expect(
      ConduceLegalidadPersonaDescriptor.edadAproximadaToInt('18 a 24 anos'),
      21,
    );
    expect(
      ConduceLegalidadPersonaDescriptor.edadAproximadaToInt('No apreciable'),
      isNull,
    );
  });

  test('keeps no apreciable clothing description concise', () {
    final description = ConduceLegalidadPersonaDescriptor.buildDescription(
      prendaSuperior: 'No apreciable',
      colorSuperior: 'No apreciable',
      prendaInferior: 'Pantalon de mezclilla',
      colorInferior: 'No apreciable',
      calzado: 'No apreciable',
      colorCalzado: 'Negro',
    );

    expect(description, contains('parte superior no apreciable'));
    expect(description, contains('parte inferior Pantalon de mezclilla'));
    expect(description, contains('calzado color Negro'));
    expect(description, isNot(contains('No apreciable color No apreciable')));
  });
}
