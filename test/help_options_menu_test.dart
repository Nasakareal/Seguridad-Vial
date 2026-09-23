import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/widgets/help_options_menu.dart';

void main() {
  testWidgets('el menú de ayuda desplaza hasta la última opción', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HelpOptionsMenu(
            description: 'Opciones de prueba',
            children: List.generate(
              8,
              (index) => ListTile(title: Text('Opción ${index + 1}')),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Opción 8'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Opción 8'), findsOneWidget);
  });
}
