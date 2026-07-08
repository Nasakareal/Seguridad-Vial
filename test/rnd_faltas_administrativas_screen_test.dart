import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/screens/herramientas/rnd_faltas_administrativas_screen.dart';

void main() {
  testWidgets('RND tool renders guided form and actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RndFaltasAdministrativasScreen()),
    );

    expect(find.text('Solicitar RND'), findsOneWidget);
    expect(find.text('Elementos'), findsOneWidget);
    expect(find.text('Detención'), findsOneWidget);
    expect(find.text('Policía Estatal'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
  });

  test('RND message does not include internal warning text', () {
    final source = File(
      'lib/screens/herramientas/rnd_faltas_administrativas_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('Información incompleta')));
  });
}
