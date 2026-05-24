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

  test('jefe de grupo gets implicit hechos listing access', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Jefe Grupo',
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 22,
        'role': <String, Object>{'id': 9, 'name': 'Jefe Grupo'},
      }),
      'auth_perms': <String>[],
    });

    expect(await AuthService.isJefeGrupo(), isTrue);
    expect(await AuthService.isSiniestrosUser(), isTrue);
    expect(await AuthService.getPermissions(), contains('ver hechos'));
  });

  test('delegaciones policia cannot share location tracking', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Policia',
      'auth_role_id': 10,
      'auth_unidad_id': AuthService.unidadDelegacionesId,
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 31,
        'role': <String, Object>{'id': 10, 'name': 'Policia'},
        'unidad_id': AuthService.unidadDelegacionesId,
      }),
    });

    expect(await AuthService.canShareLocationTracking(), isFalse);
    expect(
      await AuthService.getLocationTrackingIntervalProfile(),
      AuthService.locationTrackingIntervalDefault,
    );
  });

  test('delegaciones delegado shares location tracking hourly', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Delegado',
      'auth_unidad_id': AuthService.unidadDelegacionesId,
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 32,
        'role': <String, Object>{'name': 'Delegado'},
        'unidad_id': AuthService.unidadDelegacionesId,
      }),
    });

    expect(await AuthService.canShareLocationTracking(), isTrue);
    expect(
      await AuthService.getLocationTrackingIntervalProfile(),
      AuthService.locationTrackingIntervalHourly,
    );
  });

  test('desktop builds do not force the location consent gate', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Delegado',
      'auth_unidad_id': AuthService.unidadDelegacionesId,
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 34,
        'role': <String, Object>{'name': 'Delegado'},
        'unidad_id': AuthService.unidadDelegacionesId,
      }),
    });

    expect(await AuthService.canShareLocationTracking(), isTrue);
    expect(await AuthService.shouldAskLocation(), isFalse);
  });

  test(
    'delegaciones subdelegado is not delegado for location tracking',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_role': 'Subdelegado',
        'auth_unidad_id': AuthService.unidadDelegacionesId,
        'auth_user_payload': jsonEncode(<String, Object>{
          'id': 33,
          'role': <String, Object>{'name': 'Subdelegado'},
          'unidad_id': AuthService.unidadDelegacionesId,
        }),
      });

      expect(await AuthService.canShareLocationTracking(), isFalse);
    },
  );

  test('delegaciones policia feed is scoped to own delegacion', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Policia',
      'auth_role_id': 10,
      'auth_unidad_id': AuthService.unidadDelegacionesId,
      'auth_delegacion_id': 7,
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 41,
        'role': <String, Object>{'id': 10, 'name': 'Policia'},
        'unidad_id': AuthService.unidadDelegacionesId,
        'delegacion_id': 7,
      }),
    });

    expect(await AuthService.canSeeFullDelegacionesFeed(), isFalse);
    expect(await AuthService.getFeedDelegacionFilterId(), 7);
  });

  test(
    'delegaciones delegado without child delegations keeps own scope',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_role': 'Delegado',
        'auth_unidad_id': AuthService.unidadDelegacionesId,
        'auth_delegacion_id': 8,
        'auth_user_payload': jsonEncode(<String, Object>{
          'id': 42,
          'role': <String, Object>{'name': 'Delegado'},
          'unidad_id': AuthService.unidadDelegacionesId,
          'delegacion_id': 8,
          'delegacion': <String, Object>{
            'id': 8,
            'delegaciones_hijas_count': 0,
          },
        }),
      });

      expect(await AuthService.canSeeFullDelegacionesFeed(), isFalse);
      expect(await AuthService.getFeedDelegacionFilterId(), 8);
    },
  );

  test('delegaciones delegado with child delegations sees full feed', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': 'Delegado',
      'auth_unidad_id': AuthService.unidadDelegacionesId,
      'auth_delegacion_id': 9,
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': 43,
        'role': <String, Object>{'name': 'Delegado'},
        'unidad_id': AuthService.unidadDelegacionesId,
        'delegacion_id': 9,
        'delegacion': <String, Object>{
          'id': 9,
          'delegaciones_hijas': <Map<String, Object>>[
            <String, Object>{'id': 91, 'nombre': 'Hija 1'},
          ],
        },
      }),
    });

    expect(await AuthService.canSeeFullDelegacionesFeed(), isTrue);
    expect(await AuthService.getFeedDelegacionFilterId(), isNull);
  });

  test(
    'delegaciones administrativo with child delegations sees full feed',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_role': 'Administrativo',
        'auth_role_id': 5,
        'auth_unidad_id': AuthService.unidadDelegacionesId,
        'auth_delegacion_id': 10,
        'auth_user_payload': jsonEncode(<String, Object>{
          'id': 44,
          'role': <String, Object>{'id': 5, 'name': 'Administrativo'},
          'unidad_id': AuthService.unidadDelegacionesId,
          'delegacion_id': 10,
          'delegacion': <String, Object>{'id': 10, 'children_count': 2},
        }),
      });

      expect(await AuthService.canSeeFullDelegacionesFeed(), isTrue);
      expect(await AuthService.getFeedDelegacionFilterId(), isNull);
    },
  );

  test(
    'delegaciones subdelegado with child delegations keeps own scope',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_role': 'Subdelegado',
        'auth_unidad_id': AuthService.unidadDelegacionesId,
        'auth_delegacion_id': 11,
        'auth_user_payload': jsonEncode(<String, Object>{
          'id': 45,
          'role': <String, Object>{'name': 'Subdelegado'},
          'unidad_id': AuthService.unidadDelegacionesId,
          'delegacion_id': 11,
          'delegaciones_hijas_count': 3,
        }),
      });

      expect(await AuthService.canSeeFullDelegacionesFeed(), isFalse);
      expect(await AuthService.getFeedDelegacionFilterId(), 11);
    },
  );

  test(
    'superadmin sees constancias manejo without unit or permission',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_role': 'Superadmin',
        'auth_role_id': 1,
        'auth_perms': <String>[],
      });

      expect(await AuthService.canUseConstanciasManejo(), isTrue);
      expect(await AuthService.canEditConstanciasManejo(), isTrue);
    },
  );

  test(
    'unit one user needs modulo examenes permission for constancias',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_unidad_id': 1,
        'auth_user_payload': jsonEncode(<String, Object>{'unidad_id': 1}),
        'auth_perms': <String>['ver modulo examenes', 'editar modulo examenes'],
      });

      expect(await AuthService.canUseConstanciasManejo(), isTrue);
      expect(await AuthService.canEditConstanciasManejo(), isTrue);
    },
  );

  test(
    'unit two user with view but without edit cannot edit constancias',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_unidad_id': AuthService.unidadDelegacionesId,
        'auth_user_payload': jsonEncode(<String, Object>{
          'unidad_id': AuthService.unidadDelegacionesId,
        }),
        'auth_perms': <String>['ver modulo examenes'],
      });

      expect(await AuthService.canUseConstanciasManejo(), isTrue);
      expect(await AuthService.canEditConstanciasManejo(), isFalse);
    },
  );

  test(
    'other unit cannot use constancias even with modulo examenes permission',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_unidad_id': AuthService.unidadSeguridadVialId,
        'auth_user_payload': jsonEncode(<String, Object>{
          'unidad_id': AuthService.unidadSeguridadVialId,
        }),
        'auth_perms': <String>['ver modulo examenes', 'editar modulo examenes'],
      });

      expect(await AuthService.canUseConstanciasManejo(), isFalse);
      expect(await AuthService.canEditConstanciasManejo(), isFalse);
    },
  );
}
