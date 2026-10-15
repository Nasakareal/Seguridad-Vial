import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/conduce_legalidad_captura_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the operative delegation as the agent assignment', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': 'test-token',
      'auth_role': 'Superadmin',
      'auth_role_id': 1,
      'auth_user_id': 1,
      'auth_session_owner_key': 'user:1',
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 1,
        'role': <String, Object>{'name': 'Superadmin'},
      }),
    });

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ConduceLegalidadCapturaScreen(operativoId: 44),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Unidad de Delegaciones · Delegación de Uruapan'),
          findsOneWidget,
        );
        expect(
          find.text('Unidad de Protección en Vialidades Urbanas'),
          findsNothing,
        );
      },
      () => MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/capturas/reservar-folio')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return _json(<String, dynamic>{
            'data': <String, dynamic>{
              'client_uuid': body['client_uuid'],
              'folio_numero': 700,
              'folio': 'CL-44-700',
            },
          });
        }
        if (request.url.path.endsWith('/meta')) {
          return _json(<String, dynamic>{
            'data': <String, dynamic>{
              'abilities': <String, dynamic>{'can_feed': true},
              'fundamentos_conduce_legalidad': <Object>[],
              'fundamentos_corralon': <Object>[],
              'fundamentos_persona': <Object>[],
            },
          });
        }
        return _json(<String, dynamic>{
          'data': <String, dynamic>{
            'id': 44,
            'nombre': 'Operativo conduce con legalidad',
            'tipo_operativo': 'conduce_legalidad',
            'unidad_id': 2,
            'delegacion_id': 30,
            'delegacion': <String, dynamic>{'id': 30, 'nombre': 'Uruapan'},
            'estado': 'activo',
            'can_feed': true,
            'total_capturas': 0,
            'mis_capturas': 0,
            'capturas': <Object>[],
          },
        });
      }),
    );
  });

  testWidgets('warns about an old draft and lets the user start clean', (
    tester,
  ) async {
    const oldUuid = '11111111-1111-4111-8111-111111111111';
    const draftKey =
        'local_form_draft_v1:user:99:conduce_legalidad:captura:17:create';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': 'test-token',
      'auth_role': 'Administrador',
      'auth_role_id': 3,
      'auth_user_id': 99,
      'auth_unidad_id': 5,
      'auth_session_owner_key': 'user:99',
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 99,
        'role': <String, Object>{'name': 'Administrador'},
        'unidad_id': 5,
      }),
      draftKey: jsonEncode(<String, dynamic>{
        'saved_at': '2026-10-13T10:00:00Z',
        'values': <String, dynamic>{
          'client_uuid': oldUuid,
          'fecha': '2026-10-13',
          'hora': '10:00',
          'agente_nombres': 'CAPTURA VIEJA',
        },
      }),
    });
    final reservedUuids = <String>[];

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ConduceLegalidadCapturaScreen(operativoId: 17),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('¿Continuar una captura anterior?'), findsOneWidget);
        await tester.tap(find.text('Continuar captura anterior'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('CAPTURA VIEJA'), findsOneWidget);
        expect(find.text('CL-17-501'), findsOneWidget);

        await tester.tap(find.byTooltip('Crear nueva captura'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Crear nueva'));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('CAPTURA VIEJA'), findsNothing);
        expect(reservedUuids, hasLength(2));
        expect(reservedUuids.first, oldUuid);
        expect(reservedUuids.last, isNot(oldUuid));
      },
      () {
        return MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/capturas/reservar-folio')) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final uuid = body['client_uuid'].toString();
            reservedUuids.add(uuid);
            return _json(<String, dynamic>{
              'ok': true,
              'data': <String, dynamic>{
                'client_uuid': uuid,
                'folio_numero': 500 + reservedUuids.length,
                'folio': 'CL-17-${500 + reservedUuids.length}',
              },
            });
          }
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
              'total_capturas': 0,
              'mis_capturas': 0,
              'capturas': <Object>[],
            },
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
