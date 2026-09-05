import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/local_draft_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test(
    'discard waits for in-flight writes and prevents stale autosaves',
    () async {
      final draft = LocalDraftAutosave(
        draftId: 'hechos:create',
        collect: () => {'folio': 'HECHO-ANTERIOR'},
      );
      final first = draft.flush();
      final second = draft.flush();
      await draft.discard(stopAutosave: true);
      await Future.wait([first, second]);
      await draft.flush();
      draft.notifyChanged();
      expect(await LocalDraftService.load('hechos:create'), isNull);
      draft.dispose();
    },
  );

  test('a disposed autosave cannot restore into a replacement form', () async {
    await LocalDraftService.save('hechos:create', {'folio': 'ANTERIOR'});
    final draft = LocalDraftAutosave(
      draftId: 'hechos:create',
      collect: () => {},
    );
    var applied = false;
    final restore = draft.restore((_) => applied = true);
    draft.dispose();
    expect(await restore, isFalse);
    expect(applied, isFalse);
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

  test('recovery decision protects the stored snapshot from background autosave', () async {
    await LocalDraftService.save('hechos:create', {'calle': 'CAPTURA ANTERIOR'});
    final decision = Completer<bool>();
    final draft = LocalDraftAutosave(draftId: 'hechos:create', collect: () => {'calle': 'VACIO NUEVO'});
    Map<String, dynamic>? applied;
    final restore = draft.restore((values) => applied = values, shouldRestore: (_) => decision.future);
    await draft.flush();
    draft.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect((await LocalDraftService.load('hechos:create'))?['calle'], 'CAPTURA ANTERIOR');
    decision.complete(true);
    expect(await restore, isTrue);
    expect(applied?['calle'], 'CAPTURA ANTERIOR');
    draft.dispose();
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
