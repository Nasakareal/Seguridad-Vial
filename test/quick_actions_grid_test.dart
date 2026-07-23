import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/home/widgets/quick_actions_grid.dart';

void main() {
  testWidgets('accesos rápidos caben en una pantalla angosta', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: QuickActionsGrid(
              canAccidentes: true,
              canMapa: true,
              onAccidentes: () {},
              onMapa: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mapa de Patrullas'), findsOneWidget);
    expect(find.text('Siniestros'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('los accesos mantienen sus acciones táctiles', (tester) async {
    var mapaTaps = 0;
    var siniestrosTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickActionsGrid(
            canAccidentes: true,
            canMapa: true,
            onAccidentes: () => siniestrosTaps++,
            onMapa: () => mapaTaps++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mapa de Patrullas'));
    await tester.tap(find.text('Siniestros'));

    expect(mapaTaps, 1);
    expect(siniestrosTaps, 1);
  });
}
