import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/actividad.dart';
import 'package:seguridad_vial_app/models/actividad_categoria.dart';
import 'package:seguridad_vial_app/models/actividad_subcategoria.dart';
import 'package:seguridad_vial_app/services/motociclista_report_service.dart';

void main() {
  test('builds institutional text for abanderamiento reports', () {
    const draft = MotociclistaReportDraft(
      kind: MotociclistaReportKind.abanderamiento,
      fecha: '2026-06-06',
      hora: '09:15',
      ubicacion: 'Av. Camelinas frente a Plaza Morelia',
      lat: '19.700000',
      lng: '-101.180000',
      coordenadas: '19.700000, -101.180000',
      tipoPreliminar: 'Choque',
      lesionados: 'Se desconoce',
      estado: 'En espera de UAS',
      descripcion: 'Se mantiene protección en carril derecho.',
      unidadCrp: 'CRP-120',
      numeroElementos: '2',
      informa: 'Juan Pérez',
    );

    final text = MotociclistaReportService.buildInstitutionalText(draft);

    expect(text, contains('GUARDIA CIVIL'));
    expect(text, contains('ASUNTO: ABANDERAMIENTO POR HECHO DE TRÁNSITO'));
    expect(text, contains('COORDENADAS: 19.7000000, -101.1800000'));
    expect(
      text,
      contains(
        'GOOGLE MAPS: https://www.google.com/maps?q=19.7000000,-101.1800000',
      ),
    );
    expect(text, contains('Av. Camelinas frente a Plaza Morelia'));
    expect(text, contains('Choque'));
    expect(text, contains('En espera de UAS'));
    expect(text, contains('2 elementos'));
    expect(text, contains('CRP-120'));
    expect(text, contains('Juan Pérez'));
  });

  test('validates required fields and maps report to activity payload', () {
    const draft = MotociclistaReportDraft(
      kind: MotociclistaReportKind.monitoreoSinNovedad,
      fecha: '2026-06-06',
      hora: '10:20',
      ubicacion: '',
      lat: '',
      lng: '',
      coordenadas: '',
      zonaMonitoreada: 'Avenidas',
      kilometrosRecorridos: '0',
      unidadCrp: 'MOTOCICLISTA',
      numeroElementos: '1',
      informa: 'María López',
    );

    expect(
      MotociclistaReportService.validateDraft(draft, photoCount: 0),
      isEmpty,
    );

    final data = MotociclistaReportService.buildActividadData(
      draft: draft,
      catalog: const MotociclistaCatalogSelection(
        categoria: ActividadCategoria(id: 10, nombre: 'Vialidades Urbanas'),
        subcategoria: ActividadSubcategoria(id: 20, nombre: 'Monitoreo'),
      ),
    );

    final fields = data.toFields();
    expect(fields['actividad_categoria_id'], '10');
    expect(fields['actividad_subcategoria_id'], '20');
    expect(fields['lugar'], 'Lugar informado');
    expect(fields['municipio'], 'MORELIA');
    expect(fields['personas_participantes'], '1');
    expect(fields['patrullas_participantes_texto'], 'MOTOCICLISTA');
    expect(fields['narrativa'], contains('MONITOREO SIN NOVEDAD'));
  });

  test('uses fixed activity catalog targets for statistics', () {
    MotociclistaCatalogTarget target(MotociclistaReportKind kind) {
      return MotociclistaReportService.catalogTargetFor(
        MotociclistaReportDraft(
          kind: kind,
          fecha: '2026-06-06',
          hora: '10:20',
          ubicacion: '',
          lat: '',
          lng: '',
          coordenadas: '',
          zonaMonitoreada: kind == MotociclistaReportKind.monitoreoSinNovedad
              ? 'Periférico'
              : '',
        ),
      );
    }

    expect(
      target(MotociclistaReportKind.abanderamiento).categoria,
      'ABANDERAMIENTOS',
    );
    expect(
      target(MotociclistaReportKind.abanderamiento).subcategoria,
      'ACCIDENTES',
    );
    expect(
      target(MotociclistaReportKind.apoyoPreventivo).categoria,
      'DISPOSITIVOS DE SEGURIDAD VIAL',
    );
    expect(
      target(MotociclistaReportKind.apoyoPreventivo).subcategoria,
      'APOYO A LA VIALIDAD',
    );
    expect(
      target(MotociclistaReportKind.cierreVialidad).categoria,
      'ABANDERAMIENTOS',
    );
    expect(
      target(MotociclistaReportKind.cierreVialidad).subcategoria,
      'CORTES DE CIRCULACIÓN',
    );
    expect(
      target(MotociclistaReportKind.dispositivoVial).categoria,
      'DISPOSITIVOS DE SEGURIDAD VIAL',
    );
    expect(
      target(MotociclistaReportKind.dispositivoVial).subcategoria,
      'APOYO A LA VIALIDAD',
    );
    expect(
      target(MotociclistaReportKind.monitoreoSinNovedad).subcategoria,
      'PERIFÉRICOS',
    );
  });

  test('builds clean share text for existing motociclista activities', () {
    const draft = MotociclistaReportDraft(
      kind: MotociclistaReportKind.apoyoPreventivo,
      fecha: '2026-06-06',
      hora: '22:17',
      ubicacion: 'Ubicación GPS 19.697543, -101.277612',
      lat: '19.697543',
      lng: '-101.277612',
      coordenadas: '19.697543, -101.277612',
      motivo: 'Apoyo a la vialidad',
      unidadCrp: 'MOTOCICLISTA',
      numeroElementos: '1',
      informa: 'vialidad',
    );
    final narrativa = MotociclistaReportService.buildInstitutionalText(draft);
    final actividad = Actividad(
      id: 12400,
      actividadCategoriaId: 8,
      actividadSubcategoriaId: 49,
      nombre: '',
      cantidad: 1,
      fotoPath: null,
      fotoPreviewPath: null,
      fotoNombreOriginal: null,
      fotoHash: null,
      createdAt: DateTime(2026, 6, 6, 22, 17),
      updatedAt: null,
      fecha: '2026-06-06',
      hora: '22:17',
      lugar: 'Ubicación GPS 19.697543, -101.277612',
      municipio: 'MORELIA',
      carretera: null,
      tramo: null,
      kilometro: null,
      lat: 19.697543,
      lng: -101.277612,
      kmRecorridos: null,
      coordenadasTexto: '19.697543, -101.277612',
      fuenteUbicacion: 'GPS_APP',
      notaGeo: null,
      motivo: 'Apoyo a la vialidad',
      narrativa: narrativa,
      accionesRealizadas: 'Apoyo vial preventivo.',
      observaciones: 'Reporte Motociclista: Apoyo vial preventivo',
      personasAlcanzadas: 1,
      personasParticipantes: 1,
      personasDetenidas: 0,
      elementosParticipantesTexto: '1 elementos',
      patrullasParticipantesTexto: MotociclistaReportService.reportSourceMarker,
      destacamentoId: null,
      categoria: const ActividadCategoria(
        id: 8,
        nombre: 'DISPOSITIVOS DE SEGURIDAD VIAL',
      ),
      subcategoria: const ActividadSubcategoria(
        id: 49,
        nombre: 'APOYO A LA VIALIDAD',
      ),
      unidad: null,
      delegacion: null,
      destacamento: null,
      fotos: const <ActividadFoto>[],
      vehiculos: const <ActividadVehiculo>[],
      fomentoCulturaVialDetalle: null,
    );

    final text = MotociclistaReportService.buildShareTextFromActividad(
      actividad,
      informaFallback: 'Operador',
    );

    expect(RegExp('GUARDIA CIVIL').allMatches(text), hasLength(1));
    expect(text, contains('ID DE ACTIVIDAD: 12400'));
    expect(text, contains('COORDENADAS: 19.6975430, -101.2776120'));
    expect(
      text,
      contains(
        'GOOGLE MAPS: https://www.google.com/maps?q=19.6975430,-101.2776120',
      ),
    );
    expect(text, contains('ASUNTO: APOYO VIAL PREVENTIVO'));
    expect(text, contains('INFORMA:\nvialidad'));
    expect(text, isNot(contains('DATOS GENERALES')));
    expect(text, isNot(contains('RESPETUOSAMENTE')));
  });
}
