import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seguridad_vial_app/app/routes.dart';
import 'package:seguridad_vial_app/screens/busqueda/hechos_busqueda_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'conserva resultados de choques si el buscador de operativos da 404',
    (tester) async {
      SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/hechos/buscar')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 84,
                  'fecha': '2026-07-25',
                  'calle': 'Avenida Madero',
                  'colonia': 'Centro',
                  'perito': 'JUAN PEREZ',
                  'vehiculos': [
                    {
                      'placas': 'ABC123A',
                      'serie': 'SERIE-CHOQUE-84',
                      'conductores': [
                        {'nombre': 'ANA LOPEZ'},
                      ],
                    },
                  ],
                },
              ],
              'meta': {
                'current_page': 1,
                'last_page': 1,
                'per_page': 20,
                'total': 1,
              },
            }),
            200,
          );
        }

        if (request.url.path.endsWith('/conduce-legalidad/buscar')) {
          return http.Response(jsonEncode({'message': 'Error HTTP 404'}), 404);
        }

        return http.Response('No encontrado', 404);
      });

      await tester.pumpWidget(
        MaterialApp(home: HechosBusquedaScreen(client: client)),
      );

      await tester.enterText(find.byType(TextField), 'ABC123A');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(find.text('Hecho #84 · 2026-07-25'), findsOneWidget);
      expect(find.textContaining('Placas: ABC123A'), findsOneWidget);
      expect(find.textContaining('Error: Exception: Error 404'), findsNothing);
    },
  );

  testWidgets('busca operativos y abre la captura encontrada', (tester) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/hechos/buscar')) {
        return http.Response(
          jsonEncode({
            'data': <dynamic>[],
            'meta': {
              'current_page': 1,
              'last_page': 1,
              'per_page': 20,
              'total': 0,
            },
          }),
          200,
        );
      }

      if (request.url.path.endsWith('/conduce-legalidad/buscar')) {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'result_type': 'operativo',
                'module': 'alcoholimetria',
                'module_label': 'Prevención de Accidentes',
                'operativo_id': 7,
                'captura_id': 31,
                'folio': 'PA-7-31',
                'folios': ['PA-7-31-1', 'PA-7-31-2'],
                'fecha': '2026-07-25',
                'hora': '21:30',
                'municipio': 'Morelia',
                'lugar': 'Avenida Madero',
                'colonia': 'Centro',
                'personas': [
                  {'nombre': 'ANA PEREZ', 'numero_licencia': 'MIC-123'},
                ],
                'vehiculos': [
                  {'placas': 'ABC-123-A', 'serie': 'SERIE123'},
                ],
              },
            ],
            'meta': {
              'current_page': 1,
              'last_page': 1,
              'per_page': 20,
              'total': 1,
            },
          }),
          200,
        );
      }

      return http.Response('No encontrado', 404);
    });

    RouteSettings? openedRoute;
    await tester.pumpWidget(
      MaterialApp(
        home: HechosBusquedaScreen(client: client),
        onGenerateRoute: (settings) {
          openedRoute = settings;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Detalle operativo')),
          );
        },
      ),
    );

    await tester.enterText(find.byType(TextField), 'PA-7-31-2');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    const resultTitle = 'Prevención de Accidentes · PA-7-31-2';
    expect(find.text(resultTitle), findsOneWidget);
    expect(find.textContaining('ANA PEREZ'), findsOneWidget);

    await tester.tap(find.text(resultTitle));
    await tester.pumpAndSettle();

    expect(openedRoute?.name, AppRoutes.alcoholimetriaShow);
    expect(openedRoute?.arguments, {'operativoId': 7, 'capturaId': 31});
  });
}
