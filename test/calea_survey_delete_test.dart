import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seguridad_vial_app/screens/calea/calea_surveys_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('solo Superadmin ve y confirma eliminar encuesta CALEA', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': 'test-token',
      'auth_role': 'Superadmin',
      'auth_role_id': 1,
      'auth_user_id': 1,
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 1,
        'role': <String, Object>{'id': 1, 'name': 'Superadmin'},
      }),
    });
    var deleted = false;

    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: CaleaSurveysScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Administrar'));
        await tester.pumpAndSettle();

        final deleteButton = find.byKey(const Key('eliminar-encuesta-calea-9'));
        expect(deleteButton, findsOneWidget);
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        expect(find.text('Eliminar encuesta CALEA'), findsOneWidget);
        expect(find.textContaining('todas las respuestas'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('confirmar-eliminar-encuesta-calea')),
        );
        await tester.pumpAndSettle();

        expect(deleted, isTrue);
        expect(find.text('Encuesta CALEA eliminada.'), findsOneWidget);
        expect(deleteButton, findsNothing);
      },
      () => MockClient((request) async {
        if (request.method == 'DELETE' &&
            request.url.path.endsWith('/calea-encuestas/9')) {
          deleted = true;
          return _json(<String, dynamic>{
            'message': 'Encuesta CALEA eliminada definitivamente.',
          });
        }
        if (request.url.path.endsWith('/calea-encuestas/activas')) {
          return _json(<String, dynamic>{'data': <Object>[]});
        }
        if (request.url.path.endsWith('/calea-encuestas/administrar')) {
          return _json(<String, dynamic>{
            'data': <Object>[
              <String, dynamic>{
                'id': 9,
                'titulo': 'Encuesta para eliminar',
                'descripcion': 'Prueba',
                'duracion_minutos': 10,
                'preguntas_count': 2,
                'intentos_count': 3,
                'permite_externos': false,
              },
            ],
          });
        }
        return _json(<String, dynamic>{'data': <Object>[]});
      }),
    );
  });

  testWidgets('Administrador no ve eliminar encuesta CALEA', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': 'test-token',
      'auth_role': 'Administrador',
      'auth_role_id': 3,
      'auth_user_id': 3,
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 3,
        'role': <String, Object>{'id': 3, 'name': 'Administrador'},
      }),
    });

    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MaterialApp(home: CaleaSurveysScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Administrar'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('eliminar-encuesta-calea-9')),
          findsNothing,
        );
        expect(find.text('Editar'), findsOneWidget);
        expect(find.text('Ver respuestas'), findsOneWidget);
      },
      () => MockClient((request) async {
        if (request.url.path.endsWith('/calea-encuestas/activas')) {
          return _json(<String, dynamic>{'data': <Object>[]});
        }
        if (request.url.path.endsWith('/calea-encuestas/administrar')) {
          return _json(<String, dynamic>{
            'data': <Object>[
              <String, dynamic>{
                'id': 9,
                'titulo': 'Encuesta administrada',
                'duracion_minutos': 10,
                'preguntas_count': 2,
                'intentos_count': 0,
                'permite_externos': false,
              },
            ],
          });
        }
        return _json(<String, dynamic>{'data': <Object>[]});
      }),
    );
  });
}

http.Response _json(Map<String, dynamic> body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
