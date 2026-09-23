import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/accidentes/ayuda/hecho_turnado_delegaciones_help_sheet.dart';

void main() {
  testWidgets('explica el flujo completo de un hecho turnado en delegaciones', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HechoTurnadoDelegacionesHelpSheet()),
      ),
    );

    const titles = [
      'Encuentra el hecho',
      'Abre la edición',
      'Cámbialo a TURNADO',
      'Indica qué entregarás al MP',
      'Guarda y crea la puesta',
      'Adjunta el expediente',
      'Vincula y registra',
    ];

    for (var i = 0; i < titles.length; i++) {
      expect(find.text(titles[i]), findsOneWidget);
      if (i < titles.length - 1) {
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
      }
    }

    expect(find.text('Entendido'), findsOneWidget);
    expect(find.text('Registrar'), findsOneWidget);
  });

  testWidgets('permite abrir directamente el paso de archivos', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HechoTurnadoDelegacionesHelpSheet(initialPage: 5)),
      ),
    );

    expect(find.text('Adjunta el expediente'), findsOneWidget);
    expect(find.text('Archivo PDF'), findsOneWidget);
    expect(find.text('Elegir'), findsOneWidget);
    expect(find.text('Anterior'), findsOneWidget);
  });
}
