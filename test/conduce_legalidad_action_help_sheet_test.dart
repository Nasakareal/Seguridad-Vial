import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/ayuda/conduce_legalidad_action_help_sheet.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/ayuda/conduce_legalidad_alimentar_help_sheet.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/ayuda/conduce_legalidad_ticket_alimentacion_help_sheet.dart';

void main() {
  testWidgets('muestra una acción con pasos y advertencia', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConduceLegalidadActionHelpSheet(
            title: 'Eliminar una alimentación',
            description: 'Descripción de prueba.',
            icon: Icons.delete_outline,
            color: Colors.red,
            steps: ['Abre las opciones.', 'Confirma la eliminación.'],
            note: 'Esta acción no se puede deshacer.',
          ),
        ),
      ),
    );

    expect(find.text('Eliminar una alimentación'), findsOneWidget);
    expect(find.text('Abre las opciones.'), findsOneWidget);
    expect(find.text('Confirma la eliminación.'), findsOneWidget);
    expect(find.text('Esta acción no se puede deshacer.'), findsOneWidget);
    expect(find.text('Entendido'), findsOneWidget);
  });

  testWidgets('la ayuda para agregar muestra el botón inferior real', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ConduceLegalidadAlimentarHelpSheet()),
      ),
    );

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Pulsa Agregar captura'), findsOneWidget);
    expect(find.text('Agregar captura'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la ayuda del ticket enseña boleta e imprimir', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ConduceLegalidadTicketAlimentacionHelpSheet()),
      ),
    );
    await tester.pump();

    expect(find.text('Boleta de infracción'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsWidgets);
    expect(find.byIcon(Icons.print_outlined), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
