import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/settings_personal_service.dart';

void main() {
  test('resolves personal photo paths from common backend fields', () {
    expect(
      SettingsPersonalService.photoUrlFor(const <String, dynamic>{
        'foto_path': 'personal/fotos/elemento.jpg',
      }),
      'https://seguridadvial-mich.com/storage/personal/fotos/elemento.jpg',
    );

    expect(
      SettingsPersonalService.photoUrlFor(const <String, dynamic>{
        'user': <String, dynamic>{
          'profile_photo_url': '/storage/avatars/elemento.jpg',
        },
      }),
      'https://seguridadvial-mich.com/storage/avatars/elemento.jpg',
    );
  });
}
