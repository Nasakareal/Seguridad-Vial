import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/widgets/drawer_ui.dart';

void main() {
  testWidgets('drawer section keeps options collapsed until tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DrawerExpandableSection(
            icon: Icons.build_outlined,
            title: 'Herramientas',
            children: [
              DrawerActionTile(
                icon: Icons.forum_outlined,
                title: 'Comunicaciones',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Herramientas'), findsOneWidget);
    expect(find.text('Comunicaciones'), findsNothing);

    await tester.tap(find.text('Herramientas'));
    await tester.pumpAndSettle();

    expect(find.text('Comunicaciones'), findsOneWidget);
  });
}
