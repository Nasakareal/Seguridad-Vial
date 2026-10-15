import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('identifica una sesión de grúa por account_type', () async {
    SharedPreferences.setMockInitialValues({
      'auth_user_payload': jsonEncode({
        'id': 10,
        'account_type': 'grua',
        'role': 'GRUA',
      }),
    });

    expect(await AuthService.isGruaUser(), isTrue);
  });

  test('no confunde un usuario operativo con una cuenta de grúa', () async {
    SharedPreferences.setMockInitialValues({
      'auth_user_payload': jsonEncode({
        'id': 20,
        'account_type': 'user',
        'role': 'Administrador',
      }),
      'auth_role': 'Administrador',
    });

    expect(await AuthService.isGruaUser(), isFalse);
  });
}
