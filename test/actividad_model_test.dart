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

    test('lee la puesta a disposición vinculada', () {
      final actividad = Actividad.fromJson({
        'id': 10,
        'puesta_disposicion': {'id': 42},
      });

      expect(actividad.puestaDisposicionId, 42);
      expect(actividad.toJson()['puesta_disposicion_id'], 42);
    });

    test('lee el creador para resaltar actividades propias', () {
      final actividad = Actividad.fromJson({
        'id': 8,
        'created_by': 42,
        'actividad_categoria_id': 3,
      });

      expect(actividad.createdBy, 42);
      expect(actividad.toJson()['created_by'], 42);
    });

    test('lee el vínculo y fundamentos de Conduce con Legalidad', () {
      final actividad = Actividad.fromJson({
        'id': 11,
        'conduce_legalidad_operativo_id': 7,
        'conduce_legalidad_captura_id': 21,
        'conduce_legalidad_fundamentos': [
          {
            'id': 4,
            'codigo': 'ART-4',
            'nombre': 'Sin placa',
            'retencion_vehiculo': true,
          },
        ],
      });

      expect(actividad.conduceLegalidadOperativoId, 7);
      expect(actividad.conduceLegalidadCapturaId, 21);
      expect(actividad.conduceLegalidadFundamentos, hasLength(1));
      expect(actividad.conduceLegalidadFundamentos.single.codigo, 'ART-4');
      expect(actividad.toJson()['conduce_legalidad_operativo_id'], 7);
      expect(
        actividad.toJson()['conduce_legalidad_fundamentos'],
        isA<List<dynamic>>(),
      );
    });
  });
}
