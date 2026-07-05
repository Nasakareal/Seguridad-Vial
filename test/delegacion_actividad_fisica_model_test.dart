import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/delegacion_actividad_fisica.dart';

void main() {
  group('DelegacionActividadFisica', () {
    test('normaliza campos principales del payload del backend', () {
      final actividad = DelegacionActividadFisica.fromJson({
        'id': 7,
        'delegacion_id': '3',
        'delegacion': {
          'id': 3,
          'clave': 'MOR-01',
          'nombre': 'Morelia',
          'municipio': 'Morelia',
        },
        'fecha': '2026-07-04',
        'hora': '09:35:00',
        'tipo_ejercicio': 'ACONDICIONAMIENTO',
        'elementos_participantes': '18',
        'foto_url': 'https://example.test/foto.jpg',
        'capturo': {'id': 2, 'name': 'Operador'},
      });

      expect(actividad.id, 7);
      expect(actividad.delegacionId, 3);
      expect(actividad.fechaCorta, '04/07/2026');
      expect(actividad.hora, '09:35');
      expect(actividad.elementosParticipantes, 18);
      expect(actividad.delegacionLabel, 'MOR-01 - Morelia - Morelia');
      expect(actividad.capturoLabel, 'Operador');
    });
  });
}
