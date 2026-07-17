import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/puestas_disposicion_service.dart';

void main() {
  test('catálogo de motivos coincide con las reglas del backend', () {
    expect(PuestaDisposicionCatalog.motivos, contains('PERSONA DETENIDA'));
    expect(
      PuestaDisposicionCatalog.motivos,
      contains('HECHO DE TRANSITO TURNADO'),
    );
    expect(
      PuestaDisposicionCatalog.motivos.last,
      PuestaDisposicionCatalog.motivoOtro,
    );
    expect(PuestaDisposicionCatalog.motivos.toSet().length, 26);
  });

  test('tipos de puesta incluyen las cuatro opciones del backend', () {
    expect(PuestaDisposicionCatalog.tipos, <String>[
      'PERSONA',
      'VEHICULO',
      'OBJETO',
      'MIXTA',
    ]);
  });
}
