import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/local_draft_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_session_owner_key': 'user:1',
    });
  });

  test('stores and restores a local draft for the current user', () async {
    await LocalDraftService.save('hechos:create', <String, dynamic>{
      'folio': 'ABC-123',
      'flags': <String, dynamic>{'danos': true},
    });

    final restored = await LocalDraftService.load('hechos:create');

    expect(restored?['folio'], 'ABC-123');
    expect(restored?['flags'], <String, dynamic>{'danos': true});
  });

  test('separates drafts by session owner', () async {
    await LocalDraftService.save('actividades:create', <String, dynamic>{
      'asunto': 'Operativo local',
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_session_owner_key', 'user:2');

    final restored = await LocalDraftService.load('actividades:create');

    expect(restored, isNull);
  });

  test('removes empty drafts and discards existing values', () async {
    await LocalDraftService.save('vehiculos:create:1', <String, dynamic>{
      'marca': 'NISSAN',
    });

    await LocalDraftService.save('vehiculos:create:1', <String, dynamic>{
      'marca': '',
      'extra': <String, dynamic>{},
    });

    expect(await LocalDraftService.load('vehiculos:create:1'), isNull);

    await LocalDraftService.save('vehiculos:create:1', <String, dynamic>{
      'marca': 'NISSAN',
    });
    await LocalDraftService.discard('vehiculos:create:1');

    expect(await LocalDraftService.load('vehiculos:create:1'), isNull);
  });
}
