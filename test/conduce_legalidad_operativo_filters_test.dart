import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/conduce_legalidad_show_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('filters one operativo by arbitrary data and creator', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': 'test-token',
      'auth_role': 'Administrador',
      'auth_role_id': 3,
      'auth_unidad_id': 5,
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 99,
        'role': <String, Object>{'name': 'Administrador'},
        'unidad_id': 5,
      }),
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: ConduceLegalidadShowScreen(operativoId: 17)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana Operadora'), findsOneWidget);
      expect(find.text('2 de 2 capturas'), findsOneWidget);

      await tester.ensureVisible(find.text('Buscar dato'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buscar dato'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'INV-ROJO-44');
      await tester.tap(find.text('Buscar').last);
      await tester.pumpAndSettle();

      expect(find.text('Ana Operadora'), findsOneWidget);
      expect(find.text('Bruno Grullero'), findsNothing);
      expect(find.text('1 de 2 capturas'), findsOneWidget);

      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Usuario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bruno Grullero').last);
      await tester.pumpAndSettle();

      expect(find.text('Ana Operadora'), findsNothing);
      expect(find.text('1 de 2 capturas'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Folio CL-17-502'), findsOneWidget);
    }, () => MockClient(_response));
  });
}

Future<http.Response> _response(http.Request request) async {
  if (request.url.path.endsWith('/meta')) {
    return _json(<String, dynamic>{
      'data': <String, dynamic>{
        'abilities': <String, dynamic>{
          'can_feed': true,
          'can_manage_operativos': true,
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
    'data': <String, dynamic>{
      'id': 17,
      'nombre': 'Operativo conduce con legalidad',
      'tipo_operativo': 'conduce_legalidad',
      'estado': 'activo',
      'can_feed': true,
      'total_capturas': 2,
      'mis_capturas': 0,
      'capturas': <Object>[
        <String, dynamic>{
          'id': 80,
          'folio_numero': 501,
          'folio': 'CL-17-501',
          'operativo_id': 17,
          'created_by': 10,
          'fecha': '2026-10-14',
          'hora': '10:05:00',
          'creador': <String, dynamic>{'id': 10, 'name': 'Ana Operadora'},
          'can_edit': true,
          'can_delete': true,
          'vehiculos': <Object>[
            <String, dynamic>{
              'placas': 'ABC-123',
              'numero_inventario': 'INV-ROJO-44',
            },
          ],
          'personas': <Object>[],
          'fotos': <Object>[],
        },
        <String, dynamic>{
          'id': 81,
          'folio_numero': 502,
          'folio': 'CL-17-502',
          'operativo_id': 17,
          'created_by': 11,
          'fecha': '2026-10-14',
          'hora': '10:00:00',
          'creador': <String, dynamic>{'id': 11, 'name': 'Bruno Grullero'},
          'can_edit': true,
          'can_delete': true,
          'vehiculos': <Object>[
            <String, dynamic>{
              'placas': 'XYZ-999',
              'numero_inventario': 'INV-AZUL-20',
            },
          ],
          'personas': <Object>[],
          'fotos': <Object>[],
        },
      ],
    },
  });
}

http.Response _json(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: const <String, String>{
    'content-type': 'application/json; charset=utf-8',
  },
);
