import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/core/hechos/hechos_catalogos.dart';
import 'package:seguridad_vial_app/models/hecho_form_data.dart';
import 'package:seguridad_vial_app/screens/accidentes/widgets/hecho_form.dart';
import 'package:seguridad_vial_app/services/auth_service.dart';
import 'package:seguridad_vial_app/services/offline_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
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
    var submitted = false;

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
                    required fotoSituacion,
                  }) async {
                    submitted = true;
                    return const OfflineActionResult.synced();
                  },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('TURNADO').last);
    await tester.tap(find.text('TURNADO').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PENDIENTE').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(submitted, isTrue);
    expect(data.situacion, 'PENDIENTE');
    expect(data.vehiculosMp, '0');
    expect(data.personasMp, '0');
  });

  testWidgets('delegaciones turnado shows puesta selector', (tester) async {
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

    expect(find.text('Puesta a disposicion'), findsOneWidget);
  });
}
