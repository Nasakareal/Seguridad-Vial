import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/conduce_legalidad_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('standby exige tres confirmaciones y envía la contraseña', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': 'test-token',
      'auth_role': 'Policia',
      'auth_role_id': 4,
      'auth_unidad_id': 1,
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 1,
        'role': <String, Object>{'name': 'Policia'},
        'unidad_id': 1,
      }),
    });

    Map<String, dynamic>? deletePayload;

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: ConduceLegalidadScreen()),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
        final optionsButton = find.byType(PopupMenuButton<String>);
        await tester.ensureVisible(optionsButton);
        await tester.pumpAndSettle();
        await tester.tap(optionsButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Poner en standby'));
        await tester.pumpAndSettle();

        expect(find.text('Confirmación 1 de 3'), findsOneWidget);
        await tester.tap(find.text('Sí, continuar'));
        await tester.pumpAndSettle();

        expect(find.text('Confirmación 2 de 3'), findsOneWidget);
        await tester.tap(find.text('Entiendo, continuar'));
        await tester.pumpAndSettle();

        expect(find.text('Confirmación 3 de 3'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'secreto-123');
        await tester.tap(find.text('Poner en standby'));
        await tester.pumpAndSettle();

        expect(deletePayload, <String, dynamic>{
          'password': 'secreto-123',
          'confirmations': 3,
          'confirmation_text': 'STANDBY',
        });
        expect(
          find.text(
            'Operativo puesto en standby. Toda la información se conservó.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
      () {
        return MockClient((request) async {
          if (request.method == 'DELETE') {
            deletePayload = jsonDecode(request.body) as Map<String, dynamic>;
            return _json(<String, dynamic>{
              'ok': true,
              'message': 'Operativo puesto en standby.',
            });
          }

          if (request.url.path.endsWith('/meta')) {
            return _json(<String, dynamic>{
              'data': <String, dynamic>{
                'operativo_nombre': 'Operativo conduce con legalidad',
                'abilities': <String, dynamic>{
                  'can_feed': true,
                  'can_create_operativo': false,
                  'can_view_all_capturas': true,
                  'scope': 'all',
                },
                'fundamentos_conduce_legalidad': <Object>[],
                'fundamentos_corralon': <Object>[],
                'fundamentos_persona': <Object>[],
                'unidades': <Object>[],
                'delegaciones': <Object>[],
              },
            });
          }

          return _json(<String, dynamic>{
            'data': <Object>[
              <String, dynamic>{
                'id': 31,
                'nombre': 'Operativo conduce con legalidad',
                'tipo_operativo': 'conduce_legalidad',
                'fecha': '2026-10-30',
                'hora_inicio': '09:00:00',
                'municipio': 'Uruapan',
                'lugar': 'Boulevard Industrial',
                'numero': '120',
                'estado': 'activo',
                'can_feed': true,
                'can_edit': false,
                'can_delete': true,
              },
            ],
          });
        });
      },
    );
  });
}

http.Response _json(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: const <String, String>{
    'content-type': 'application/json; charset=utf-8',
  },
);
