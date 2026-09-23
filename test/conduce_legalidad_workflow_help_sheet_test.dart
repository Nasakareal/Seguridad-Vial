import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/ayuda/conduce_legalidad_workflow_help_sheet.dart';

void main() {
  testWidgets('el listado sólo explica cómo crear una captura nueva', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConduceLegalidadWorkflowHelpSheet(
            mode: ConduceLegalidadHelpMode.nuevaCaptura,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Crear una nueva captura'), findsOneWidget);
    expect(find.text('Agregar captura'), findsOneWidget);
    expect(find.text('Siguiente'), findsNothing);
  });

  testWidgets('la guía abre directamente vehículo y escaneo de tarjeta', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ConduceLegalidadWorkflowHelpSheet(initialPage: 1)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Vehículo y tarjeta'), findsOneWidget);
    expect(find.text('Escanear tarjeta'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsWidgets);
  });

  testWidgets('el formulario explica evidencias y guardado', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ConduceLegalidadWorkflowHelpSheet(initialPage: 3)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Evidencias y guardado'), findsOneWidget);
    expect(find.text('Guardar captura'), findsOneWidget);
    expect(find.byIcon(Icons.save_outlined), findsWidgets);
  });

  testWidgets('la boleta sólo muestra la ayuda para imprimir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConduceLegalidadWorkflowHelpSheet(
            mode: ConduceLegalidadHelpMode.impresion,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Imprimir la boleta'), findsOneWidget);
    expect(find.text('Siguiente'), findsNothing);
  });
}
