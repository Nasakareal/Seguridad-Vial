import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/herramientas/reconstructor_transito_2d_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('muestra el editor y sus controles principales en móvil', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: ReconstructorTransito2dScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reconstructor de tránsito 2D'), findsOneWidget);
    expect(find.text('Reproducir'), findsOneWidget);
    expect(find.byIcon(Icons.add_box_outlined), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
