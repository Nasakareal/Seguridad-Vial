import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/cultura_vial_audio_service.dart';
import '../widgets/game_ui.dart';

class DetectaPeligroScreen extends StatefulWidget {
  const DetectaPeligroScreen({super.key});

  @override
  State<DetectaPeligroScreen> createState() => _DetectaPeligroScreenState();
}

class _DetectaPeligroScreenState extends State<DetectaPeligroScreen>
    with SingleTickerProviderStateMixin {
  static const String _art = 'assets/cultura_vial/detecta_peligro/';
  late final AnimationController _timeline;
  int _level = 0;
  int _score = 0;
  int _streak = 0;
  int _mistakes = 0;
  int _hits = 0;
  bool _resolved = false;
  bool _hit = false;
  bool _tutorial = true;
  String? _feedback;

  static const _scenarios = <_HazardScenario>[
    _HazardScenario(
      title: 'El balón perdido',
      hint: 'Observa junto a los vehículos estacionados a la derecha.',
      explanation:
          'La pelota es la primera señal. Reduce la velocidad y prepárate: detrás puede aparecer una niña o un niño.',
      image: 'fondo_escuela.png',
      type: _HazardType.child,
      revealAt: .26,
      idealAt: .43,
      dangerAt: .78,
    ),
    _HazardScenario(
      title: 'Puerta inesperada',
      hint: 'Una puerta puede abrirse hacia tu carril sin aviso.',
      explanation:
          'Una puerta que comienza a abrirse invade la trayectoria. Conserva distancia lateral y anticipa la maniobra.',
      image: 'fondo_puerta.png',
      type: _HazardType.door,
      revealAt: .29,
      idealAt: .44,
      dangerAt: .75,
    ),
    _HazardScenario(
      title: 'Cruce bajo la lluvia',
      hint: 'Vigila la banqueta antes de llegar al cruce.',
      explanation:
          'La lluvia reduce la visibilidad y aumenta la distancia de frenado. Anticipa al peatón antes de que cruce.',
      image: 'fondo_lluvia.png',
      type: _HazardType.pedestrian,
      revealAt: .32,
      idealAt: .48,
      dangerAt: .79,
      rain: true,
    ),
    _HazardScenario(
      title: 'Moto entre vehículos',
      hint: 'Una motocicleta puede salir del punto ciego de la camioneta.',
      explanation:
          'Una motocicleta puede ocultarse detrás de un vehículo grande. No cierres su trayectoria y deja espacio.',
      image: 'fondo_moto.png',
      type: _HazardType.motorcycle,
      revealAt: .49,
      idealAt: .61,
      dangerAt: .82,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timeline = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_resolved) {
          _timeout();
        }
      });
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  void _start() {
    setState(() => _tutorial = false);
    _timeline.forward(from: 0);
  }

  void _tapScene(TapUpDetails details, Rect scene) {
    if (_resolved || _tutorial || !scene.contains(details.localPosition)) {
      return;
    }
    final scenario = _scenarios[_level];
    final progress = _timeline.value;
    final point = details.localPosition - scene.topLeft;
    final localSize = scene.size;
    if (progress >= scenario.revealAt &&
        _touchTargets(scenario, progress, localSize)
            .any((rect) => rect.inflate(14).contains(point))) {
      _resolveHit(scenario, progress);
      return;
    }
    setState(() {
      _mistakes++;
      _streak = 0;
      _score = math.max(0, _score - 45);
      _feedback = 'Falsa alarma · −45 puntos';
    });
    CulturaVialAudioService.instance.playEffect(CulturaVialSound.wrong);
    Future<void>.delayed(const Duration(milliseconds: 950), () {
      if (mounted && !_resolved) {
        setState(() => _feedback = null);
      }
    });
  }

  void _resolveHit(_HazardScenario scenario, double progress) {
    _timeline.stop();
    final anticipation = ((scenario.dangerAt - progress) /
            (scenario.dangerAt - scenario.revealAt))
        .clamp(0.0, 1.0);
    final gained =
        180 + (anticipation * 320).round() + math.min(_streak, 4) * 60;
    setState(() {
      _resolved = true;
      _hit = true;
      _hits++;
      _streak++;
      _score += gained;
      _feedback = progress <= scenario.idealAt
          ? '¡Excelente anticipación! +$gained'
          : anticipation > .35
              ? '¡Buen ojo! +$gained'
              : '¡Riesgo detectado! +$gained';
    });
    CulturaVialAudioService.instance.playEffect(
      _streak >= 2 ? CulturaVialSound.combo : CulturaVialSound.correct,
    );
  }

  void _timeout() {
    if (_resolved) return;
    setState(() {
      _mistakes++;
      _streak = 0;
      _resolved = true;
      _hit = false;
      _feedback = '¡El peligro te sorprendió!';
    });
    CulturaVialAudioService.instance.playEffect(CulturaVialSound.wrong);
  }

  void _next() {
    if (_level + 1 == _scenarios.length) {
      _finish();
      return;
    }
    setState(() {
      _level++;
      _resolved = false;
      _hit = false;
      _feedback = null;
    });
    _timeline.forward(from: 0);
  }

  void _finish() {
    final stars = _hits == _scenarios.length && _mistakes == 0
        ? 3
        : _hits >= 3
            ? 2
            : 1;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameResultScreen(
          gameId: 'detecta_peligro',
          title: 'Detecta el peligro',
          score: _score,
          correct: _hits,
          mistakes: _mistakes,
          stars: stars,
          hazards: _hits,
          onReplay: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const DetectaPeligroScreen(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scenario = _scenarios[_level];
    return CulturaVialGameScaffold(
      title: 'Detecta el peligro',
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
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F1FF),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            'ESCENA ${(_level + 1).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Color(0xFF20598A),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_streak >= 2)
                          Row(
                            children: [
                              const Icon(
                                Icons.local_fire_department_rounded,
                                color: Color(0xFFFF8534),
                                size: 20,
                              ),
                              Text(
                                'COMBO x$_streak',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF9A4C15),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        Text(
                          '${_level + 1} / ${_scenarios.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: culturaInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_level + 1) / _scenarios.length,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(8),
                      backgroundColor: const Color(0xFFDDE9F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        culturaBlue,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        scenario.title,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: culturaInk,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        scenario.hint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF61768A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final scene = _sceneBounds(size);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _tapScene(details, scene),
                      child: AnimatedBuilder(
                        animation: _timeline,
                        builder: (context, _) => _buildScene(
                          scene,
                          scenario,
                          _timeline.value,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 92),
                padding: const EdgeInsets.fromLTRB(17, 13, 17, 15),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFE3ECF3)),
                  ),
                ),
                child: _resolved
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _hit
                                    ? Icons.verified_rounded
                                    : Icons.error_outline_rounded,
                                size: 23,
                                color: _hit ? culturaGreen : culturaRed,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  _feedback ?? '',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _hit ? culturaGreen : culturaRed,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            scenario.explanation,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF475B70),
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GamePressable(
                            onPressed: _next,
                            color: culturaBlue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 27,
                              vertical: 12,
                            ),
                            child: Text(
                              _level + 1 == _scenarios.length
                                  ? 'Ver resultado'
                                  : 'Siguiente escena',
                            ),
                          ),
                        ],
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Row(
                          key: ValueKey(_feedback),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _feedback == null
                                  ? Icons.touch_app_outlined
                                  : Icons.warning_amber_rounded,
                              color: _feedback == null
                                  ? culturaBlue
                                  : culturaRed,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _feedback ??
                                    'Toca el peligro en cuanto aparezca',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _feedback == null
                                      ? culturaInk
                                      : culturaRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          if (_tutorial)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xEC0B2037),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF234A68),
                            ),
                            child: const Icon(
                              Icons.visibility_rounded,
                              size: 65,
                              color: culturaYellow,
                            ),
                          ),
                          const SizedBox(height: 21),
                          const Text(
                            'MISIÓN: ANTICIPAR',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: culturaYellow,
                              fontSize: 13,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Observa la calle.\nEncuentra el peligro.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              height: 1.13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Toca el riesgo apenas lo identifiques. Ganas más puntos si te anticipas, y pierdes por falsas alarmas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFD6E6F7),
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 23),
                          GamePressable(
                            onPressed: _start,
                            color: culturaGreen,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 14,
                            ),
                            child: const Text('COMENZAR MISIÓN'),
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

  Widget _buildScene(
    Rect scene,
    _HazardScenario scenario,
    double progress,
  ) {
    final size = scene.size;
    final visible = progress >= scenario.revealAt;
    final t = ((progress - scenario.revealAt) / (1 - scenario.revealAt))
        .clamp(0.0, 1.0);
    final primary = _riskRect(scenario, progress, size);
    final remaining = (8 * (1 - progress)).ceil();
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF172E42)),
        Positioned.fromRect(
          rect: scene,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  '$_art${scenario.image}',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF294E68),
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white70,
                        size: 50,
                      ),
                    ),
                  ),
                ),
                if (scenario.type == _HazardType.child && visible)
                  _sprite('balon.png', _ballRect(progress, size)),
                if (scenario.type == _HazardType.child && progress >= .46)
                  _sprite('nina.png', _girlRect(progress, size)),
                if (scenario.type == _HazardType.pedestrian && visible)
                  _sprite('peaton.png', primary),
                if (scenario.type == _HazardType.motorcycle && progress >= .36)
                  _sprite('moto_perspectiva.png', primary),
                if (scenario.type == _HazardType.child)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Image.asset(
                        '${_art}oclusor_escuela.png',
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                if (scenario.type == _HazardType.motorcycle)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Image.asset(
                        '${_art}oclusor_moto.png',
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                if (scenario.type == _HazardType.door && progress >= .22)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _DoorPainter(progress),
                      ),
                    ),
                  ),
                if (scenario.rain)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _RainPainter(progress),
                    ),
                  ),
                if (_resolved)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ResultPainter(
                          position: primary.center,
                          success: _hit,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 103,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xDD07192C),
                            const Color(0x0007192C),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 13,
                  left: 13,
                  right: 13,
                  child: IgnorePointer(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xCC072238),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: const Color(0x66FFFFFF),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.sensors_rounded,
                                size: 16,
                                color: culturaYellow,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'OBSERVA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: remaining <= 3 && !_resolved
                                ? const Color(0xDCC34727)
                                : const Color(0xCC072238),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                color: Colors.white,
                                size: 17,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$remaining s',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 9,
                  child: IgnorePointer(
                    child: LinearProgressIndicator(
                      value: 1 - progress,
                      minHeight: 9,
                      backgroundColor: const Color(0xAB10273A),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _resolved
                            ? (_hit ? culturaGreen : culturaRed)
                            : t > .72
                                ? const Color(0xFFFF7656)
                                : culturaYellow,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sprite(String file, Rect rect, {double opacity = 1}) {
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Image.asset(
            '$_art$file',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

enum _HazardType { child, door, pedestrian, motorcycle }

class _HazardScenario {
  final String title;
  final String hint;
  final String explanation;
  final String image;
  final _HazardType type;
  final double revealAt;
  final double idealAt;
  final double dangerAt;
  final bool rain;

  const _HazardScenario({
    required this.title,
    required this.hint,
    required this.explanation,
    required this.image,
    required this.type,
    required this.revealAt,
    required this.idealAt,
    required this.dangerAt,
    this.rain = false,
  });
}

Rect _sceneBounds(Size viewport) {
  final height = math.min(viewport.height, viewport.width * 4 / 3);
  final width = height * 3 / 4;
  return Rect.fromLTWH(
    (viewport.width - width) / 2,
    (viewport.height - height) / 2,
    width,
    height,
  );
}

double _motion(double progress, double start, double end) {
  final t = ((progress - start) / (end - start)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

Rect _ballRect(double progress, Size size) {
  final t = _motion(progress, .26, .78);
  final d = size.width * (.018 + .022 * t);
  return Rect.fromCenter(
    center: Offset(
      size.width * (.716 - .155 * t),
      size.height * (.640 + .108 * t),
    ),
    width: d * 2,
    height: d * 2,
  );
}

Rect _girlRect(double progress, Size size) {
  final t = _motion(progress, .46, .92);
  return Rect.fromCenter(
    center: Offset(
      size.width * (.728 - .206 * t),
      size.height * (.580 + .116 * t),
    ),
    width: size.width * (.085 + .042 * t),
    height: size.height * (.123 + .060 * t),
  );
}

Rect _doorRect(double progress, Size size) {
  final t = _motion(progress, .22, .66);
  return Rect.fromLTRB(
    size.width * (.681 - .105 * t),
    size.height * (.617 - .015 * t),
    size.width * .700,
    size.height * (.700 + .006 * t),
  );
}

Rect _pedestrianRect(double progress, Size size) {
  final t = _motion(progress, .32, .91);
  return Rect.fromCenter(
    center: Offset(
      size.width * (.148 + .37 * t),
      size.height * (.604 + .066 * t),
    ),
    width: size.width * (.113 + .039 * t),
    height: size.height * (.170 + .041 * t),
  );
}

Rect _motorcycleRect(double progress, Size size) {
  final t = _motion(progress, .36, .88);
  return Rect.fromCenter(
    center: Offset(
      size.width * (.686 - .165 * t),
      size.height * (.607 + .172 * t),
    ),
    width: size.width * (.097 + .084 * t),
    height: size.height * (.129 + .105 * t),
  );
}

Rect _riskRect(_HazardScenario scenario, double progress, Size size) {
  switch (scenario.type) {
    case _HazardType.child:
      return progress >= .46
          ? _girlRect(progress, size)
          : _ballRect(progress, size);
    case _HazardType.door:
      return _doorRect(progress, size);
    case _HazardType.pedestrian:
      return _pedestrianRect(progress, size);
    case _HazardType.motorcycle:
      return _motorcycleRect(progress, size);
  }
}

List<Rect> _touchTargets(
  _HazardScenario scenario,
  double progress,
  Size size,
) {
  if (progress < scenario.revealAt) return const [];
  if (scenario.type == _HazardType.child) {
    return [
      _ballRect(progress, size),
      if (progress >= .46) _girlRect(progress, size),
    ];
  }
  if (scenario.type == _HazardType.motorcycle) {
    final risk = _motorcycleRect(progress, size);
    final visibleEdge = size.width * .628;
    if (risk.left >= visibleEdge) return const [];
    return [Rect.fromLTRB(
      risk.left,
      risk.top,
      math.min(risk.right, visibleEdge),
      risk.bottom,
    )];
  }
  return [_riskRect(scenario, progress, size)];
}

class _DoorPainter extends CustomPainter {
  final double progress;
  const _DoorPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 900, size.height / 1200);
    final t = _motion(progress, .22, .66);
    final hingeTop = const Offset(610, 742);
    final hingeBottom = const Offset(618, 836);
    final topOuter = Offset(608 - 97 * t, 742 - 16 * t);
    final bottomOuter = Offset(617 - 103 * t, 836 + 9 * t);
    final shadow = Path()
      ..moveTo(hingeBottom.dx + 5, hingeBottom.dy + 14)
      ..lineTo(bottomOuter.dx + 8, bottomOuter.dy + 26)
      ..lineTo(topOuter.dx + 9, topOuter.dy + 27)
      ..close();
    canvas.drawPath(
      shadow,
      Paint()..color = const Color(0x6613263A),
    );
    final door = Path()
      ..moveTo(hingeTop.dx, hingeTop.dy)
      ..lineTo(topOuter.dx, topOuter.dy)
      ..lineTo(bottomOuter.dx, bottomOuter.dy)
      ..lineTo(hingeBottom.dx, hingeBottom.dy)
      ..close();
    canvas.drawPath(
      door,
      Paint()
        ..color = const Color(0xFFF0F6FB)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      door,
      Paint()
        ..color = const Color(0xFF627D92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round,
    );
    final glass = Path()
      ..moveTo(hingeTop.dx - 6, hingeTop.dy + 10)
      ..lineTo(topOuter.dx + 4, topOuter.dy + 11)
      ..lineTo(bottomOuter.dx + 3, bottomOuter.dy - 46)
      ..lineTo(hingeBottom.dx - 6, hingeBottom.dy - 44)
      ..close();
    canvas.drawPath(glass, Paint()..color = const Color(0xFF8AB7CC));
    canvas.drawPath(
      glass,
      Paint()
        ..color = const Color(0xFFDAF4FB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    if (t > .15) {
      final x = bottomOuter.dx * .63 + hingeBottom.dx * .37;
      final y = bottomOuter.dy * .63 + hingeBottom.dy * .37;
      canvas.drawLine(
        Offset(x - 10, y - 4),
        Offset(x + 10, y - 7),
        Paint()
          ..color = const Color(0xFF415F74)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DoorPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _RainPainter extends CustomPainter {
  final double progress;
  const _RainPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDEEEFF).withValues(alpha: .51)
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 68; i++) {
      final x = (i * 73.7 + progress * 155) % size.width;
      final y = (i * 127.3 + progress * size.height * 2.2) % size.height;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 6, y + 22),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ResultPainter extends CustomPainter {
  final Offset position;
  final bool success;
  const _ResultPainter({required this.position, required this.success});

  @override
  void paint(Canvas canvas, Size size) {
    final color = success ? culturaGreen : culturaRed;
    canvas.drawCircle(
      position,
      size.width * .13,
      Paint()..color = color.withValues(alpha: .23),
    );
    canvas.drawCircle(
      position,
      size.width * .105,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    final text = TextPainter(
      text: TextSpan(
        text: success ? '✓' : '!',
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawCircle(
      position,
      size.width * .06,
      Paint()..color = color,
    );
    text.paint(
      canvas,
      position - Offset(text.width / 2, text.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _ResultPainter oldDelegate) =>
      oldDelegate.position != position || oldDelegate.success != success;
}
