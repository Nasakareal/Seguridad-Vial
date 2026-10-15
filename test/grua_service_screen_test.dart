import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/grua/grua_corralon_screen.dart';
import 'package:seguridad_vial_app/screens/grua/grua_expediente_screen.dart';

void main() {
  testWidgets('muestra origen y permite capturar la actuación de la grúa', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GruaServicioScreen(
          item: {
            'id': 10,
            'placas': 'ABC123A',
            'galeria': <Map<String, dynamic>>[],
            'origen': {
              'tipo': 'SINIESTRO',
              'etiqueta': 'Siniestro',
              'id': 55,
              'folio': 'C5-100',
              'fecha': '2026-10-14',
              'lugar': 'Morelia',
              'detalle': 'Choque',
            },
            'servicio': {
              'realizo_maniobras': true,
              'maniobras_descripcion': 'Izaje del vehículo',
              'observaciones_grua': 'Sin daños adicionales',
            },
          },
        ),
      ),
    );

    expect(find.text('Siniestro · Choque'), findsOneWidget);
    expect(find.text('¿Se realizaron maniobras? *'), findsOneWidget);
    expect(find.text('Izaje del vehículo'), findsOneWidget);
    expect(find.text('Sin daños adicionales'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Guardar servicio'), findsOneWidget);
    expect(find.text('Compartir resumen del sistema'), findsOneWidget);
  });

  testWidgets('alta manual muestra expediente y carga de memoria oficial', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GruaExpedienteScreen()));

    expect(find.text('Nuevo servicio SIERSE'), findsOneWidget);
    expect(find.text('Vehículo'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Servicio auxiliar'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -2100));
    await tester.pumpAndSettle();
    expect(find.text('Memoria descriptiva oficial'), findsOneWidget);
    expect(find.text('Subir memoria descriptiva'), findsOneWidget);
    expect(find.text('Registrar servicio'), findsOneWidget);
  });
}
