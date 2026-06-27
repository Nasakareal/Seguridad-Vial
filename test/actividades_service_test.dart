import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/actividad.dart';
import 'package:seguridad_vial_app/models/actividad_categoria.dart';
import 'package:seguridad_vial_app/models/actividad_fomento.dart';
import 'package:seguridad_vial_app/models/actividad_subcategoria.dart';
import 'package:seguridad_vial_app/screens/actividades/actividad_ui_labels.dart';
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

  test('sends zero detained people when the field is left empty', () {
    const emptyTextData = ActividadUpsertData(
      actividadCategoriaId: 1,
      actividadSubcategoriaId: 2,
      personasDetenidas: '',
    );
    const nullData = ActividadUpsertData(
      actividadCategoriaId: 1,
      actividadSubcategoriaId: 2,
    );

    expect(emptyTextData.toFields()['personas_detenidas'], '0');
    expect(nullData.toFields()['personas_detenidas'], '0');
  });

  test(
    'allows activity captures without timestamp when server clock is used',
    () async {
      final error = await ActividadesService.validateBeforeSubmit(
        data: const ActividadUpsertData(
          actividadCategoriaId: 1,
          actividadSubcategoriaId: 2,
          municipio: 'MORELIA',
          personasAlcanzadas: '1',
          personasParticipantes: '0',
          personasDetenidas: '0',
        ),
        fotos: const <File>[],
        requirePhotos: false,
        requireCoords: false,
        requireTimestamp: false,
      );

      expect(error, isNull);
    },
  );

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

  test('caps activity participants input at fifteen', () {
    const formatter = NormalizedIntegerInputFormatter(
      max: ActividadesService.maxParticipantsCount,
    );

    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '15000'),
    );

    expect(result.text, '15');
  });

  test(
    'rejects activity captures with more than fifteen participants',
    () async {
      final error = await ActividadesService.validateBeforeSubmit(
        data: const ActividadUpsertData(
          actividadCategoriaId: 1,
          actividadSubcategoriaId: 2,
          fecha: '2026-04-25',
          lat: '19.7000000',
          lng: '-101.2000000',
          personasAlcanzadas: '1',
          personasParticipantes: '16',
          personasDetenidas: '0',
        ),
        fotos: const <File>[],
        requirePhotos: false,
      );

      expect(
        error,
        contains('Personas participantes no puede ser mayor a 15.'),
      );
    },
  );

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
    expect(
      ActividadesService.shouldRedirectC5iReportToHecho(
        categoriaNombre: 'Reportes C5i',
        subcategoriaNombre: 'Hechos de tránsito',
        userCanCaptureHechos: false,
      ),
      isFalse,
    );
  });

  test(
    'redirects delegaciones accident and siniestro activities to hechos',
    () {
      expect(
        ActividadesService.shouldRedirectDelegacionesActivityToHecho(
          categoriaNombre: 'Reportes de C5i',
          subcategoriaNombre: 'Accidentes',
        ),
        isTrue,
      );
      expect(
        ActividadesService.shouldRedirectDelegacionesActivityToHecho(
          categoriaNombre: 'Reportes de C5i',
          subcategoriaNombre: 'Hechos de tránsito',
        ),
        isTrue,
      );
      expect(
        ActividadesService.shouldRedirectDelegacionesActivityToHecho(
          categoriaNombre: 'Servicios',
          subcategoriaNombre: 'Siniestros',
        ),
        isTrue,
      );
    },
  );

  test('redirects delegaciones abanderamientos to hechos', () {
    expect(
      ActividadesService.shouldRedirectDelegacionesActivityToHecho(
        categoriaNombre: 'Abanderamientos',
        subcategoriaNombre: 'Cortes de circulación',
      ),
      isTrue,
    );
    expect(
      ActividadesService.shouldRedirectDelegacionesActivityToHecho(
        categoriaNombre: 'Abanderamientos',
        subcategoriaNombre: '',
      ),
      isTrue,
    );
  });

  test('does not redirect normal activities or users outside rule', () {
    expect(
      ActividadesService.shouldRedirectDelegacionesActivityToHecho(
        categoriaNombre: 'Monitoreos',
        subcategoriaNombre: 'Periféricos',
      ),
      isFalse,
    );
    expect(
      ActividadesService.shouldRedirectDelegacionesActivityToHecho(
        categoriaNombre: 'Reportes de C5i',
        subcategoriaNombre: 'Accidentes',
        appliesToUser: false,
      ),
      isFalse,
    );
    expect(
      ActividadesService.shouldRedirectDelegacionesActivityToHecho(
        categoriaNombre: 'Reportes de C5i',
        subcategoriaNombre: 'Accidentes',
        userCanCaptureHechos: false,
      ),
      isFalse,
    );
  });

  test('parses fomento metadata from activity catalogs', () {
    final unidad = ActividadRef.fromJson(const <String, dynamic>{
      'id': 2,
      'name': 'Delegaciones',
    });
    final categoria = ActividadCategoria.fromJson(const <String, dynamic>{
      'id': 10,
      'nombre': 'CAPACITACIONES',
      'slug': 'capacitaciones',
      'requiere_fomento_cultura_vial': true,
    });
    final subcategoria = ActividadSubcategoria.fromJson(const <String, dynamic>{
      'id': 20,
      'nombre': 'TALLER',
      'programas_fomento': <Map<String, dynamic>>[
        <String, dynamic>{'id': 7, 'nombre': 'PEATON SEGURO'},
      ],
    });

    expect(unidad.nombre, 'Delegaciones');
    expect(categoria.requiereFomentoCulturaVial, isTrue);
    expect(categoria.slug, 'capacitaciones');
    expect(subcategoria.programasFomento.single.id, 7);
    expect(subcategoria.programasFomento.single.nombre, 'PEATON SEGURO');
  });

  test('uses capacitaciones as default fomento category', () {
    const categorias = <ActividadCategoria>[
      ActividadCategoria(id: 1, nombre: 'Operativos'),
      ActividadCategoria(
        id: 2,
        nombre: 'CAPACITACIONES',
        slug: 'capacitaciones',
        requiereFomentoCulturaVial: true,
      ),
    ];

    expect(ActividadUiLabels.defaultFomentoCategoriaId(categorias), 2);
  });

  test('shortens talleres de seguridad vial only for fomento users', () {
    const subcategoria = ActividadSubcategoria(
      id: 10,
      nombre: 'Talleres de Seguridad Vial',
    );

    expect(
      ActividadUiLabels.subcategoriaNombre(subcategoria, isFomentoUser: true),
      'Talleres',
    );
    expect(
      ActividadUiLabels.subcategoriaNombre(subcategoria, isFomentoUser: false),
      'Talleres de Seguridad Vial',
    );
  });

  test('activity share payload adds hour fallback after date', () {
    final payload = ActividadNativeShareData.fromJson(const <String, dynamic>{
      'texto': 'ACTIVIDAD\nFecha: 2026-04-25\nMunicipio: MORELIA',
      'fotos': <String>['foto.jpg'],
    }).withHoraFallback('09:30:00');

    expect(
      payload.message,
      'ACTIVIDAD\nFecha: 2026-04-25\nHora: 09:30\nMunicipio: MORELIA',
    );
    expect(payload.media, <String>['foto.jpg']);
  });

  test('activity share payload does not duplicate existing hour', () {
    final payload = ActividadNativeShareData.fromJson(const <String, dynamic>{
      'texto': 'ACTIVIDAD\nFecha: 2026-04-25\nHora: 09:30',
    }).withHoraFallback('09:30:00');

    expect(payload.message.split('Hora:').length - 1, 1);
  });

  test('activity share payload can prefer original media paths', () {
    final payload = ActividadNativeShareData.fromJson(const <String, dynamic>{
      'texto': 'ACTIVIDAD',
      'fotos': <String>['thumb.jpg'],
    }).withMedia(<String>['original.jpg', 'original.jpg']);

    expect(payload.media, <String>['original.jpg']);
  });

  test('decodes activity index pagination metadata', () {
    final page = ActividadesIndexPage.fromJson(const <String, dynamic>{
      'data': <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'actividad_categoria_id': 10},
      ],
      'meta': <String, dynamic>{
        'current_page': 1,
        'last_page': 2,
        'per_page': 20,
        'total': 21,
      },
      'links': <String, dynamic>{'next': '/actividades?page=2'},
    });

    expect(page.items.single.id, 1);
    expect(page.currentPage, 1);
    expect(page.hasMore, isTrue);
  });

  test('decodes nested activity paginator responses', () {
    final page = ActividadesIndexPage.fromJson(const <String, dynamic>{
      'data': <String, dynamic>{
        'current_page': 2,
        'last_page': 2,
        'per_page': 20,
        'total': 21,
        'data': <Map<String, dynamic>>[
          <String, dynamic>{'id': 21, 'actividad_categoria_id': 10},
        ],
      },
    });

    expect(page.items.single.id, 21);
    expect(page.currentPage, 2);
    expect(page.hasMore, isFalse);
  });

  test('sends fomento detail fields using backend names', () {
    const data = ActividadUpsertData(
      actividadCategoriaId: 10,
      actividadSubcategoriaId: 20,
      fecha: '2026-04-25',
      municipio: 'MORELIA',
      personasAlcanzadas: '9',
      fomento: ActividadFomentoDetalle(
        programaId: 7,
        escuela: 'Primaria Benito Juarez',
        domicilio: 'Av. Principal 123',
        nivelEducativo: 'PRIMARIA',
        sector: 'CICLISTAS',
        ninas: 3,
        ninos: 4,
        mujeres: 2,
      ),
    );

    final fields = data.toFields();

    expect(fields['fomento[programa_id]'], '7');
    expect(fields['fomento[nombre_institucion]'], 'Primaria Benito Juarez');
    expect(fields['fomento[escuela]'], 'Primaria Benito Juarez');
    expect(fields['fomento[domicilio]'], 'Av. Principal 123');
    expect(fields['fomento[nivel_educativo]'], 'PRIMARIA');
    expect(fields['fomento[sector]'], 'CICLISTAS');
    expect(fields['fomento[ninas]'], '3');
    expect(fields['fomento[ninos]'], '4');
    expect(fields['fomento[mujeres]'], '2');
    expect(fields['fomento[total_poblacion_atendida]'], '9');
  });

  test('allows zero reached people when fomento total is zero', () async {
    final issues = await ActividadesService.validateBeforeSubmitIssues(
      data: const ActividadUpsertData(
        actividadCategoriaId: 10,
        actividadSubcategoriaId: 20,
        fecha: '2026-04-25',
        municipio: 'MORELIA',
        personasAlcanzadas: '0',
        personasParticipantes: '0',
        personasDetenidas: '0',
        fomento: ActividadFomentoDetalle(),
      ),
      fotos: const <File>[],
      requirePhotos: false,
      requireCoords: false,
    );

    expect(
      issues.map((issue) => issue.message),
      isNot(contains('Personas alcanzadas debe ser al menos 1.')),
    );
  });

  test('prioritizes fomento subcategories with programs first', () {
    final ordered = ActividadesService.prioritizeFomentoSubcategorias(
      <ActividadSubcategoria>[
        const ActividadSubcategoria(id: 1, nombre: 'ZETA'),
        const ActividadSubcategoria(
          id: 2,
          nombre: 'BICICLETA',
          programasFomento: <ActividadFomentoPrograma>[
            ActividadFomentoPrograma(id: 10, nombre: 'RODADA SEGURA'),
          ],
        ),
        const ActividadSubcategoria(
          id: 3,
          nombre: 'PEATON',
          programasFomento: <ActividadFomentoPrograma>[
            ActividadFomentoPrograma(id: 11, nombre: 'PEATON SEGURO'),
          ],
        ),
        const ActividadSubcategoria(id: 4, nombre: 'ALFA'),
      ],
    );

    expect(ordered.map((item) => item.id), <int>[2, 3, 4, 1]);
  });
}
