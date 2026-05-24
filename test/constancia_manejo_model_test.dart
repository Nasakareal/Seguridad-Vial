import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/constancia_manejo.dart';

void main() {
  ConstanciaManejo makeConstancia(Map<String, dynamic> overrides) {
    return ConstanciaManejo.fromJson(<String, dynamic>{
      'id': 1,
      'folio': 'D-0001',
      'qr_token': 'token',
      'estatus': 'IMPRESA_INACTIVA',
      ...overrides,
    });
  }

  test('folio impreso de lote puede activarse sin flujo de examen', () {
    final constancia = makeConstancia(<String, dynamic>{});

    expect(constancia.tieneFlujoExamen, isFalse);
    expect(constancia.puedeActivarDirectamente, isTrue);
  });

  test('constancia con examen conserva flujo de examen', () {
    final constancia = makeConstancia(<String, dynamic>{
      'tipo_examen': 'LINEA',
      'resultado': 'APROBADO',
      'examen': <String, dynamic>{
        'modalidad': 'LINEA',
        'resultado': 'APROBADO',
      },
    });

    expect(constancia.tieneFlujoExamen, isTrue);
    expect(constancia.puedeActivarDirectamente, isFalse);
  });
}
