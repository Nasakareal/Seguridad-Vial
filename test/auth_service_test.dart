import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('perito can create hechos even from an excluded unit', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Perito',
      'auth_role_id': 4,
      'auth_unidad_id': AuthService.unidadProteccionCarreterasId,
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 15,
        'role': <String, Object>{'id': 4, 'name': 'Perito'},
        'unidad_id': AuthService.unidadProteccionCarreterasId,
      }),
      'auth_perms': <String>['ver hechos', 'crear hechos'],
    });

    expect(await AuthService.canCreateHechos(), isTrue);
    expect(await AuthService.getPermissions(), contains('crear hechos'));
  });

  test(
    'siniestros perito role id is not confused with excluded unit id',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_role': 'Perito',
        'auth_role_id': 4,
        'auth_unidad_id': 1,
        'auth_user_payload': jsonEncode(<String, Object>{
          'id': 17,
          'roles': <Map<String, Object>>[
            <String, Object>{'id': 4, 'name': 'Perito'},
          ],
          'unidad_id': 1,
        }),
        'auth_perms': <String>['ver hechos', 'crear hechos'],
      });

      expect(await AuthService.canCreateHechos(), isTrue);
      expect(await AuthService.getPermissions(), contains('crear hechos'));
    },
  );

  test('non-perito excluded unit still cannot create hechos', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Agente UPEC',
      'auth_role_id': 11,
      'auth_unidad_id': AuthService.unidadProteccionCarreterasId,
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 16,
        'role': <String, Object>{'id': 11, 'name': 'Agente UPEC'},
        'unidad_id': AuthService.unidadProteccionCarreterasId,
      }),
      'auth_perms': <String>['ver hechos', 'crear hechos'],
    });

    expect(await AuthService.canCreateHechos(), isFalse);
    expect(await AuthService.getPermissions(), isNot(contains('crear hechos')));
  });
}
