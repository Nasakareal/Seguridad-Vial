import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/modules/cultura_vial/academy/content/vial_question_bank.dart';
import 'package:seguridad_vial_app/modules/cultura_vial/academy/models/vial_question.dart';
import 'package:seguridad_vial_app/modules/cultura_vial/academy/screens/academia_vial_screen.dart';
import 'package:seguridad_vial_app/modules/cultura_vial/academy/widgets/academy_question_card.dart';
import 'package:seguridad_vial_app/modules/cultura_vial/screens/cultura_vial_game_hub_screen.dart';
import 'package:seguridad_vial_app/screens/publico/registro_ciudadano_screen.dart';
import 'package:seguridad_vial_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('academy contains 120 practice questions', () {
    expect(vialQuestionBank, hasLength(120));
    for (final question in vialQuestionBank) {
      expect(question.options.length, greaterThanOrEqualTo(3));
      expect(
        question.correct,
        inInclusiveRange(0, question.options.length - 1),
      );
      expect(question.explanation.trim(), isNotEmpty);
    }
  });

  test('citizen role is isolated from operational roles', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Ciudadano',
    });
    expect(await AuthService.isCitizen(), isTrue);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Perito',
    });
    expect(await AuthService.isCitizen(), isFalse);
  });

  testWidgets('registration has no forgotten-password action', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegistroCiudadanoScreen()));
    expect(find.text('Crear mi cuenta'), findsOneWidget);
    expect(find.textContaining('Olvid'), findsNothing);
  });

  for (final mode in AcademiaMode.values) {
    testWidgets('academy starts a visual question in ${mode.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: AcademiaVialScreen(initialMode: mode)),
      );
      await tester.pump();
      if (mode == AcademiaMode.aprender) {
        await tester.tap(find.text('Señales y semáforos').first);
      } else if (mode == AcademiaMode.practicar) {
        await tester.scrollUntilVisible(
          find.text('Comenzar práctica'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        final button = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Comenzar práctica'),
            matching: find.byWidgetPredicate((widget) => widget is FilledButton),
          ),
        );
        button.onPressed!();
      } else {
        await tester.scrollUntilVisible(
          find.text('Iniciar simulacro'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        final button = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Iniciar simulacro'),
            matching: find.byWidgetPredicate((widget) => widget is FilledButton),
          ),
        );
        button.onPressed!();
      }
      await tester.pump();
      expect(find.byType(AcademyQuestionCard), findsOneWidget);
      final length = switch (mode) {
        AcademiaMode.aprender => 12,
        AcademiaMode.practicar => 15,
        AcademiaMode.simulacro => 30,
      };
      expect(find.text('1/$length'), findsOneWidget);
    });
  }
  testWidgets('public home exposes academy and missions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CulturaVialGameHubScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Elige tu misión'), findsOneWidget);
    expect(find.text('Detecta el peligro'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Academia y simulador'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Academia y simulador'), findsOneWidget);
  });
}
