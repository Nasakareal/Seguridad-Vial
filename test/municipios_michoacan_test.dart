import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/core/municipios_michoacan.dart';

void main() {
  test('catalog has the 113 Michoacan municipalities', () {
    expect(MunicipiosMichoacan.options, hasLength(113));
    expect(MunicipiosMichoacan.options, contains('SANTA ANA MAYA'));
    expect(MunicipiosMichoacan.options, contains('SALVADOR ESCALANTE'));
    expect(MunicipiosMichoacan.options, isNot(contains('SANTA CLARA')));
  });

  test('canonicalizes common municipality text variants', () {
    expect(MunicipiosMichoacan.canonical('Morelia, Michoacan'), 'MORELIA');
    expect(MunicipiosMichoacan.canonical('La Piedad'), 'LA PIEDAD');
    expect(MunicipiosMichoacan.canonical('Reyes, Los'), 'LOS REYES');
    expect(
      MunicipiosMichoacan.canonical('Santa Clara del Cobre'),
      'SALVADOR ESCALANTE',
    );
  });

  test('searches without accents or exact casing', () {
    expect(MunicipiosMichoacan.search('carde'), contains('LAZARO CARDENAS'));
    expect(MunicipiosMichoacan.search('tzint'), contains('TZINTZUNTZAN'));
    expect(MunicipiosMichoacan.search('alvaro'), contains('ALVARO OBREGON'));
  });
}
