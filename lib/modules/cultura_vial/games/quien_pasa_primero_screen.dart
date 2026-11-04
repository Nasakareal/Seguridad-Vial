import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/cultura_vial_audio_service.dart';
import '../widgets/game_ui.dart';

const _assetRoot = 'assets/cultura_vial/quien_pasa/';
const _navy = Color(0xFF102D47);
const _slate = Color(0xFF5E7589);
const _canvasBg = Color(0xFFF1F6FB);

class QuienPasaPrimeroScreen extends StatefulWidget {
  const QuienPasaPrimeroScreen({super.key});

  @override
  State<QuienPasaPrimeroScreen> createState() => _QuienPasaPrimeroScreenState();
}

class _QuienPasaPrimeroScreenState extends State<QuienPasaPrimeroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _movement;
  int _level = 0;
  int _score = 0;
  int _mistakes = 0;
  int _solved = 0;
  bool _checked = false;
  bool _correct = false;
  bool _tutorial = true;
  late List<_RoadUser> _order;

  static const _puzzles = <_IntersectionPuzzle>[
    _IntersectionPuzzle(
      title: 'Giro y cruce peatonal',
      context: 'Un automóvil se prepara para girar a la derecha. Una persona comienza a cruzar la calle a la que ingresará.',
      rule: 'La persona que cruza tiene preferencia. El conductor espera hasta que el paso esté libre antes de girar.',
      image: 'escena_1.png',
      users: [
        _RoadUser(
          id: 'peaton', tag: 'A', label: 'Persona que cruza', detail: 'Ya inició el paso peatonal',
          sprite: 'peaton.png', color: culturaGreen, width: 77, height: 109,
          path: [
            _Waypoint(730, 311, math.pi),
            _Waypoint(730, 397, math.pi),
            _Waypoint(730, 489, math.pi),
            _Waypoint(730, 629, math.pi),
          ],
        ),
        _RoadUser(
          id: 'auto', tag: 'B', label: 'Automóvil que gira', detail: 'Espera para incorporarse',
          sprite: 'auto_azul.png', color: culturaBlue, width: 102, height: 150,
          path: [
            _Waypoint(577, 801, 0),
            _Waypoint(577, 660, 0),
            _Waypoint(576, 552, 0),
            _Waypoint(609, 519, math.pi / 4),
            _Waypoint(715, 516, math.pi / 2),
            _Waypoint(903, 516, math.pi / 2),
          ],
        ),
      ],
      solution: ['peaton', 'auto'],
    ),
    _IntersectionPuzzle(
      title: 'Preferencia en glorieta',
      context: 'Una moto va adelante de una bicicleta dentro de la glorieta. Un auto espera para incorporarse desde el acceso sur.',
      rule: 'El auto cede a quienes ya circulan en la glorieta. En este ejercicio, la moto pasa antes que la bicicleta porque va delante.',
      image: 'escena_2.png',
      users: [
        _RoadUser(
          id: 'moto', tag: 'A', label: 'Moto en circulación', detail: 'Va adelante dentro de la glorieta',
          sprite: 'moto.png', color: culturaRed, width: 79, height: 122,
          path: [
            _Waypoint(680, 302, -.62),
            _Waypoint(614, 244, -.99),
            _Waypoint(518, 218, -1.50),
            _Waypoint(413, 236, -2.00),
            _Waypoint(312, 310, -2.40),
          ],
        ),
        _RoadUser(
          id: 'bici', tag: 'B', label: 'Bicicleta en la glorieta', detail: 'Circula detrás de la moto',
          sprite: 'bici.png', color: culturaGreen, width: 72, height: 113,
          path: [
            _Waypoint(718, 500, -.15),
            _Waypoint(716, 395, -.28),
            _Waypoint(667, 309, -.68),
            _Waypoint(572, 242, -1.24),
            _Waypoint(468, 221, -1.66),
          ],
        ),
        _RoadUser(
          id: 'auto', tag: 'C', label: 'Auto que se incorpora', detail: 'Tiene señalamiento CEDA',
          sprite: 'auto_amarillo.png', color: culturaBlue, width: 99, height: 150,
          path: [
            _Waypoint(556, 815, 0),
            _Waypoint(556, 736, 0),
            _Waypoint(596, 648, .42),
            _Waypoint(678, 587, .42),
            _Waypoint(730, 497, -.03),
            _Waypoint(840, 509, math.pi / 2),
            _Waypoint(956, 509, math.pi / 2),
          ],
        ),
      ],
      solution: ['moto', 'bici', 'auto'],
    ),
    _IntersectionPuzzle(
      title: 'Paso de emergencia',
      context: 'Se acerca una ambulancia con señales activas. Una persona espera para cruzar y un auto permanece detenido.',
      rule: 'Se facilita el paso de la ambulancia sin generar otro riesgo. Cuando ha pasado, la persona puede cruzar y el auto espera.',
      image: 'escena_3.png',
      users: [
        _RoadUser(
          id: 'ambulancia', tag: 'A', label: 'Ambulancia con sirena', detail: 'Se aproxima por la izquierda',
          sprite: 'ambulancia.png', color: culturaRed, width: 109, height: 161,
          path: [
            _Waypoint(99, 510, math.pi / 2),
            _Waypoint(278, 510, math.pi / 2),
            _Waypoint(494, 510, math.pi / 2),
            _Waypoint(728, 510, math.pi / 2),
            _Waypoint(944, 510, math.pi / 2),
          ],
        ),
        _RoadUser(
          id: 'peaton', tag: 'B', label: 'Persona que espera', detail: 'Cruza después de la ambulancia',
          sprite: 'peaton.png', color: culturaGreen, width: 77, height: 109,
          path: [
            _Waypoint(735, 311, math.pi),
            _Waypoint(735, 406, math.pi),
            _Waypoint(735, 521, math.pi),
            _Waypoint(735, 631, math.pi),
          ],
        ),
        _RoadUser(
          id: 'auto', tag: 'C', label: 'Automóvil detenido', detail: 'Espera su oportunidad de girar',
          sprite: 'auto_turquesa.png', color: culturaBlue, width: 100, height: 151,
          path: [
            _Waypoint(567, 800, 0),
            _Waypoint(567, 663, 0),
            _Waypoint(567, 551, 0),
            _Waypoint(612, 521, math.pi / 4),
            _Waypoint(727, 520, math.pi / 2),
            _Waypoint(927, 520, math.pi / 2),
          ],
        ),
      ],
      solution: ['ambulancia', 'peaton', 'auto'],
    ),
    _IntersectionPuzzle(
      title: 'Cruce con giro pendiente',
      context: 'La bicicleta ya entra al cruce desde la derecha. Después llega el auto que sigue recto. La moto espera para girar.',
      rule: 'Aquí la bicicleta ya inició el cruce; después pasa el auto recto y por último gira la moto. En la calle real revisa señalamiento, posiciones y llegada.',
      image: 'escena_4.png',
      users: [
        _RoadUser(
          id: 'bici', tag: 'A', label: 'Bicicleta a la derecha', detail: 'Ya está entrando al cruce',
          sprite: 'bici.png', color: culturaGreen, width: 76, height: 118,
          path: [
            _Waypoint(747, 351, -math.pi / 2),
            _Waypoint(631, 351, -math.pi / 2),
            _Waypoint(480, 351, -math.pi / 2),
            _Waypoint(336, 351, -math.pi / 2),
            _Waypoint(187, 351, -math.pi / 2),
          ],
        ),
        _RoadUser(
          id: 'auto_norte', tag: 'B', label: 'Auto que sigue recto', detail: 'Circula hacia el sur',
          sprite: 'auto_azul.png', color: culturaBlue, width: 103, height: 151,
          path: [
            _Waypoint(421, 112, math.pi),
            _Waypoint(421, 270, math.pi),
            _Waypoint(421, 431, math.pi),
            _Waypoint(421, 605, math.pi),
            _Waypoint(421, 792, math.pi),
          ],
        ),
        _RoadUser(
          id: 'moto_giro', tag: 'C', label: 'Moto que espera para girar', detail: 'No debe atravesarse',
          sprite: 'moto.png', color: culturaRed, width: 76, height: 125,
          path: [
            _Waypoint(578, 814, 0),
            _Waypoint(578, 652, 0),
            _Waypoint(577, 560, 0),
            _Waypoint(610, 514, math.pi / 4),
            _Waypoint(712, 512, math.pi / 2),
            _Waypoint(920, 512, math.pi / 2),
          ],
        ),
      ],
      solution: ['bici', 'auto_norte', 'moto_giro'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _movement = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5100),
    );
    _loadPuzzle();
  }

  void _loadPuzzle() {
    _order = List<_RoadUser>.of(_puzzles[_level].users)
      ..shuffle(math.Random(_level + 7));
    if (_order.map((u) => u.id).join('|') ==
        _puzzles[_level].solution.join('|')) {
      _order = _order.reversed.toList();
    }
  }

  @override
  void dispose() {
    _movement.dispose();
    super.dispose();
  }

  void _moveItem(int oldIndex, int newIndex) {
    if (_checked || oldIndex == newIndex || newIndex < 0 ||
        newIndex >= _order.length) {
      return;
    }
    setState(() {
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
    CulturaVialAudioService.instance.playEffect(CulturaVialSound.tap);
  }

  void _check() {
    if (_checked) return;
    final solution = _puzzles[_level].solution;
    final correct = _order.asMap().entries.every(
      (entry) => entry.value.id == solution[entry.key],
    );
    setState(() {
      _checked = true;
      _correct = correct;
      if (correct) {
        _solved++;
        _score += 300 + math.max(0, 120 - _mistakes * 15);
      } else {
        _mistakes++;
      }
    });
    _movement.forward(from: 0);
    CulturaVialAudioService.instance.playEffect(
      correct ? CulturaVialSound.correct : CulturaVialSound.wrong,
    );
  }

  void _retry() {
    if (!_checked || _correct) return;
    setState(() {
      _checked = false;
      _correct = false;
    });
    _movement.reset();
  }

  void _next() {
    if (!_checked || !_correct) return;
    if (_level + 1 >= _puzzles.length) {
      _finish();
      return;
    }
    _movement.reset();
    setState(() {
      _level++;
      _checked = false;
      _correct = false;
      _loadPuzzle();
    });
  }

  void _finish() {
    final stars = _solved == _puzzles.length && _mistakes == 0
        ? 3
        : _solved >= 3
            ? 2
            : 1;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameResultScreen(
          gameId: 'quien_pasa',
          title: '¿Quién pasa primero?',
          score: _score,
          correct: _solved,
          mistakes: _mistakes,
          stars: stars,
          intersections: _solved,
          onReplay: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const QuienPasaPrimeroScreen(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = _puzzles[_level];
    return CulturaVialGameScaffold(
      title: '¿Quién pasa primero?',
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
          Container(
            color: _canvasBg,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 820;
                return Column(
                  children: [
                    _header(puzzle),
                    Expanded(
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 10, 24),
                                    child: _scene(puzzle),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(8, 12, 18, 24),
                                    child: _orderPanel(puzzle),
                                  ),
                                ),
                              ],
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                              child: Column(
                                children: [
                                  _scene(puzzle),
                                  const SizedBox(height: 14),
                                  _orderPanel(puzzle),
                                ],
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_tutorial) _tutorialOverlay(),
        ],
      ),
    );
  }

  Widget _header(_IntersectionPuzzle puzzle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0E9F1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'CRUCE ${(_level + 1).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: culturaBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .6,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.shield_outlined, color: culturaGreen, size: 18),
              const SizedBox(width: 5),
              Text(
                '$_solved resueltos',
                style: const TextStyle(
                  color: _slate,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '${_level + 1} / ${_puzzles.length}',
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_level + 1) / _puzzles.length,
              minHeight: 7,
              backgroundColor: const Color(0xFFE1EBF3),
              color: culturaBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            puzzle.title,
            style: const TextStyle(
              color: _navy,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            puzzle.context,
            style: const TextStyle(color: _slate, fontSize: 13, height: 1.32),
          ),
        ],
      ),
    );
  }

  Widget _scene(_IntersectionPuzzle puzzle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _navy,
            borderRadius: BorderRadius.circular(23),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1C123A56),
                offset: Offset(0, 7),
                blurRadius: 15,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: AspectRatio(
              aspectRatio: 1000 / 880,
              child: AnimatedBuilder(
                animation: _movement,
                builder: (context, child) {
                  return FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 1000,
                      height: 880,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              '$_assetRoot${puzzle.image}',
                              fit: BoxFit.fill,
                            ),
                          ),
                          for (final user in puzzle.users)
                            _actorOnMap(user, puzzle),
                          Positioned(
                            top: 20,
                            left: 20,
                            child: _sceneTag(
                              Icons.map_outlined,
                              'VISTA AÉREA',
                            ),
                          ),
                          if (_checked)
                            Positioned(
                              top: 20,
                              right: 20,
                              child: _sceneTag(
                                _correct ? Icons.check_circle : Icons.warning_amber_rounded,
                                _correct ? 'ORDEN CORRECTO' : 'REVISA EL ORDEN',
                                color: _correct ? const Color(0xFF096E50) : const Color(0xFF923F2D),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        const Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 17, color: _slate),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Las letras del mapa corresponden a las fichas. No indican prioridad.',
                style: TextStyle(fontSize: 12, color: _slate),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sceneTag(IconData icon, String label, {Color color = _navy}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .93),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: .4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actorOnMap(_RoadUser user, _IntersectionPuzzle puzzle) {
    final index = _order.indexWhere((candidate) => candidate.id == user.id);
    final local = _checked && _correct
        ? (_movement.value * _order.length - index).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final pose = user.poseAt(local);
    final active = _checked && _correct &&
        local > 0 && local < 1;
    final pulse = _checked && !_correct
        ? (math.sin(_movement.value * math.pi * 5).abs() * .5 + .3)
        : 0.0;
    return Positioned(
      left: pose.x - user.width / 2 - 12,
      top: pose.y - user.height / 2 - 15,
      width: user.width + 48,
      height: user.height + 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (active || pulse > 0)
            Positioned(
              top: 3,
              left: 0,
              width: user.width + 43,
              height: user.height + 39,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active
                        ? const Color(0xFF16B77C)
                        : culturaRed.withValues(alpha: pulse),
                    width: active ? 7 : 5,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 12,
            top: 15,
            width: user.width,
            height: user.height,
            child: Transform.rotate(
              angle: pose.heading,
              child: Image.asset(
                '$_assetRoot${user.sprite}',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            left: user.width * .66,
            top: 0,
            child: Container(
              width: 45,
              height: 45,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: user.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: const [
                  BoxShadow(color: Color(0x540D3047), blurRadius: 7),
                ],
              ),
              child: Text(
                user.tag,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderPanel(_IntersectionPuzzle puzzle) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFDDE9F3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D103A59),
            offset: Offset(0, 3),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.route_rounded, color: culturaBlue, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ELIGE EL ORDEN DE PASO',
                  style: TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .3,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Arrastra desde el asa o usa las flechas para reordenar.',
            style: TextStyle(fontSize: 12, color: _slate),
          ),
          const SizedBox(height: 12),
          ReorderableListView.builder(
            itemCount: _order.length,
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              if (_checked) return;
              if (newIndex > oldIndex) newIndex--;
              _moveItem(oldIndex, newIndex);
            },
            proxyDecorator: (child, index, animation) => Material(
              elevation: 10,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              child: child,
            ),
            itemBuilder: (context, index) {
              final user = _order[index];
              final right = _checked &&
                  user.id == puzzle.solution[index];
              final borderColor = _checked
                  ? right ? culturaGreen : culturaRed
                  : const Color(0xFFDCE8F1);
              return Container(
                key: ValueKey(user.id),
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.fromLTRB(8, 7, 7, 7),
                decoration: BoxDecoration(
                  color: right && _checked
                      ? const Color(0xFFEAF9F0)
                      : const Color(0xFFF8FBFE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor,
                    width: _checked ? 2 : 1.3,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 31,
                      height: 39,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _navy,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 33,
                      height: 33,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: user.color.withValues(alpha: .13),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        user.tag,
                        style: TextStyle(
                          color: user.color,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: _navy,
                            ),
                          ),
                          Text(
                            user.detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_checked)
                      Icon(
                        right ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: right ? culturaGreen : culturaRed,
                        size: 23,
                      )
                    else ...[
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _reorderButton(
                            Icons.keyboard_arrow_up_rounded,
                            index > 0 ? () => _moveItem(index, index - 1) : null,
                          ),
                          _reorderButton(
                            Icons.keyboard_arrow_down_rounded,
                            index < _order.length - 1
                                ? () => _moveItem(index, index + 1)
                                : null,
                          ),
                        ],
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: _slate,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          if (_checked) ...[
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _correct
                    ? const Color(0xFFE9F8F0)
                    : const Color(0xFFFFF0EB),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _correct
                            ? Icons.verified_rounded
                            : Icons.warning_amber_rounded,
                        color: _correct ? culturaGreen : culturaRed,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _correct
                              ? '¡Cruce resuelto!'
                              : 'Todavía hay un conflicto',
                          style: TextStyle(
                            color: _correct ? const Color(0xFF16865A) : culturaRed,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _correct
                        ? puzzle.rule
                        : 'Revisa quién ya está circulando, quién espera y quién debe ceder. Cambia el orden e inténtalo otra vez.',
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: GamePressable(
              onPressed: !_checked ? _check : _correct ? _next : _retry,
              color: _checked && !_correct ? culturaRed : culturaBlue,
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    !_checked
                        ? Icons.play_arrow_rounded
                        : _correct
                            ? Icons.arrow_forward_rounded
                            : Icons.replay_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      !_checked
                          ? 'Comprobar y ver el cruce'
                          : _correct
                              ? (_level + 1 == _puzzles.length
                                  ? 'Ver resultado'
                                  : 'Siguiente cruce')
                              : 'Reordenar e intentar otra vez',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reorderButton(IconData icon, VoidCallback? action) {
    return SizedBox(
      width: 27,
      height: 27,
      child: IconButton(
        onPressed: action,
        icon: Icon(icon, size: 22),
        color: culturaBlue,
        disabledColor: const Color(0xFFB9C8D2),
        tooltip: icon == Icons.keyboard_arrow_up_rounded ? 'Subir' : 'Bajar',
        constraints: const BoxConstraints(minWidth: 27, minHeight: 27),
        padding: EdgeInsets.zero,
        splashRadius: 15,
      ),
    );
  }

  Widget _tutorialOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xEA0B2136),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(23),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 425),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 103,
                  height: 103,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E4D71),
                    borderRadius: BorderRadius.circular(31),
                    border: Border.all(color: const Color(0xFF88D5E2), width: 2),
                  ),
                  child: const Icon(
                    Icons.alt_route_rounded,
                    size: 57,
                    color: culturaYellow,
                  ),
                ),
                const SizedBox(height: 21),
                const Text(
                  '¡TÚ CONTROLAS EL CRUCE!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    height: 1.16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 13),
                const Text(
                  'Observa el mapa, lee la situación y ordena quién debe pasar primero. Las fichas se arrastran y también tienen flechas.',
                  style: TextStyle(
                    color: Color(0xFFDCEBF4),
                    fontSize: 15,
                    height: 1.48,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 11),
                const Text(
                  'Si aciertas, verás cómo atraviesan el cruce en el orden correcto.',
                  style: TextStyle(
                    color: Color(0xFF88DEB8),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: 270,
                  child: GamePressable(
                    onPressed: () => setState(() => _tutorial = false),
                    color: culturaGreen,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: const Text('¡Comenzar misión!'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Waypoint {
  final double x;
  final double y;
  final double heading;
  const _Waypoint(this.x, this.y, this.heading);
}

class _RoadUser {
  final String id;
  final String tag;
  final String label;
  final String detail;
  final String sprite;
  final Color color;
  final double width;
  final double height;
  final List<_Waypoint> path;

  const _RoadUser({
    required this.id,
    required this.tag,
    required this.label,
    required this.detail,
    required this.sprite,
    required this.color,
    required this.width,
    required this.height,
    required this.path,
  });

  _Waypoint poseAt(double progress) {
    if (progress <= 0) return path.first;
    if (progress >= 1) return path.last;
    final step = progress * (path.length - 1);
    final index = step.floor().clamp(0, path.length - 2).toInt();
    final u = step - index;
    final a = path[index];
    final b = path[index + 1];
    final before = path[math.max(0, index - 1)];
    final after = path[math.min(path.length - 1, index + 2)];
    double catmull(double p0, double p1, double p2, double p3) {
      final t2 = u * u;
      final t3 = t2 * u;
      return .5 * ((2 * p1) + (-p0 + p2) * u +
          (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
          (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
    }
    var delta = b.heading - a.heading;
    while (delta > math.pi) { delta -= math.pi * 2; }
    while (delta < -math.pi) { delta += math.pi * 2; }
    final smooth = u * u * (3 - 2 * u);
    return _Waypoint(
      catmull(before.x, a.x, b.x, after.x),
      catmull(before.y, a.y, b.y, after.y),
      a.heading + delta * smooth,
    );
  }
}

class _IntersectionPuzzle {
  final String title;
  final String context;
  final String rule;
  final String image;
  final List<_RoadUser> users;
  final List<String> solution;

  const _IntersectionPuzzle({
    required this.title,
    required this.context,
    required this.rule,
    required this.image,
    required this.users,
    required this.solution,
  });
}
