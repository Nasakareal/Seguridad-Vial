import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:seguridad_vial_app/services/actividades_service.dart';
import 'package:seguridad_vial_app/services/app_version_service.dart';
import 'package:seguridad_vial_app/services/home_resolver_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('non-UPEC users do not probe the protected UPEC home', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': 'test-token',
      'auth_role': 'Policia',
      'auth_role_id': 10,
      'auth_perms': <String>['ver actividades'],
    });
    var requests = 0;

    final available = await http.runWithClient(
      HomeResolverService.isAgenteUpecHomeAvailable,
      () => MockClient((request) async {
        requests++;
        return http.Response('{}', 403);
      }),
    );

    expect(available, isFalse);
    expect(requests, 0);
  });

  test('activity filters use activity-scoped catalog routes', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': 'test-token',
    });
    final paths = <String>[];

    await http.runWithClient(
      () async {
        await ActividadesService.fetchUnidadesFiltro();
        await ActividadesService.fetchDelegacionesFiltro();
      },
      () {
        return MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response(
            '[]',
            200,
            headers: const {'content-type': 'application/json'},
          );
        });
      },
    );

    expect(paths, <String>[
      '/api/actividades/catalogos/unidades',
      '/api/actividades/catalogos/delegaciones',
    ]);
  });

  testWidgets('version check sends the authenticated token', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': 'version-token',
    });
    PackageInfo.setMockInitialValues(
      appName: 'Seguridad Vial',
      packageName: 'mx.gob.seguridad_vial',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    late BuildContext context;
    String? authorization;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await http.runWithClient(
      () => AppVersionService.enforceUpdateIfNeeded(context),
      () => MockClient((request) async {
        authorization = request.headers['Authorization'];
        return http.Response(
          jsonEncode(<String, Object>{'data': <String, Object>{}}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    expect(authorization, 'Bearer version-token');
  });
}
