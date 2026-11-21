import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/settings/widgets/user_password_field.dart';

void main() {
  testWidgets('permite mostrar y volver a ocultar la contraseña', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Secreto-123');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserPasswordField(controller: controller, label: 'Contraseña'),
        ),
      ),
    );

    EditableText field() =>
        tester.widget<EditableText>(find.byType(EditableText));

    expect(field().obscureText, isTrue);
    expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();

    expect(field().obscureText, isFalse);
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);

    await tester.tap(find.byTooltip('Ocultar contraseña'));
    await tester.pump();

    expect(field().obscureText, isTrue);
  });
}
