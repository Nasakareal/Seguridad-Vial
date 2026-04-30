import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/actividades_service.dart';

void main() {
  test('validates activity captures before they enter offline queue', () async {
    final error = await ActividadesService.validateBeforeSubmit(
      data: const ActividadUpsertData(
        actividadCategoriaId: 0,
        actividadSubcategoriaId: null,
        fecha: '',
        personasAlcanzadas: '',
      ),
      fotos: const <File>[],
    );

    expect(error, isNotNull);
    expect(error, contains('Selecciona una categoría.'));
    expect(error, contains('Selecciona una subcategoría.'));
    expect(error, contains('Captura la ubicación'));
    expect(error, contains('Selecciona al menos una foto.'));
    expect(error, contains('Personas alcanzadas debe ser al menos 1.'));
  });

  test('accepts a valid minimal activity capture', () async {
    final dir = await Directory.systemTemp.createTemp('actividad_test_');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    final foto = File('${dir.path}${Platform.pathSeparator}foto.jpg');
    await foto.writeAsBytes(<int>[1, 2, 3]);

    final error = await ActividadesService.validateBeforeSubmit(
      data: const ActividadUpsertData(
        actividadCategoriaId: 1,
        actividadSubcategoriaId: 2,
        fecha: '2026-04-25',
        hora: '09:30',
        lat: '19.7000000',
        lng: '-101.2000000',
        personasAlcanzadas: '1',
        personasParticipantes: '0',
        personasDetenidas: '0',
      ),
      fotos: <File>[foto],
    );

    expect(error, isNull);
  });
}
