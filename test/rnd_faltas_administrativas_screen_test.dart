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

  test('RND form reuses all clothing selectors in the generated message', () {
    final source = File(
      'lib/screens/herramientas/rnd_faltas_administrativas_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Vestimenta de la persona'));
    expect(source, contains('Prenda superior *'));
    expect(source, contains('Color superior *'));
    expect(source, contains('Prenda inferior *'));
    expect(source, contains('Color inferior *'));
    expect(source, contains('Calzado *'));
    expect(source, contains('Color calzado *'));
    expect(
      source,
      contains('ConduceLegalidadPersonaDescriptor.buildDescription'),
    );
  });
}
