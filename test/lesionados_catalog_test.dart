import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/core/lesionados/lesionados_catalog.dart';

void main() {
  test('normalizes lesionado victim type variants', () {
    expect(LesionadosCatalog.tipoVictimaValue('Peaton'), 'Peatón');
    expect(
      LesionadosCatalog.tipoVictimaValue(' motociclista '),
      'Motociclista',
    );
  });

  test('rejects unknown lesionado victim types', () {
    expect(LesionadosCatalog.tipoVictimaValue('Copiloto'), isNull);
    expect(LesionadosCatalog.tipoVictimaValue(''), isNull);
  });
}
