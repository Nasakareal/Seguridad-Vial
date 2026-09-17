import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/patrullas/ayuda/patrulla_servicio_help_sheet.dart';

void main() {
  testWidgets('la ayuda de patrullas recorre recepción, servicio y entrega', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PatrullaServicioHelpSheet()),
      ),
    );

    expect(find.text('Recibe la unidad'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Inspecciona y documenta'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Consulta tu servicio'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Entrega y cierra el turno'), findsOneWidget);
    expect(find.text('Entendido'), findsOneWidget);
  });
}
