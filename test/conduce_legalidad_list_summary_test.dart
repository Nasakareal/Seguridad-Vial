import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/conduce_legalidad_screen.dart';
import 'package:seguridad_vial_app/services/conduce_legalidad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('el filtro mensual se envía y conserva el resumen global', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': 'test-token',
    });
    String? requestedMonth;

    await http.runWithClient(
      () async {
        final result = await ConduceLegalidadService.fetchOperativos(
          mes: '2026-10',
          incluirCerrados: true,
        );

        expect(requestedMonth, '2026-10');
        expect(result.totalOperativos, 12);
        expect(result.totalRegistros, 47);
      },
      () {
        return MockClient((request) async {
          requestedMonth = request.url.queryParameters['mes'];
          return _json(<String, dynamic>{
            'resumen': <String, dynamic>{'operativos': 12, 'registros': 47},
            'data': <Object>[],
          });
        });
      },
    );
  });

  testWidgets('la cabecera muestra operativos y registros del filtro', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': 'test-token',
      'auth_role': 'Policia',
      'auth_role_id': 4,
      'auth_unidad_id': 2,
      'auth_delegacion_id': 15,
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 99,
        'role': <String, Object>{'name': 'Policia'},
        'unidad_id': 2,
        'delegacion_id': 15,
      }),
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: ConduceLegalidadScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('operativo'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('registros / resguardos'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Boulevard Industrial 120'), findsOneWidget);
      expect(find.textContaining('Uruapan'), findsWidgets);
      expect(find.textContaining('2 mías'), findsOneWidget);
      expect(find.textContaining('5 resguardados'), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => MockClient(_response));
  });
}

Future<http.Response> _response(http.Request request) async {
  if (request.url.path.endsWith('/meta')) {
    return _json(<String, dynamic>{
      'data': <String, dynamic>{
        'operativo_nombre': 'Operativo conduce con legalidad',
        'abilities': <String, dynamic>{
          'can_feed': true,
          'can_create_operativo': false,
          'can_view_all_capturas': false,
          'scope': 'own',
        },
        'fundamentos_conduce_legalidad': <Object>[],
        'fundamentos_corralon': <Object>[],
        'fundamentos_persona': <Object>[],
      },
    });
  }

  return _json(<String, dynamic>{
    'resumen': <String, dynamic>{'operativos': 1, 'registros': 8},
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
        'colonia': 'La Basilia',
        'estado': 'activo',
        'total_capturas': 2,
        'mis_capturas': 2,
        'can_feed': true,
        'can_view_all_capturas': false,
        'delegacion': <String, dynamic>{'id': 15, 'nombre': 'Uruapan'},
      },
    ],
  });
}

http.Response _json(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: const <String, String>{
    'content-type': 'application/json; charset=utf-8',
  },
);
