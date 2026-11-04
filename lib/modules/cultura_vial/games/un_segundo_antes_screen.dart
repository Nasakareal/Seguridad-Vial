import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/cultura_vial_audio_service.dart';
import '../widgets/game_ui.dart';

const _assets = 'assets/cultura_vial/un_segundo_antes/';

class UnSegundoAntesScreen extends StatefulWidget {
  const UnSegundoAntesScreen({super.key});

  @override
  State<UnSegundoAntesScreen> createState() => _UnSegundoAntesScreenState();
}

class _UnSegundoAntesScreenState extends State<UnSegundoAntesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sequence;
  late List<int> _choiceOrder;
  int _level = 0;
  int _score = 0;
  int _safeChoices = 0;
  int _mistakes = 0;
  int? _choice;
  bool _tutorial = true;
  bool _alreadyScored = false;
  bool _reviewing = false;

  static const _scenes = <_DecisionScene>[
    _DecisionScene(
      title: 'El autobús oculta el cruce',
      condition: 'Tarde soleada · visibilidad parcial',
      type: _DecisionType.bus,
      clue: 'El autobús tapa a quien podría cruzar por delante.',
      choices: [
        _DecisionChoice(
          'Reducir y preparar el frenado',
          2,
          'Reduciste la velocidad antes del punto ciego. La persona cruza y conservas espacio para detenerte.',
        ),
        _DecisionChoice(
          'Mantener la velocidad',
          1,
          'Detectas al peatón muy tarde. Debes frenar de golpe para evitar el conflicto.',
        ),
        _DecisionChoice(
          'Rebasar al autobús',
          0,
          'Avanzas hacia una zona oculta sin comprobar el paso peatonal. El riesgo de atropellamiento aumenta.',
        ),
      ],
    ),
    _DecisionScene(
      title: 'Cochera con poca visibilidad',
      condition: 'Zona habitacional · tarde',
      type: _DecisionType.driveway,
      clue: 'Un vehículo comienza a salir de una cochera a tu derecha.',
      choices: [
        _DecisionChoice(
          'Soltar acelerador y dejar espacio',
          2,
          'Dejaste margen para que el vehículo termine de incorporarse sin cruzarse con tu trayectoria.',
        ),
        _DecisionChoice(
          'Acelerar para pasar primero',
          0,
          'Acortas la distancia justo cuando el vehículo sale. Las trayectorias se cruzan y debes hacer una maniobra brusca.',
        ),
        _DecisionChoice(
          'Tocar el claxon y seguir igual',
          1,
          'El claxon alerta, pero no sustituye reducir la velocidad ni mantener espacio de seguridad.',
        ),
      ],
    ),
    _DecisionScene(
      title: 'Lluvia y reflejos',
      condition: 'Noche · pavimento mojado',
      type: _DecisionType.rain,
      clue: 'Las luces de freno aparecen sobre un pavimento resbaladizo.',
      choices: [
        _DecisionChoice(
          'Aumentar distancia y bajar velocidad',
          2,
          'Conservas distancia suficiente para frenar de forma progresiva cuando el auto de adelante reduce la marcha.',
        ),
        _DecisionChoice(
          'Seguir las luces del auto delantero',
          1,
          'Depender de sus movimientos deja menos tiempo para reaccionar, especialmente cuando el piso está mojado.',
        ),
        _DecisionChoice(
          'Usar luces altas y acelerar',
          0,
          'El brillo y la velocidad reducen tu margen de reacción. Te acercas peligrosamente al vehículo que frena.',
        ),
      ],
    ),
    _DecisionScene(
      title: 'Motocicleta en punto ciego',
      condition: 'Avenida · tránsito moderado',
      type: _DecisionType.blindSpot,
      clue: 'Una motocicleta avanza por el costado que quieres ocupar.',
      choices: [
        _DecisionChoice(
          'Esperar, señalizar y verificar',
          2,
          'Esperaste a que la motocicleta pasara antes de cambiar de carril y evitaste cerrarle el camino.',
        ),
        _DecisionChoice(
          'Cerrar el espacio lentamente',
          0,
          'Aunque lo hagas despacio, invades la trayectoria de la motocicleta y puedes derribarla.',
        ),
        _DecisionChoice(
          'Girar mirando solamente el espejo',
          1,
          'El espejo no muestra todos los puntos ciegos. La motocicleta queda demasiado cerca de tu maniobra.',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _sequence = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();
    _makeChoiceOrder();
  }

  void _makeChoiceOrder() {
    _choiceOrder = List<int>.generate(_scenes[_level].choices.length, (i) => i)
      ..shuffle(math.Random(73 + _level * 31));
  }

  @override
  void dispose() {
    _sequence.dispose();
    super.dispose();
  }

  void _choose(int originalIndex) {
    if (_choice != null) return;
    final selection = _scenes[_level].choices[originalIndex];
    setState(() {
      _choice = originalIndex;
      if (!_alreadyScored) {
        _alreadyScored = true;
        if (selection.safety == 2) {
          _safeChoices++;
          _score += 420;
        } else if (selection.safety == 1) {
          _mistakes++;
          _score += 180;
        } else {
          _mistakes++;
        }
      }
    });
    _sequence.forward(from: 0);
    CulturaVialAudioService.instance.playEffect(
      selection.safety == 2 ? CulturaVialSound.correct : CulturaVialSound.wrong,
    );
  }

  void _rewind() {
    setState(() {
      _choice = null;
      _reviewing = true;
    });
    _sequence.repeat();
    CulturaVialAudioService.instance.playEffect(CulturaVialSound.tap);
  }

  void _next() {
    if (_level + 1 >= _scenes.length) {
      _finish();
      return;
    }
    setState(() {
      _level++;
      _choice = null;
      _reviewing = false;
      _alreadyScored = false;
      _makeChoiceOrder();
    });
    _sequence.repeat();
  }

  void _finish() {
    final stars = _safeChoices == _scenes.length && _mistakes == 0
        ? 3
        : _safeChoices >= 3
            ? 2
            : 1;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameResultScreen(
          gameId: 'segundo_antes',
          title: 'Un segundo antes',
          score: _score,
          correct: _safeChoices,
          mistakes: _mistakes,
          stars: stars,
          preventiveChoices: _safeChoices,
          onReplay: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UnSegundoAntesScreen()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scenes[_level];
    final choice = _choice == null ? null : scene.choices[_choice!];
    return CulturaVialGameScaffold(
      title: 'Un segundo antes',
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              '$_score pts',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: culturaBlue,
              ),
            ),
          ),
        ),
      ],
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 780;
              final visual = AnimatedBuilder(
                animation: _sequence,
                builder: (_, __) => _sceneView(scene, choice, _sequence.value),
              );
              final panel = _decisionPanel(scene, choice);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _topPill('ESCENA ${(_level + 1).toString().padLeft(2, '0')}',
                                const Color(0xFFE9F2FE), culturaBlue),
                            const Spacer(),
                            Text(
                              '${_level + 1} / ${_scenes.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: culturaInk,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: (_level + 1) / _scenes.length,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: wide
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: SingleChildScrollView(child: visual)),
                                const SizedBox(width: 14),
                                Expanded(flex: 5, child: SingleChildScrollView(child: panel)),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                            children: [
                              visual,
                              const SizedBox(height: 12),
                              panel,
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
          if (_tutorial)
            Positioned.fill(
              child: Container(
                color: const Color(0xE90B2034),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(26),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.slow_motion_video_rounded,
                            size: 74,
                            color: culturaYellow,
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'Cambia el desenlace',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Observa el riesgo, elige qué harías y mira cómo cambia la escena. Puedes rebobinar para aprender de las otras decisiones.',
                            style: TextStyle(color: Color(0xFFDBEAF3), fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Solo la primera decisión de cada escena suma puntos.',
                            style: TextStyle(
                              color: Color(0xFFFBE7AF),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          GamePressable(
                            onPressed: () => setState(() => _tutorial = false),
                            color: culturaGreen,
                            child: const Text('Comenzar recorrido'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topPill(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: background,
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  Widget _sceneView(_DecisionScene scene, _DecisionChoice? choice, double progress) {
    final safety = choice?.safety;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: LayoutBuilder(
              builder: (context, bounds) {
                final w = bounds.maxWidth;
                final h = bounds.maxHeight;
                final t = progress * progress * (3 - 2 * progress);
                Widget sprite(String name, double x, double y, double width, double height,
                    {double angle = 0}) {
                  return Positioned(
                    left: x / 960 * w,
                    top: y / 720 * h,
                    width: width / 960 * w,
                    height: height / 720 * h,
                    child: Transform.rotate(
                      angle: angle,
                      child: Image.asset('$_assets$name', fit: BoxFit.fill,
                          filterQuality: FilterQuality.medium),
                    ),
                  );
                }

                final selected = safety != null;
                final risky = selected && safety == 0;
                final medium = selected && safety == 1;
                final double advance = selected ? t : 0.0;
                final double preview = selected ? 0.0 : progress;
                final objects = <Widget>[];
                switch (scene.type) {
                  case _DecisionType.bus:
                    objects.add(sprite('peaton.png',
                      684 - (selected ? 252 * advance : 65 * preview),
                      338 + (selected ? 45 * advance : 8 * preview),
                      93 + 13 * advance, 147 + 18 * advance));
                    objects.add(sprite('autobus.png', 611, 287, 208, 290));
                    objects.add(sprite('capo_auto.png',
                      318 + (risky ? 54 * advance : medium ? 19 * advance : 0),
                      648 - (risky ? 78 * advance : medium ? 27 * advance : 0),
                      326, 130));
                  case _DecisionType.driveway:
                    objects.add(sprite('auto_lateral.png',
                      796 - (selected ? 276 * advance : 35 * preview),
                      370 + (selected ? 98 * advance : 13 * preview),
                      206 + 27 * advance, 110 + 20 * advance,
                      angle: -0.11));
                    objects.add(sprite('capo_auto.png',
                      317 + (risky ? 30 * advance : 0),
                      648 - (risky ? 83 * advance : medium ? 25 * advance : 0),
                      326, 130));
                  case _DecisionType.rain:
                    objects.add(sprite('auto_frenando.png',
                      421 - (selected ? 12 * advance : 2 * preview),
                      298 + (selected ? (safety == 2 ? 45 : safety == 1 ? 91 : 133) * advance : 7 * preview),
                      118 + (selected ? (safety == 2 ? 22 : safety == 1 ? 46 : 69) * advance : 0),
                      155 + (selected ? (safety == 2 ? 29 : safety == 1 ? 61 : 96) * advance : 0)));
                    objects.add(sprite('capo_auto.png', 318,
                      646 - (risky ? 63 * advance : medium ? 19 * advance : 0),
                      326, 130));
                  case _DecisionType.blindSpot:
                    objects.add(sprite('auto_amarillo.png', 345, 295, 126, 165));
                    objects.add(sprite('motocicleta.png',
                      590 - (selected ? 46 * advance : 9 * preview),
                      467 - (selected ? (safety == 2 ? 194 : safety == 1 ? 98 : 52) * advance : 20 * preview),
                      113 - (selected ? 23 * advance : 0),
                      151 - (selected ? 32 * advance : 0)));
                    objects.add(sprite('auto_azul.png',
                      331 + (selected ? (safety == 2 ? 0 : safety == 1 ? 64 : 139) * advance : 0),
                      501 - (selected ? 15 * advance : 0),
                      164, 207,
                      angle: selected ? (safety == 2 ? 0 : 0.05 * advance) : 0));
                }
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        '$_assets${scene.background}',
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    ...objects,
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _SceneEffectsPainter(
                            scene.type, progress, safety,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _sceneChip(
                        selected ? 'DESENLACE' : 'OBSERVA LA PISTA',
                        selected ? Icons.play_circle_outline_rounded : Icons.visibility_rounded,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _sceneChip(
                        selected ? (safety == 2 ? 'PREVENCIÓN' : safety == 1 ? 'CASI ACCIDENTE' : 'RIESGO ALTO')
                            : 'ANTES DE ACTUAR',
                        selected ? Icons.route_rounded : Icons.timer_outlined,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 8,
                        color: const Color(0xFF0C2942),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: selected ? progress : 1 - progress,
                          child: ColoredBox(
                            color: selected
                                ? safety == 2 ? culturaGreen : safety == 1 ? culturaYellow : culturaRed
                                : culturaYellow,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(safety == null ? Icons.search_rounded : Icons.lightbulb_outline,
                  color: culturaBlue, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  safety == null ? scene.clue : 'Observa la trayectoria y compara el margen de seguridad.',
                  style: const TextStyle(
                    color: Color(0xFF51677D),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sceneChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xE8133048),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x77C1E0EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFFD36D), size: 14),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: .3,
            fontSize: 9,
            color: Colors.white,
          )),
        ],
      ),
    );
  }

  Widget _decisionPanel(_DecisionScene scene, _DecisionChoice? choice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9E6EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            scene.title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: culturaInk,
            ),
          ),
          const SizedBox(height: 5),
          Text(scene.condition, style: const TextStyle(
              color: Color(0xFF667B8C), fontSize: 13)),
          const SizedBox(height: 14),
          if (choice == null) ...[
            const Text('¿Qué haces un segundo antes?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: culturaInk)),
            const SizedBox(height: 11),
            for (var i = 0; i < _choiceOrder.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: GamePressable(
                  onPressed: () => _choose(_choiceOrder[i]),
                  color: culturaBlue,
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 13),
                  child: Row(
                    children: [
                      Container(
                        height: 27,
                        width: 27,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0x44FFFFFF),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(String.fromCharCode(65 + i),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(scene.choices[_choiceOrder[i]].label,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ))),
                    ],
                  ),
                ),
              ),
            if (_reviewing)
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text('Modo práctica: puedes probar otra decisión, sin sumar puntos otra vez.',
                  style: TextStyle(color: Color(0xFF65788A), fontSize: 12)),
              ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: choice.safety == 2
                    ? const Color(0xFFE8F8EE)
                    : choice.safety == 1
                        ? const Color(0xFFFFF3DB)
                        : const Color(0xFFFFECEA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    choice.safety == 2
                        ? Icons.verified_rounded
                        : choice.safety == 1
                            ? Icons.warning_amber_rounded
                            : Icons.report_problem_rounded,
                    size: 38,
                    color: choice.safety == 2
                        ? culturaGreen
                        : choice.safety == 1
                            ? const Color(0xFFCF8D18)
                            : culturaRed,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    choice.safety == 2
                        ? '¡Elegiste prevenir!'
                        : choice.safety == 1
                            ? 'Te faltó margen de reacción'
                            : 'La maniobra generó peligro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: choice.safety == 2
                          ? const Color(0xFF168055)
                          : choice.safety == 1
                              ? const Color(0xFF9A6810)
                              : culturaRed,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(choice.consequence,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: culturaInk,
                      height: 1.4,
                    )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _rewind,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Retroceder y probar otra acción'),
            ),
            const SizedBox(height: 8),
            GamePressable(
              onPressed: _next,
              color: culturaBlue,
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(_level + 1 == _scenes.length
                ? 'Ver resultado' : 'Continuar recorrido'),
            ),
          ],
        ],
      ),
    );
  }
}

enum _DecisionType { bus, driveway, rain, blindSpot }

class _DecisionChoice {
  final String label;
  final int safety;
  final String consequence;
  const _DecisionChoice(this.label, this.safety, this.consequence);
}

class _DecisionScene {
  final String title;
  final String condition;
  final _DecisionType type;
  final String clue;
  final List<_DecisionChoice> choices;
  const _DecisionScene({
    required this.title,
    required this.condition,
    required this.type,
    required this.clue,
    required this.choices,
  });

  String get background => switch (type) {
    _DecisionType.bus => 'fondo_autobus.png',
    _DecisionType.driveway => 'fondo_cochera.png',
    _DecisionType.rain => 'fondo_lluvia.png',
    _DecisionType.blindSpot => 'fondo_punto_ciego.png',
  };
}

class _SceneEffectsPainter extends CustomPainter {
  final _DecisionType type;
  final double progress;
  final int? safety;
  const _SceneEffectsPainter(this.type, this.progress, this.safety);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 960, size.height / 720);
    if (type == _DecisionType.rain) {
      final rain = Paint()
        ..color = const Color(0xFFB8DEEF).withValues(alpha: .61)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 63; i++) {
        final x = (i * 131.0 + progress * 190) % 990 - 15;
        final y = (i * 87.0 + progress * 770) % 770 - 25;
        canvas.drawLine(Offset(x, y), Offset(x - 16, y + 32), rain);
      }
    }
    if (safety != null && progress > .43) {
      final reveal = ((progress - .43) / .4).clamp(0.0, 1.0);
      final emphasis = math.sin(reveal * math.pi / 2);
      final center = switch (type) {
        _DecisionType.bus => const Offset(478, 474),
        _DecisionType.driveway => const Offset(630, 516),
        _DecisionType.rain => const Offset(493, 528),
        _DecisionType.blindSpot => const Offset(540, 497),
      };
      final highlight = safety == 2
          ? culturaGreen
          : safety == 1
              ? const Color(0xFFFFA62D)
              : culturaRed;
      final radius = 64.0 + 24 * emphasis;
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = highlight.withValues(alpha: .17 * emphasis),
      );
      canvas.drawCircle(
        center,
        radius * .82,
        Paint()
          ..color = highlight.withValues(alpha: .7 * emphasis)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
      if (progress >= .74) {
        final painter = TextPainter(
          text: TextSpan(
            text: safety == 2 ? '✓' : '!',
            style: TextStyle(
              fontSize: 61,
              fontWeight: FontWeight.w900,
              color: highlight,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          center - Offset(painter.width / 2, painter.height / 2),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SceneEffectsPainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.progress != progress ||
      oldDelegate.safety != safety;
}
