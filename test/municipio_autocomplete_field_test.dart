import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/widgets/municipio_autocomplete_field.dart';

void main() {
  testWidgets('selects a municipio from the picker sheet', (tester) async {
    final controller = TextEditingController(text: 'MORELIA');
    addTearDown(controller.dispose);
    String? changed;
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MunicipioAutocompleteField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Municipio'),
              onChanged: (value) => changed = value,
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'zamo');
    await tester.pump();
    await tester.tap(find.text('ZAMORA'));
    await tester.pumpAndSettle();

    expect(controller.text, 'ZAMORA');
    expect(changed, 'ZAMORA');
    expect(selected, 'ZAMORA');
  });

  testWidgets('can dismiss the picker while the host unmounts', (tester) async {
    final controller = TextEditingController(text: 'MORELIA');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MunicipioAutocompleteField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Municipio'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
