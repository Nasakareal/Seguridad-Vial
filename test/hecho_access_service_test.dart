import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/auth_service.dart';
import 'package:seguridad_vial_app/services/hecho_access_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<HechoEditAccess> loadDelegacionesAccess({
    required String role,
    int? roleId,
    required int userId,
    required int delegacionId,
  }) {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_role': role,
      if (roleId != null) 'auth_role_id': roleId,
      'auth_unidad_id': AuthService.unidadDelegacionesId,
      'auth_delegacion_id': delegacionId,
      'auth_user_id': userId,
      'auth_user_payload': jsonEncode(<String, Object>{
        'id': userId,
        'role': <String, Object>{
          if (roleId != null) 'id': roleId,
          'name': role,
        },
        'unidad_id': AuthService.unidadDelegacionesId,
        'delegacion_id': delegacionId,
      }),
      'auth_perms': <String>['editar hechos'],
    });

    return HechoAccessService.loadEditAccess();
  }

  test(
    'delegaciones delegado can edit other hechos from same delegacion',
    () async {
      final access = await loadDelegacionesAccess(
        role: 'Delegado',
        userId: 101,
        delegacionId: 7,
      );

      expect(access.canEditAnyHecho, isFalse);
      expect(access.canEditDelegacionHechos, isTrue);
      expect(
        access.canEditHecho(<String, dynamic>{
          'delegacion_id': 7,
          'created_by': 202,
          'puede_editar': false,
        }),
        isTrue,
      );
    },
  );

  test(
    'delegaciones delegado cannot edit hechos from another delegacion',
    () async {
      final access = await loadDelegacionesAccess(
        role: 'Delegado',
        userId: 101,
        delegacionId: 7,
      );

      expect(
        access.canEditHecho(<String, dynamic>{
          'delegacion_id': 8,
          'created_by': 202,
          'puede_editar': false,
        }),
        isFalse,
      );
    },
  );

  test('delegaciones policia remains limited to own hechos', () async {
    final access = await loadDelegacionesAccess(
      role: 'Policia',
      roleId: 10,
      userId: 101,
      delegacionId: 7,
    );

    expect(access.canEditDelegacionHechos, isFalse);
    expect(
      access.canEditHecho(<String, dynamic>{
        'delegacion_id': 7,
        'created_by': 202,
        'puede_editar': false,
      }),
      isFalse,
    );
    expect(
      access.canEditHecho(<String, dynamic>{
        'delegacion_id': 7,
        'created_by': 101,
      }),
      isTrue,
    );
  });

  test(
    'delegaciones subdelegado does not inherit delegado edit scope',
    () async {
      final access = await loadDelegacionesAccess(
        role: 'Subdelegado',
        userId: 101,
        delegacionId: 7,
      );

      expect(access.canEditDelegacionHechos, isFalse);
      expect(
        access.canEditHecho(<String, dynamic>{
          'delegacion_id': 7,
          'created_by': 202,
        }),
        isFalse,
      );
    },
  );
}
