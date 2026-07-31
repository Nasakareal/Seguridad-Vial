import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/conduce_legalidad_operativo_form_screen.dart';
import 'package:seguridad_vial_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('delegate does not see operativo date or time fields', (
    tester,
  ) async {
    _setSession(role: 'Delegado');

    await tester.pumpWidget(
      const MaterialApp(home: ConduceLegalidadOperativoFormScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.calendar_month), findsNothing);
    expect(find.byIcon(Icons.schedule), findsNothing);
    expect(find.text('Unidad responsable *'), findsNothing);
    expect(find.text('Delegación específica *'), findsNothing);
  });

  testWidgets('administrator sees operativo date and time fields', (
    tester,
  ) async {
    _setSession(role: 'Administrador', roleId: 3);

    await tester.pumpWidget(
      const MaterialApp(home: ConduceLegalidadOperativoFormScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.calendar_month), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.text('Unidad responsable *'), findsNothing);
    expect(find.text('Delegación específica *'), findsNothing);
  });

  testWidgets(
    'superadmin selects unit and delegation only appears for Delegaciones',
    (tester) async {
      _setSession(role: 'Superadmin', roleId: 1);

      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: ConduceLegalidadOperativoFormScreen()),
        );
        await tester.pumpAndSettle();
      }, () => MockClient(_metaResponse));

      expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(2));

      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vialidades Urbanas').last);
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    },
  );
}

Future<http.Response> _metaResponse(http.Request request) async {
  return http.Response(
    jsonEncode({
      'data': {
        'abilities': {'can_assign_scope': true},
        'unidades': [
          {'id': 2, 'nombre': 'Delegaciones'},
          {'id': 5, 'nombre': 'Vialidades Urbanas'},
        ],
        'delegaciones': [
          {'id': 15, 'nombre': 'Pátzcuaro'},
        ],
        'fundamentos_corralon': <Object>[],
        'fundamentos_persona': <Object>[],
      },
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void _setSession({required String role, int? roleId}) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'auth_token': 'test-token',
    'auth_role': role,
    if (roleId != null) 'auth_role_id': roleId,
    'auth_unidad_id': AuthService.unidadDelegacionesId,
    'auth_user_payload': jsonEncode(<String, Object>{
      'id': 300 + (roleId ?? 0),
      'role': <String, Object>{if (roleId != null) 'id': roleId, 'name': role},
      'unidad_id': AuthService.unidadDelegacionesId,
    }),
  });
}
