import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/ayuda/conduce_legalidad_form_help_sheet.dart';

void main() {
  testWidgets(
    'la ayuda de vehículo muestra los botones reales del formulario',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConduceLegalidadCaptureFormHelpSheet(
              topic: ConduceLegalidadCaptureFormHelpTopic.vehiculo,
              isEditing: false,
              isAlcoholimetria: false,
            ),
          ),
        ),
      );

      expect(find.text('Agregar motocicleta'), findsOneWidget);
      expect(find.text('Agregar'), findsOneWidget);
      expect(find.text('Escanear tarjeta'), findsOneWidget);
      expect(find.text('Agregar vehículo'), findsOneWidget);
      expect(find.textContaining('Número de inventario'), findsOneWidget);
      expect(find.textContaining('Corralón de destino'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('la ayuda de edición muestra Actualizar captura', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConduceLegalidadCaptureFormHelpSheet(
            topic: ConduceLegalidadCaptureFormHelpTopic.guardado,
            isEditing: true,
            isAlcoholimetria: false,
          ),
        ),
      ),
    );

    expect(find.text('Actualizar la captura'), findsOneWidget);
    expect(find.text('Galería'), findsOneWidget);
    expect(find.text('Cámara'), findsOneWidget);
    expect(find.text('Actualizar captura'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la ayuda del operativo usa el botón de edición correcto', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConduceLegalidadOperativoFormHelpSheet(
            topic: ConduceLegalidadOperativoFormHelpTopic.guardado,
            operativoNombre: 'CONDUCE CON LEGALIDAD',
            isEditing: true,
            canSetSchedule: false,
            canAssignOrganization: false,
          ),
        ),
      ),
    );

    expect(find.text('Guardar los cambios'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);
    expect(find.text('Activar operativo'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
