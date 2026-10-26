import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seguridad_vial_app/models/conduce_legalidad.dart';
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
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Unidad de Delegaciones · Delegación de Uruapan',
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Unidad de Protección en Vialidades Urbanas',
            skipOffstage: false,
          ),
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

  testWidgets('agent autocomplete fills all fields and keeps manual editing', (
    tester,
  ) async {
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
    });

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ConduceLegalidadCapturaScreen(operativoId: 17),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final search = find.byKey(const Key('agente-autocomplete'));
        await tester.ensureVisible(search);
        await tester.enterText(search, '09130');
        await tester.pumpAndSettle();

        final suggestion = find.byKey(const Key('agente-suggestion-291'));
        expect(suggestion, findsOneWidget);
        await tester.tap(suggestion);
        await tester.pumpAndSettle();

        String fieldText(String key) =>
            tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

        expect(fieldText('agente-nombres'), 'Julio Octavio');
        expect(fieldText('agente-apellido-paterno'), 'Pérez');
        expect(fieldText('agente-apellido-materno'), 'Hernández');
        expect(fieldText('agente-numero-placa'), '09130');

        await tester.enterText(
          find.byKey(const Key('agente-nombres')),
          'Agente Nuevo',
        );
        expect(fieldText('agente-nombres'), 'Agente Nuevo');
      },
      () => MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/capturas/reservar-folio')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return _json(<String, dynamic>{
            'data': <String, dynamic>{
              'client_uuid': body['client_uuid'],
              'folio_numero': 701,
              'folio': 'CL-17-701',
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
              'agentes': <Object>[
                <String, dynamic>{
                  'id': 291,
                  'nombres': 'Julio Octavio',
                  'apellido_paterno': 'Pérez',
                  'apellido_materno': 'Hernández',
                  'numero_placa': '09130',
                  'nombre_completo': 'Julio Octavio Pérez Hernández',
                },
              ],
            },
          });
        }
        return _json(<String, dynamic>{
          'data': <String, dynamic>{
            'id': 17,
            'nombre': 'Operativo conduce con legalidad',
            'tipo_operativo': 'conduce_legalidad',
            'unidad_id': 5,
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

  testWidgets('hides a selected legal ground only within the current feeding', (
    tester,
  ) async {
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
    });

    await http.runWithClient(
      () async {
        Future<void> openFeeding() async {
          await tester.pumpWidget(
            const MaterialApp(
              home: ConduceLegalidadCapturaScreen(operativoId: 17),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
        }

        List<String?> optionCodes(Finder field) {
          final dropdown = tester
              .widget<DropdownButton<ConduceLegalidadFundamento?>>(
                find.descendant(
                  of: field,
                  matching: find.byType(
                    DropdownButton<ConduceLegalidadFundamento?>,
                  ),
                ),
              );
          return dropdown.items!
              .map((item) => item.value?.codigo)
              .whereType<String>()
              .toList();
        }

        await openFeeding();
        final primary = find.byKey(const Key('fundamento-principal'));
        await tester.scrollUntilVisible(
          primary,
          500,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          optionCodes(primary),
          unorderedEquals(<String>['FUNDAMENTO_A', 'FUNDAMENTO_B']),
        );
        await tester.tap(primary);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Fundamento A').last);
        await tester.pumpAndSettle();

        final add = find.text('Añadir otro fundamento');
        await tester.scrollUntilVisible(
          add,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(add);
        await tester.pumpAndSettle();

        final additional = find.byKey(const Key('fundamento-adicional-0'));
        expect(optionCodes(additional), <String>['FUNDAMENTO_B']);
      },
      () => MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/capturas/reservar-folio')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return _json(<String, dynamic>{
            'data': <String, dynamic>{
              'client_uuid': body['client_uuid'],
              'folio_numero': 702,
              'folio': 'CL-17-702',
            },
          });
        }
        if (request.url.path.endsWith('/meta')) {
          return _json(<String, dynamic>{
            'data': <String, dynamic>{
              'abilities': <String, dynamic>{'can_feed': true},
              'fundamentos_conduce_legalidad': <Object>[
                <String, dynamic>{
                  'id': 101,
                  'codigo': 'FUNDAMENTO_A',
                  'nombre': 'Fundamento A',
                  'ambito_vehiculo': 'motocicleta',
                  'retencion_vehiculo': true,
                },
                <String, dynamic>{
                  'id': 102,
                  'codigo': 'FUNDAMENTO_B',
                  'nombre': 'Fundamento B',
                  'ambito_vehiculo': 'motocicleta',
                  'retencion_vehiculo': true,
                },
              ],
              'fundamentos_corralon': <Object>[
                <String, dynamic>{
                  'id': 101,
                  'codigo': 'FUNDAMENTO_A',
                  'nombre': 'Fundamento A',
                  'ambito_vehiculo': 'motocicleta',
                  'retencion_vehiculo': true,
                },
                <String, dynamic>{
                  'id': 102,
                  'codigo': 'FUNDAMENTO_B',
                  'nombre': 'Fundamento B',
                  'ambito_vehiculo': 'motocicleta',
                  'retencion_vehiculo': true,
                },
              ],
              'fundamentos_persona': <Object>[],
            },
          });
        }
        return _json(<String, dynamic>{
          'data': <String, dynamic>{
            'id': 17,
            'nombre': 'Operativo conduce con legalidad',
            'tipo_operativo': 'conduce_legalidad',
            'unidad_id': 5,
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
