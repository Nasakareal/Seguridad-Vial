import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/administrative_access_service.dart';
import 'package:seguridad_vial_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('identifies configured administrative roles', () async {
    for (final role in <String>[
      'Superadmin',
      'Subdirector',
      'Administrador',
      'Administrativo',
    ]) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_role': role,
      });

      expect(
        await AdministrativeAccessService.hasAdministrativeRole(),
        isTrue,
        reason: role,
      );
    }
  });

  test('allows administrative role ids even without role text', () async {
    for (final roleId in <int>[1, 2, 3, 5]) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_role_id': roleId,
      });

      expect(
        await AdministrativeAccessService.hasAdministrativeRole(),
        isTrue,
        reason: 'role id $roleId',
      );
    }
  });

  test(
    'does not allow unrelated roles with configuration permissions',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_role': 'Policia',
        'auth_perms': <String>['ver usuarios', 'ver personal'],
      });

      expect(
        await AdministrativeAccessService.canSeeConfigurationMenu(),
        isFalse,
      );
    },
  );

  test('administrator with users permission can open configuration', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Administrador',
      'auth_perms': <String>['ver usuarios'],
    });

    final access = await AdministrativeAccessService.loadAccess();

    expect(access.canSeeUsers, isTrue);
    expect(access.canSeeConfigurationMenu, isTrue);
  });

  test('vialidades administrative user only sees vialidades files', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Administrativo',
      'auth_role_id': 5,
      'auth_unidad_id': AuthService.unidadVialidadesUrbanasId,
      'auth_user_payload': jsonEncode(<String, Object>{
        'role': <String, Object>{'id': 5, 'name': 'Administrativo'},
        'unidad_id': AuthService.unidadVialidadesUrbanasId,
        'unidad': <String, Object>{
          'id': AuthService.unidadVialidadesUrbanasId,
          'nombre': 'PROTECCIÓN EN VIALIDADES URBANAS',
        },
      }),
      'auth_perms': <String>[
        'ver estadisticas',
        'ver estadisticas globales',
        'ver estadisticas actividades',
        'ver operativos vialidades',
      ],
    });

    final access = await AdministrativeAccessService.loadAccess();

    expect(access.canSeeSiniestrosFiles, isFalse);
    expect(access.canSeeDelegacionesFiles, isFalse);
    expect(access.canSeeVialidadesFiles, isTrue);
    expect(access.canSeeFomentoFiles, isFalse);
    expect(access.canSeeConfigurationMenu, isTrue);
  });

  test('vialidades operative user cannot see statistics files', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Agente Vial',
      'auth_role_id': 12,
      'auth_unidad_id': AuthService.unidadVialidadesUrbanasId,
      'auth_user_payload': jsonEncode(<String, Object>{
        'role': <String, Object>{'id': 12, 'name': 'Agente Vial'},
        'unidad_id': AuthService.unidadVialidadesUrbanasId,
      }),
      'auth_perms': <String>[
        'ver estadisticas',
        'ver estadisticas globales',
        'ver estadisticas actividades',
        'ver operativos vialidades',
      ],
    });

    final access = await AdministrativeAccessService.loadAccess();

    expect(access.canSeeSiniestrosFiles, isFalse);
    expect(access.canSeeDelegacionesFiles, isFalse);
    expect(access.canSeeVialidadesFiles, isFalse);
    expect(access.canSeeFomentoFiles, isFalse);
    expect(access.canSeeConfigurationMenu, isFalse);
  });

  test('siniestros administrative user sees siniestros files only', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Administrativo',
      'auth_role_id': 5,
      'auth_unidad_id': 1,
      'auth_user_payload': jsonEncode(<String, Object>{
        'role': <String, Object>{'id': 5, 'name': 'Administrativo'},
        'unidad_id': 1,
      }),
      'auth_perms': <String>[
        'ver estadisticas globales',
        'ver estadisticas actividades',
      ],
    });

    final access = await AdministrativeAccessService.loadAccess();

    expect(access.canSeeSiniestrosFiles, isTrue);
    expect(access.canSeeDelegacionesFiles, isFalse);
    expect(access.canSeeVialidadesFiles, isFalse);
    expect(access.canSeeFomentoFiles, isFalse);
  });

  test('reads administrative role from stored payload', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_user_payload': jsonEncode(<String, Object>{
        'role': <String, Object>{'name': 'Administrativo'},
      }),
    });

    expect(await AdministrativeAccessService.hasAdministrativeRole(), isTrue);
  });
}
