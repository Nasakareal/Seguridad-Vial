import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/modules/cultura_vial/games/detecta_peligro_screen.dart';
import 'package:seguridad_vial_app/modules/cultura_vial/games/quien_pasa_primero_screen.dart';
import 'package:seguridad_vial_app/modules/cultura_vial/games/un_segundo_antes_screen.dart';
import 'package:seguridad_vial_app/modules/cultura_vial/screens/cultura_vial_game_hub_screen.dart';
import 'package:seguridad_vial_app/modules/cultura_vial/services/cultura_vial_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_user_email': 'jugador-pruebas@example.test',
    });
  });

  testWidgets('hazard game starts with a direct observation tutorial', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DetectaPeligroScreen()));
    expect(
      find.text('Observa la calle.\nEncuentra el peligro.'),
      findsOneWidget,
    );
    await tester.tap(find.text('COMENZAR MISIÓN'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('El balón perdido'), findsOneWidget);
    expect(
      find.text('Toca el peligro en cuanto aparezca'),
      findsOneWidget,
    );
  });

  testWidgets('intersection game uses draggable ordering', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: QuienPasaPrimeroScreen()));
    await tester.tap(find.text('¡Comenzar misión!'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.text('Comprobar y ver el cruce'), findsOneWidget);
  });

  testWidgets('prevention game allows branching decisions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UnSegundoAntesScreen()));
    await tester.tap(find.text('Comenzar recorrido'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('¿Qué haces un segundo antes?'), findsOneWidget);
    expect(find.text('Reducir y preparar el frenado'), findsOneWidget);
  });

  test('progress awards XP, stars and safety achievements', () async {
    final service = CulturaVialProgressService.instance;
    await service.load();
    final reward = await service.recordGame(
      gameId: 'detecta_peligro',
      score: 1200,
      stars: 3,
      correct: 4,
      mistakes: 0,
      hazards: 20,
    );

    expect(reward.xpEarned, greaterThan(0));
    expect(service.progress.stars['detecta_peligro'], 3);
    expect(service.progress.achievements, contains('ojo_aguila'));
    expect(service.progress.achievements, contains('cero_riesgos'));
  });

  testWidgets('game hub remains usable on a compact phone', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: CulturaVialGameHubScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Elige tu misión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
