import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/vialidades_urbanas_form_service.dart';

void main() {
  VialidadesUrbanasFormPayload payload({required String municipio}) {
    return VialidadesUrbanasFormPayload(
      catalogoId: 1,
      fecha: DateTime(2026, 5, 5),
      hora: const TimeOfDay(hour: 9, minute: 30),
      asunto: 'Operativo de prueba',
      municipio: municipio,
      lugar: 'Centro',
      evento: '',
      objetivo: '',
      descripcion: '',
      narrativa: '',
      accionesRealizadas: '',
      observaciones: '',
      supervision: '',
      elementos: 0,
      crp: 0,
      motopatrullas: 0,
      fenix: 0,
      unidadesMotorizadas: 0,
      patrullas: 0,
      gruas: 0,
      otrosApoyos: 0,
      fotos: const [],
    );
  }

  test('rejects vialidades captures with unknown municipalities', () async {
    final error = await VialidadesUrbanasFormService.validateBeforeSubmit(
      payload: payload(municipio: 'mirilia'),
    );

    expect(error, 'Selecciona un municipio de Michoacan.');
  });

  test(
    'accepts vialidades captures with catalog municipality variants',
    () async {
      final error = await VialidadesUrbanasFormService.validateBeforeSubmit(
        payload: payload(municipio: 'Morelia, Michoacan'),
      );

      expect(error, isNull);
    },
  );
}
