import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/core/hechos/hechos_catalogos.dart';
import 'package:seguridad_vial_app/models/hecho_form_data.dart';
import 'package:seguridad_vial_app/screens/accidentes/widgets/hecho_form.dart';
import 'package:seguridad_vial_app/services/auth_service.dart';
import 'package:seguridad_vial_app/services/local_draft_service.dart';
import 'package:seguridad_vial_app/services/offline_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_session_owner_key': 'user:1',
      'auth_unidad_id': AuthService.unidadDelegacionesId,
      'auth_role': 'Policia',
    });
  });

  HechoFormData validDelegacionesData() {
    return HechoFormData()
      ..perito = 'Elemento de prueba'
      ..unidad = 'Unidad 01'
      ..hora = const TimeOfDay(hour: 9, minute: 30)
      ..fecha = DateTime(2026, 4, 25)
      ..calle = 'Lugar de prueba'
      ..colonia = 'Centro'
      ..municipio = 'Morelia'
      ..tipoHecho = HechosCatalogos.tiposHecho.first
      ..superficieVia = HechosCatalogos.superficiesViaUi.first
      ..tiempo = HechosCatalogos.tiemposUi.first
      ..clima = HechosCatalogos.climasUi.first
      ..condiciones = HechosCatalogos.condicionesUi.first
      ..controlTransito = HechosCatalogos.controlesTransitoUi.last
      ..causa = HechosCatalogos.causasUi.first
      ..responsable = HechosCatalogos.responsablesUi.first
      ..colisionCamino = HechosCatalogos.colisionCaminoUi.first
      ..situacion = 'TURNADO'
      ..vehiculosMp = '0'
      ..personasMp = ''
      ..vehiculosEsperados = '0'
      ..conductoresEsperados = '0'
      ..lesionadosEsperados = '0'
      ..lat = 19.7
      ..lng = -101.2;
  }

  testWidgets('delegaciones pending ignores stale MP validators', (
    tester,
  ) async {
    final data = validDelegacionesData();
    var submitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HechoForm(
              mode: HechoFormMode.edit,
              data: data,
              onSubmit:
                  ({
                    required data,
                    required dictamenSelected,
                    required fotoLugar,
                    required fotoLugar2,
                    required fotoSituacion,
                  }) async {
                    submitCount += 1;
                    return const OfflineActionResult.synced();
                  },
              onSubmitted: (_, _) async {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Foto 1 del hecho (opcional)'), findsOneWidget);
    expect(find.text('Foto 2 del hecho (opcional)'), findsOneWidget);
    await tester.ensureVisible(find.text('TURNADO').last);
    await tester.tap(find.text('TURNADO').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PENDIENTE').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(submitCount, 1);
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(submitCount, 1);
    expect(data.situacion, 'PENDIENTE');
    expect(data.vehiculosMp, '0');
    expect(data.personasMp, '0');
  });

  testWidgets('retry keeps the UUID persisted before the network attempt', (
    tester,
  ) async {
    final data = validDelegacionesData()..situacion = 'PENDIENTE';
    final attempts = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HechoForm(
              mode: HechoFormMode.create,
              data: data,
              draftId: 'hechos:create',
              onSubmit:
                  ({
                    required data,
                    required dictamenSelected,
                    required fotoLugar,
                    required fotoLugar2,
                    required fotoSituacion,
                  }) async {
                    attempts.add(data.clientUuid);
                    final saved = await LocalDraftService.load('hechos:create');
                    expect(saved?['client_uuid'], data.clientUuid);
                    if (attempts.length == 1)
                      throw Exception('Fallo de prueba');
                    return const OfflineActionResult.queued();
                  },
              onSubmitted: (_, _) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final save = find.text('Registrar Hecho');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(attempts, hasLength(2));
    expect(attempts.first, isNotEmpty);
    expect(attempts[1], attempts.first);
    expect(await LocalDraftService.load('hechos:create'), isNull);
  });

  for (final recover in [false, true]) {
    testWidgets('create draft recovery is explicit: $recover', (tester) async {
      await LocalDraftService.save('hechos:create', <String, dynamic>{
        'client_uuid': 'old-offline-operation',
        'folio_c5i': 'C5I-123',
        'perito': 'Elemento borrador',
        'unidad': 'Unidad 99',
        'hora': '09:30',
        'fecha': '2026-04-25',
      });
      final data = HechoFormData();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HechoForm(
                mode: HechoFormMode.create,
                data: data,
                draftId: 'hechos:create',
                onSubmit:
                    ({
                      required data,
                      required dictamenSelected,
                      required fotoLugar,
                      required fotoLugar2,
                      required fotoSituacion,
                    }) async {
                      return const OfflineActionResult.synced();
                    },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(data.folioC5i, isEmpty);
      expect(find.text('¿Continuar una captura anterior?'), findsOneWidget);
      await tester.tap(
        find.text(recover ? 'Continuar captura anterior' : 'Nuevo hecho'),
      );
      await tester.pumpAndSettle();

      expect(data.clientUuid, recover ? 'old-offline-operation' : isNull);
      expect(data.folioC5i, recover ? 'C5I-123' : isEmpty);
      expect(data.perito, recover ? 'Elemento borrador' : isEmpty);
      expect(data.unidad, recover ? 'Unidad 99' : isEmpty);
      if (!recover) {
        expect(await LocalDraftService.load('hechos:create'), isNull);
      }
    });
  }

  testWidgets('delegaciones turnado does not show existing puesta selector', (
    tester,
  ) async {
    final data = validDelegacionesData()
      ..vehiculosMp = '1'
      ..personasMp = '0'
      ..vehiculosEsperados = '1'
      ..conductoresEsperados = '1';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HechoForm(
              mode: HechoFormMode.edit,
              data: data,
              onSubmit:
                  ({
                    required data,
                    required dictamenSelected,
                    required fotoLugar,
                    required fotoLugar2,
                    required fotoSituacion,
                  }) async {
                    return const OfflineActionResult.synced();
                  },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Puesta a disposicion'), findsNothing);
    expect(find.text('Vehículos MP *'), findsOneWidget);
  });
}
