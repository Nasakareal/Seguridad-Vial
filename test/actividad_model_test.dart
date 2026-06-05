import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/actividad.dart';

void main() {
  group('Actividad', () {
    test('normaliza la hora recibida del backend', () {
      expect(Actividad.fromJson({'id': 1, 'hora': '09:30:00'}).hora, '09:30');
      expect(
        Actividad.fromJson({
          'id': 2,
          'hora': '2026-06-05T13:45:00.000000Z',
        }).hora,
        '13:45',
      );
      expect(Actividad.fromJson({'id': 3, 'hora': '2026-'}).hora, isNull);
    });
  });
}
