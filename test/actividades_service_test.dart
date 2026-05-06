import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/actividad.dart';
import 'package:seguridad_vial_app/services/actividades_service.dart';
import 'package:seguridad_vial_app/widgets/normalized_integer_input_formatter.dart';

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
        municipio: 'MORELIA',
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

  test('rejects activity captures with unknown municipalities', () async {
    final error = await ActividadesService.validateBeforeSubmit(
      data: const ActividadUpsertData(
        actividadCategoriaId: 1,
        actividadSubcategoriaId: 2,
        fecha: '2026-04-25',
        municipio: 'mirilia',
        lat: '19.7000000',
        lng: '-101.2000000',
        personasAlcanzadas: '1',
        personasParticipantes: '0',
        personasDetenidas: '0',
      ),
      fotos: const <File>[],
      requirePhotos: false,
    );

    expect(error, contains('Selecciona un municipio de Michoacan.'));
  });

  test('activity vehicle api payload keeps selected grua id and name', () {
    final vehiculo = ActividadVehiculo(
      marca: 'NISSAN',
      tipo: 'Sedán',
      linea: 'TSURU',
      color: 'BLANCO',
      capacidadPersonas: 5,
      tipoServicio: 'PARTICULAR',
      gruaId: 12,
      grua: 'GRÚAS CENTRO',
      corralonId: 20,
      corralon: 'CORRALÓN CENTRO',
      antecedenteVehiculo: false,
    );

    final payload = vehiculo.toApiJson();

    expect(payload['grua_id'], 12);
    expect(payload['grua'], 'GRÚAS CENTRO');
    expect(payload['corralon'], 'CORRALÓN CENTRO');
    expect(payload.containsKey('corralon_id'), isFalse);
  });

  test('normalizes activity integer inputs while typing', () {
    const formatter = NormalizedIntegerInputFormatter();

    TextEditingValue format(String text) {
      return formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: text),
      );
    }

    expect(format('01').text, '1');
    expect(format('00100').text, '100');
    expect(format('000001').text, '1');
    expect(format('000').text, '0');
  });

  test('caps detained activity input at three', () {
    const formatter = NormalizedIntegerInputFormatter(
      max: ActividadesService.maxDetainedCount,
    );

    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '40'),
    );

    expect(result.text, '3');
  });

  test(
    'rejects activity captures with more than three detained people',
    () async {
      final error = await ActividadesService.validateBeforeSubmit(
        data: const ActividadUpsertData(
          actividadCategoriaId: 1,
          actividadSubcategoriaId: 2,
          fecha: '2026-04-25',
          lat: '19.7000000',
          lng: '-101.2000000',
          personasAlcanzadas: '1',
          personasParticipantes: '1',
          personasDetenidas: '4',
        ),
        fotos: const <File>[],
        requirePhotos: false,
      );

      expect(error, contains('Personas detenidas no puede ser mayor a 3.'));
    },
  );

  test('warns before saving suspicious activity people counts', () {
    final warnings = ActividadesService.peopleCountWarnings(
      const ActividadUpsertData(
        actividadCategoriaId: 1,
        actividadSubcategoriaId: 2,
        fecha: '2026-04-25',
        personasAlcanzadas: '1000',
        personasParticipantes: '5',
        personasDetenidas: '3',
      ),
    );

    expect(warnings, anyElement(contains('Personas alcanzadas tiene 1000')));
    expect(warnings, anyElement(contains('Personas participantes tiene 5')));
    expect(warnings, anyElement(contains('Personas detenidas tiene 3')));
    expect(
      warnings,
      everyElement(anyOf(contains('operativo'), contains('alta'))),
    );
  });

  test('warns when activity participants are zero', () {
    final warnings = ActividadesService.peopleCountWarnings(
      const ActividadUpsertData(
        actividadCategoriaId: 1,
        actividadSubcategoriaId: 2,
        fecha: '2026-04-25',
        personasAlcanzadas: '1',
        personasParticipantes: '0',
        personasDetenidas: '0',
      ),
    );

    expect(warnings, anyElement(contains('Personas participantes está en 0')));
  });

  test('redirects C5i transit reports to hechos capture', () {
    expect(
      ActividadesService.shouldRedirectC5iReportToHecho(
        categoriaNombre: 'Reportes C5i',
        subcategoriaNombre: 'Hechos de tránsito',
      ),
      isTrue,
    );
    expect(
      ActividadesService.shouldRedirectC5iReportToHecho(
        categoriaNombre: 'REPORTES C5I',
        subcategoriaNombre: 'Siniestros',
      ),
      isTrue,
    );
    expect(
      ActividadesService.shouldRedirectC5iReportToHecho(
        categoriaNombre: 'Reportes C5i',
        subcategoriaNombre: 'Apoyo ciudadano',
      ),
      isFalse,
    );
  });
}
