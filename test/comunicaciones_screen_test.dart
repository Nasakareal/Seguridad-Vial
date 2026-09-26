import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seguridad_vial_app/screens/comunicaciones/comunicaciones_screen.dart';
import 'package:seguridad_vial_app/services/comunicacion_service.dart';

void main() {
  testWidgets('agrupa los mensajes directos en un solo chat por usuario', (
    tester,
  ) async {
    final client = MockClient((request) async {
      expect(request.url.path, '/comunicaciones');

      return http.Response(
        jsonEncode({
          'recibidas': {
            'data': [
              {
                'id': 30,
                'leido_at': null,
                'comunicacion': {
                  'id': 30,
                  'tipo': 'mensaje',
                  'alcance': 'usuario',
                  'contenido': '¿Cómo estás?',
                  'remitente_user_id': 7,
                  'destinatario_user_id': 1,
                  'es_mio': false,
                  'enviado_at': '2026-09-25T10:00:00-06:00',
                  'remitente': {'id': 7, 'nombre': 'Ana Pérez'},
                },
              },
              {
                'id': 20,
                'leido_at': '2026-09-25T09:01:00-06:00',
                'comunicacion': {
                  'id': 20,
                  'tipo': 'mensaje',
                  'alcance': 'usuario',
                  'contenido': 'Hola',
                  'remitente_user_id': 7,
                  'destinatario_user_id': 1,
                  'es_mio': false,
                  'enviado_at': '2026-09-25T09:00:00-06:00',
                  'remitente': {'id': 7, 'nombre': 'Ana Pérez'},
                },
              },
              {
                'id': 10,
                'leido_at': null,
                'comunicacion': {
                  'id': 10,
                  'tipo': 'aviso',
                  'alcance': 'todos',
                  'asunto': 'Aviso operativo',
                  'contenido': 'Reunión a las 12',
                  'remitente_user_id': 9,
                  'es_mio': false,
                  'enviado_at': '2026-09-25T08:00:00-06:00',
                  'remitente': {'id': 9, 'nombre': 'Coordinación'},
                },
              },
            ],
            'total': 3,
          },
          'enviadas': {
            'data': [
              {
                'id': 40,
                'tipo': 'mensaje',
                'alcance': 'usuario',
                'contenido': 'Todo bien',
                'remitente_user_id': 1,
                'destinatario_user_id': 7,
                'es_mio': true,
                'enviado_at': '2026-09-25T11:00:00-06:00',
                'destinatario': {'id': 7, 'nombre': 'Ana Pérez'},
              },
            ],
            'total': 1,
          },
          'no_leidas': 2,
          'capacidades': {'mensaje': true, 'aviso': true},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = ComunicacionService(
      baseUrl: 'https://example.test',
      token: 'token',
      client: client,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ComunicacionesScreen(
          service: service,
          eventos: const Stream.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Tú: Todo bien'), findsOneWidget);

    await tester.tap(find.text('Recibidas'));
    await tester.pumpAndSettle();

    expect(find.text('Aviso operativo'), findsOneWidget);
    expect(find.text('¿Cómo estás?'), findsNothing);

    service.dispose();
  });
}
