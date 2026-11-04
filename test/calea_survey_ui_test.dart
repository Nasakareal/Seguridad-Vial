import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/calea/calea_survey_form_screen.dart';
import 'package:seguridad_vial_app/screens/calea/calea_survey_public_screen.dart';

void main() {
  test('user search matches names with or without accents', () {
    final indexed = foldCaleaSurveySearch('José Núñez');
    expect(indexed, contains(foldCaleaSurveySearch('jose')));
    expect(indexed, contains(foldCaleaSurveySearch('nunez')));
  });

  testWidgets('public CALEA survey exposes code access without login', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CaleaSurveyPublicScreen()));

    expect(find.text('Encuesta CALEA sin cuenta'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Código de encuesta'),
      findsOneWidget,
    );
    expect(find.text('Buscar'), findsOneWidget);
  });
}
