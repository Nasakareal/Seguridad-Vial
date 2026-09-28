import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/conduce_legalidad_show_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('superadmin can reactivate a closed operativo', (tester) async {
    _setSession('Superadmin');
    Map<String, dynamic>? updatePayload;

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: ConduceLegalidadShowScreen(operativoId: 17)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        expect(find.text('Activar operativo nuevamente'), findsOneWidget);

        await tester.tap(find.text('Activar operativo nuevamente'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Activar'));
        await tester.pumpAndSettle();
      },
      () {
        return MockClient((request) async {
          if (request.url.path.endsWith('/meta')) {
            return _jsonResponse(_metaBody(canManage: true));
          }
          if (request.method == 'PUT') {
            updatePayload = jsonDecode(request.body) as Map<String, dynamic>;
            return _jsonResponse(_operativoBody(estado: 'activo'));
          }
          return _jsonResponse(_operativoBody(estado: 'cerrado'));
        });
      },
    );

    expect(updatePayload, <String, dynamic>{
      'estado': 'activo',
      'hora_cierre': null,
    });
  });

  testWidgets('non-superadmin cannot reactivate a closed operativo', (
    tester,
  ) async {
    _setSession('Administrador');

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: ConduceLegalidadShowScreen(operativoId: 17)),
        );
        await tester.pumpAndSettle();
      },
      () {
        return MockClient((request) async {
          if (request.url.path.endsWith('/meta')) {
            return _jsonResponse(_metaBody(canManage: true));
          }
          return _jsonResponse(_operativoBody(estado: 'cerrado'));
        });
      },
    );

    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text('Activar operativo nuevamente'), findsNothing);
  });
}

void _setSession(String role) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'auth_token': 'test-token',
    'auth_role': role,
    'auth_role_id': role == 'Superadmin' ? 1 : 3,
    'auth_unidad_id': 5,
    'auth_user_payload': jsonEncode(<String, Object>{
      'id': 99,
      'role': <String, Object>{'name': role},
      'unidad_id': 5,
    }),
  });
}

Map<String, dynamic> _metaBody({required bool canManage}) {
  return <String, dynamic>{
    'data': <String, dynamic>{
      'abilities': <String, dynamic>{
        'can_feed': true,
        'can_manage_operativos': canManage,
        'can_view_all_capturas': canManage,
        'scope': canManage ? 'all' : 'own',
      },
      'fundamentos_conduce_legalidad': <Object>[],
      'fundamentos_corralon': <Object>[],
      'fundamentos_persona': <Object>[],
      'unidades': <Object>[],
      'delegaciones': <Object>[],
    },
  };
}

Map<String, dynamic> _operativoBody({required String estado}) {
  return <String, dynamic>{
    'data': <String, dynamic>{
      'id': 17,
      'nombre': 'Operativo conduce con legalidad',
      'tipo_operativo': 'conduce_legalidad',
      'fecha': '2026-09-27',
      'lugar': 'Avenida de prueba',
      'colonia': 'Centro',
      'estado': estado,
      'can_feed': estado == 'activo',
      'total_capturas': 0,
      'mis_capturas': 0,
      'capturas': <Object>[],
    },
  };
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
}
