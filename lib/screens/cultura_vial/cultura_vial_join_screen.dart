import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/cultura_vial.dart';
import '../../services/cultura_vial_service.dart';
import '../../services/local_draft_service.dart';

class CulturaVialJoinScreen extends StatefulWidget {
  const CulturaVialJoinScreen({super.key});

  @override
  State<CulturaVialJoinScreen> createState() => _CulturaVialJoinScreenState();
}

class _CulturaVialJoinScreenState extends State<CulturaVialJoinScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _joining = false;
  late final LocalDraftAutosave _draft;

  @override
  void initState() {
    super.initState();
    _draft = LocalDraftAutosave(
      draftId: 'cultura_vial:join',
      collect: _draftValues,
    )..attachTextControllers({'nombre': _nameCtrl, 'codigo': _codeCtrl});
    unawaited(_restoreLocalDraft());
  }

  @override
  void dispose() {
    _draft.dispose();
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _draftValues() {
    return <String, dynamic>{
      'nombre': _nameCtrl.text,
      'codigo': _codeCtrl.text,
    };
  }

  Future<void> _restoreLocalDraft() async {
    final restored = await _draft.restore((draft) {
      _nameCtrl.text = (draft['nombre'] ?? '').toString();
      _codeCtrl.text = (draft['codigo'] ?? '').toString();
    });
    if (!mounted || !restored) return;
    setState(() {});
  }

  Future<void> _scan() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _CulturaVialScannerScreen()),
    );
    if (raw == null || !mounted) return;
    _codeCtrl.text = CulturaVialService.parseJoinCode(raw);
    _draft.notifyChanged();
  }

  Future<void> _join() async {
    if (_joining) return;
    final nombre = _nameCtrl.text.trim();
    final code = CulturaVialService.parseJoinCode(_codeCtrl.text);

    if (nombre.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captura tu nombre y el código de sala.')),
      );
      return;
    }

    setState(() => _joining = true);
    try {
      final joined = await CulturaVialService.joinSala(
        code: code,
        nombre: nombre,
      );
      if (!mounted) return;
      await _draft.discard();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CulturaVialGameScreen(joinResult: joined),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CulturaVialService.cleanExceptionMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2FE),
      appBar: AppBar(
        title: const Text('Entrar a juego vial'),
        backgroundColor: const Color(0xFF0369A1),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE047),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: Color(0xFF075985),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Misión Ciudad Segura',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Tu nombre',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Código de sala',
                      prefixIcon: const Icon(Icons.qr_code_2),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: 'Escanear QR',
                        onPressed: _scan,
                        icon: const Icon(Icons.camera_alt),
                      ),
                    ),
                    onSubmitted: (_) => _join(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _joining ? null : _scan,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Escanear'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _joining ? null : _join,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: _joining
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.play_arrow),
                          label: Text(_joining ? 'Entrando...' : 'Jugar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _PreviewPanel(),
          ],
        ),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(
          painter: const _CityRoadPainter(
            progress: .25,
            lane: 1,
            scene: _RoadScene.crosswalk,
            accent: Color(0xFF22C55E),
          ),
          child: const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 18),
              child: Text(
                'Elige seguro. Suma puntos.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CulturaVialScannerScreen extends StatefulWidget {
  const _CulturaVialScannerScreen();

  @override
  State<_CulturaVialScannerScreen> createState() =>
      _CulturaVialScannerScreenState();
}

class _CulturaVialScannerScreenState extends State<_CulturaVialScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoZoom: true,
  );

  bool _handled = false;

  void _handleDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? '';
      if (raw.isEmpty) continue;
      _handled = true;
      unawaited(_controller.stop());
      if (!mounted) return;
      Navigator.pop(context, raw);
      return;
    }
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear sala'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Cambiar cámara',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No se pudo iniciar la cámara.\n\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CulturaVialGameScreen extends StatefulWidget {
  final CulturaVialJoinResult joinResult;

  const CulturaVialGameScreen({super.key, required this.joinResult});

  @override
  State<CulturaVialGameScreen> createState() => _CulturaVialGameScreenState();
}

class _CulturaVialGameScreenState extends State<CulturaVialGameScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roadController;
  final DateTime _startedAt = DateTime.now();
  final List<Map<String, dynamic>> _decisions = <Map<String, dynamic>>[];

  int _questionIndex = 0;
  int _lane = 1;
  int? _selected;
  int _score = 0;
  int _correct = 0;
  int _wrong = 0;
  int _streak = 0;
  bool _answered = false;
  bool _finished = false;
  bool _submitting = false;
  String? _submitError;

  static const List<_GameQuestion> _questions = <_GameQuestion>[
    _GameQuestion(
      badge: 'Cruce peatonal',
      icon: Icons.directions_walk,
      accent: Color(0xFF22C55E),
      scene: _RoadScene.crosswalk,
      prompt: 'Un peatón espera en el cruce.',
      choices: [
        _GameChoice('Paso rápido', Icons.flash_on),
        _GameChoice('Cedo el paso', Icons.pan_tool),
        _GameChoice('Toco claxon', Icons.volume_up),
      ],
      correctIndex: 1,
      feedback: 'Ceder el paso protege a quien cruza.',
    ),
    _GameQuestion(
      badge: 'Semáforo',
      icon: Icons.traffic,
      accent: Color(0xFFF59E0B),
      scene: _RoadScene.trafficLight,
      prompt: 'El semáforo cambia a amarillo.',
      choices: [
        _GameChoice('Acelero', Icons.speed),
        _GameChoice('Freno con cuidado', Icons.back_hand),
        _GameChoice('Cambio de carril', Icons.swap_horiz),
      ],
      correctIndex: 1,
      feedback: 'Amarillo significa prepararse para detenerse.',
    ),
    _GameQuestion(
      badge: 'Sorpresa en la calle',
      icon: Icons.sports_soccer,
      accent: Color(0xFFEF4444),
      scene: _RoadScene.ball,
      prompt: 'Una pelota rueda hacia la calle.',
      choices: [
        _GameChoice('Bajo velocidad', Icons.speed),
        _GameChoice('La esquivo fuerte', Icons.turn_sharp_right),
        _GameChoice('Sigo igual', Icons.arrow_upward),
      ],
      correctIndex: 0,
      feedback: 'Una pelota puede venir seguida de un niño.',
    ),
    _GameQuestion(
      badge: 'Señal de alto',
      icon: Icons.report,
      accent: Color(0xFFDC2626),
      scene: _RoadScene.stopSign,
      prompt: 'Aparece una señal de ALTO.',
      choices: [
        _GameChoice('Alto total', Icons.do_not_disturb_on),
        _GameChoice('Solo bajo tantito', Icons.remove_circle_outline),
        _GameChoice('Me pego al de adelante', Icons.car_crash),
      ],
      correctIndex: 0,
      feedback: 'Alto total: mirar, esperar y avanzar seguro.',
    ),
    _GameQuestion(
      badge: 'Antes de salir',
      icon: Icons.event_seat,
      accent: Color(0xFF0EA5E9),
      scene: _RoadScene.seatbelt,
      prompt: 'Antes de arrancar el auto.',
      choices: [
        _GameChoice('Música fuerte', Icons.music_note),
        _GameChoice('Cinturón puesto', Icons.check_circle),
        _GameChoice('Celular en mano', Icons.phone_android),
      ],
      correctIndex: 1,
      feedback: 'El cinturón salva vidas en cada viaje.',
    ),
    _GameQuestion(
      badge: 'Distracción',
      icon: Icons.phone_android,
      accent: Color(0xFF8B5CF6),
      scene: _RoadScene.phone,
      prompt: 'Suena el celular mientras manejas.',
      choices: [
        _GameChoice('Lo reviso', Icons.visibility),
        _GameChoice('Lo ignoro', Icons.notifications_off),
        _GameChoice('Contesto rápido', Icons.call),
      ],
      correctIndex: 1,
      feedback: 'La atención se queda en el camino.',
    ),
    _GameQuestion(
      badge: 'Zona escolar',
      icon: Icons.school,
      accent: Color(0xFFF97316),
      scene: _RoadScene.school,
      prompt: 'Ves una escuela y niños cerca de la banqueta.',
      choices: [
        _GameChoice('Bajo velocidad', Icons.speed),
        _GameChoice('Acelero para pasar', Icons.flash_on),
        _GameChoice('Uso el celular', Icons.phone_android),
      ],
      correctIndex: 0,
      feedback: 'En zona escolar se maneja lento y atento.',
    ),
    _GameQuestion(
      badge: 'Lluvia',
      icon: Icons.water_drop,
      accent: Color(0xFF2563EB),
      scene: _RoadScene.rain,
      prompt: 'Empieza a llover y el pavimento está resbaloso.',
      choices: [
        _GameChoice('Guardo distancia', Icons.social_distance),
        _GameChoice('Freno de golpe', Icons.dangerous),
        _GameChoice('Corro más', Icons.speed),
      ],
      correctIndex: 0,
      feedback: 'Con lluvia conviene más espacio para frenar.',
    ),
    _GameQuestion(
      badge: 'Emergencia',
      icon: Icons.local_hospital,
      accent: Color(0xFF06B6D4),
      scene: _RoadScene.ambulance,
      prompt: 'Escuchas una ambulancia detrás de ti.',
      choices: [
        _GameChoice('Compito con ella', Icons.sports_score),
        _GameChoice('Me orillo seguro', Icons.arrow_circle_right),
        _GameChoice('Me detengo en medio', Icons.block),
      ],
      correctIndex: 1,
      feedback: 'Hay que abrir paso sin poner a otros en riesgo.',
    ),
    _GameQuestion(
      badge: 'Bicicleta',
      icon: Icons.directions_bike,
      accent: Color(0xFF14B8A6),
      scene: _RoadScene.bicycle,
      prompt: 'Un ciclista va adelante de tu carril.',
      choices: [
        _GameChoice('Lo presiono', Icons.warning),
        _GameChoice('Le doy espacio', Icons.open_with),
        _GameChoice('Paso pegado', Icons.compare_arrows),
      ],
      correctIndex: 1,
      feedback: 'Un ciclista necesita distancia lateral segura.',
    ),
    _GameQuestion(
      badge: 'De noche',
      icon: Icons.nightlight_round,
      accent: Color(0xFF6366F1),
      scene: _RoadScene.night,
      prompt: 'Manejas de noche por una calle poco iluminada.',
      choices: [
        _GameChoice('Prendo luces', Icons.lightbulb),
        _GameChoice('Apago todo', Icons.lightbulb_outline),
        _GameChoice('Miro el celular', Icons.phone_android),
      ],
      correctIndex: 0,
      feedback: 'Las luces ayudan a ver y a que te vean.',
    ),
    _GameQuestion(
      badge: 'Transporte público',
      icon: Icons.directions_bus,
      accent: Color(0xFFEAB308),
      scene: _RoadScene.busStop,
      prompt: 'Un camión se detiene para subir pasajeros.',
      choices: [
        _GameChoice('Paso con cuidado', Icons.visibility),
        _GameChoice('Rebaso sin mirar', Icons.fast_forward),
        _GameChoice('Toco claxon', Icons.volume_up),
      ],
      correctIndex: 0,
      feedback: 'Puede bajar gente: mira, baja velocidad y pasa seguro.',
    ),
    _GameQuestion(
      badge: 'Obras',
      icon: Icons.construction,
      accent: Color(0xFFF97316),
      scene: _RoadScene.construction,
      prompt: 'Hay conos y trabajadores arreglando la calle.',
      choices: [
        _GameChoice('Paso lento', Icons.speed),
        _GameChoice('Invado los conos', Icons.change_circle),
        _GameChoice('Acelero', Icons.flash_on),
      ],
      correctIndex: 0,
      feedback: 'En obras se respeta el carril y se reduce velocidad.',
    ),
    _GameQuestion(
      badge: 'Vía del tren',
      icon: Icons.train,
      accent: Color(0xFFA855F7),
      scene: _RoadScene.railroad,
      prompt: 'La barrera del tren empieza a bajar.',
      choices: [
        _GameChoice('Cruzo rápido', Icons.bolt),
        _GameChoice('Me detengo', Icons.do_not_disturb_on),
        _GameChoice('Rodeo la barrera', Icons.u_turn_left),
      ],
      correctIndex: 1,
      feedback: 'Nunca se cruza con la barrera bajando.',
    ),
    _GameQuestion(
      badge: 'Velocidad',
      icon: Icons.speed,
      accent: Color(0xFF10B981),
      scene: _RoadScene.speedLimit,
      prompt: 'La señal marca límite de 30 km/h.',
      choices: [
        _GameChoice('Respeto el límite', Icons.check_circle),
        _GameChoice('Voy a 60', Icons.rocket_launch),
        _GameChoice('Me distraigo', Icons.phone_android),
      ],
      correctIndex: 0,
      feedback: 'El límite ayuda a reaccionar a tiempo.',
    ),
    _GameQuestion(
      badge: 'Agente vial',
      icon: Icons.badge,
      accent: Color(0xFF0EA5E9),
      scene: _RoadScene.officer,
      prompt: 'Un agente vial te indica detenerte.',
      choices: [
        _GameChoice('Obedezco', Icons.pan_tool),
        _GameChoice('Lo ignoro', Icons.visibility_off),
        _GameChoice('Acelero', Icons.speed),
      ],
      correctIndex: 0,
      feedback: 'Las indicaciones del agente ayudan a ordenar el camino.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _roadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _roadController.dispose();
    super.dispose();
  }

  Future<void> _answer(int index) async {
    if (_answered || _finished) return;
    final question = _questions[_questionIndex];
    final isCorrect = index == question.correctIndex;
    final nextStreak = isCorrect ? _streak + 1 : 0;
    final earned = isCorrect ? 100 + math.min(nextStreak, 4) * 20 : 0;

    setState(() {
      _selected = index;
      _lane = index;
      _answered = true;
      if (isCorrect) {
        _score += earned;
        _correct += 1;
      } else {
        _wrong += 1;
      }
      _streak = nextStreak;
      _decisions.add(<String, dynamic>{
        'pregunta': question.prompt,
        'respuesta': question.choices[index].label,
        'correcta': question.choices[question.correctIndex].label,
        'acierto': isCorrect,
        'puntos': earned,
      });
    });

    await Future<void>.delayed(const Duration(milliseconds: 1250));
    if (!mounted) return;

    if (_questionIndex == _questions.length - 1) {
      await _finish();
      return;
    }

    setState(() {
      _questionIndex += 1;
      _selected = null;
      _answered = false;
    });
  }

  Future<void> _finish() async {
    final perfectBonus = _wrong == 0 ? 250 : 0;
    setState(() {
      _score += perfectBonus;
      _finished = true;
      _submitting = true;
      _submitError = null;
    });

    try {
      await CulturaVialService.submitAttempt(
        participanteId: widget.joinResult.participante.id,
        joinToken: widget.joinResult.participante.joinToken,
        puntaje: _score,
        aciertos: _correct,
        errores: _wrong,
        duracionSegundos: DateTime.now().difference(_startedAt).inSeconds,
        decisiones: _decisions,
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _submitError = CulturaVialService.cleanExceptionMessage(e),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Color _choiceColor(int index, _GameQuestion question) {
    if (!_answered) return Colors.white;
    if (index == question.correctIndex) return const Color(0xFFDCFCE7);
    if (index == _selected) return const Color(0xFFFEE2E2);
    return Colors.white;
  }

  Widget _choiceButton(int index, _GameQuestion question) {
    final choice = question.choices[index];
    final isSelected = _selected == index;
    final isCorrect = _answered && index == question.correctIndex;
    final isWrong = _answered && isSelected && !isCorrect;
    final icon = isCorrect
        ? Icons.check_circle
        : isWrong
        ? Icons.cancel
        : choice.icon;
    final iconColor = isCorrect
        ? const Color(0xFF15803D)
        : isWrong
        ? const Color(0xFFDC2626)
        : question.accent;

    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: isSelected ? 1.025 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 58),
        margin: EdgeInsets.only(top: index == 0 ? 0 : 8),
        decoration: BoxDecoration(
          color: _choiceColor(index, question),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCorrect
                ? const Color(0xFF22C55E)
                : isWrong
                ? const Color(0xFFEF4444)
                : isSelected
                ? question.accent
                : Colors.black12,
            width: isSelected || isCorrect ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .12),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _answered ? null : () => _answer(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: .14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      choice.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameBody() {
    final question = _questions[_questionIndex];
    final progressValue =
        (_questionIndex + (_answered ? 1 : 0)) / _questions.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 710;

        return AnimatedBuilder(
          animation: _roadController,
          builder: (context, _) {
            return CustomPaint(
              painter: _CityRoadPainter(
                progress: _roadController.value,
                lane: _lane,
                scene: question.scene,
                accent: question.accent,
                successPulse: _answered && _selected == question.correctIndex,
                dangerPulse: _answered && _selected != question.correctIndex,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _ScoreChip(
                            icon: Icons.star,
                            label: '$_score',
                            color: const Color(0xFFFDE047),
                          ),
                          const SizedBox(width: 8),
                          _ScoreChip(
                            icon: Icons.done,
                            label: '$_correct',
                            color: const Color(0xFF86EFAC),
                          ),
                          if (_streak > 1) ...[
                            const SizedBox(width: 8),
                            _ScoreChip(
                              icon: Icons.bolt,
                              label: 'x$_streak',
                              color: const Color(0xFFFCA5A5),
                            ),
                          ],
                          const Spacer(),
                          _ScoreChip(
                            icon: Icons.flag,
                            label: '${_questionIndex + 1}/${_questions.length}',
                            color: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _ProgressTrack(
                        value: progressValue,
                        accent: question.accent,
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _FloatingMissionBadge(
                              key: ValueKey(question.badge),
                              question: question,
                              answered: _answered,
                              correct: _selected == question.correctIndex,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(compact ? 12 : 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .94),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .75),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .22),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: question.accent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    question.icon,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        question.badge,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: question.accent,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        question.prompt,
                                        maxLines: compact ? 2 : 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          height: 1.08,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _answered
                                  ? Container(
                                      key: const ValueKey('feedback'),
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(top: 10),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (_selected == question.correctIndex
                                                    ? const Color(0xFFEFFDF5)
                                                    : const Color(0xFFFFF1F2))
                                                .withValues(alpha: .98),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _selected == question.correctIndex
                                                ? Icons.sentiment_very_satisfied
                                                : Icons.tips_and_updates,
                                            color:
                                                _selected ==
                                                    question.correctIndex
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFFE11D48),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              question.feedback,
                                              style: const TextStyle(
                                                color: Color(0xFF0F172A),
                                                fontWeight: FontWeight.w800,
                                                height: 1.15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('no-feedback'),
                                    ),
                            ),
                            const SizedBox(height: 10),
                            _choiceButton(0, question),
                            _choiceButton(1, question),
                            _choiceButton(2, question),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _finishBody() {
    final starCount = _wrong == 0
        ? 3
        : _correct >= (_questions.length * .72).ceil()
        ? 2
        : 1;

    return CustomPaint(
      foregroundPainter: _CelebrationPainter(stars: starCount),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF0E7490), Color(0xFF22C55E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .28),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFDE047),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Color(0xFF0F172A),
                        size: 58,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _StarRow(count: starCount),
                    const SizedBox(height: 12),
                    Text(
                      widget.joinResult.participante.nombre,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Piloto vial en entrenamiento',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF0F766E),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_score puntos',
                      style: const TextStyle(
                        color: Color(0xFFEA580C),
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Aciertos: $_correct de ${_questions.length} | Errores: $_wrong',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_submitting)
                      const CircularProgressIndicator(color: Color(0xFF0E7490))
                    else if (_submitError != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _submitError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      )
                    else
                      const Text(
                        'Puntaje guardado en la sala.',
                        style: TextStyle(
                          color: Color(0xFF0F766E),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Terminar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PopScope(
        canPop: _finished,
        child: _finished ? _finishBody() : _gameBody(),
      ),
    );
  }
}

enum _RoadScene {
  crosswalk,
  trafficLight,
  ball,
  stopSign,
  seatbelt,
  phone,
  school,
  rain,
  ambulance,
  bicycle,
  night,
  busStop,
  construction,
  railroad,
  speedLimit,
  officer,
}

class _GameChoice {
  final String label;
  final IconData icon;

  const _GameChoice(this.label, this.icon);
}

class _GameQuestion {
  final String badge;
  final IconData icon;
  final Color accent;
  final _RoadScene scene;
  final String prompt;
  final List<_GameChoice> choices;
  final int correctIndex;
  final String feedback;

  const _GameQuestion({
    required this.badge,
    required this.icon,
    required this.accent,
    required this.scene,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    required this.feedback,
  });
}

class _ScoreChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ScoreChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0F172A)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  final double value;
  final Color accent;

  const _ProgressTrack({required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 12,
        color: Colors.white.withValues(alpha: .5),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0, 1).toDouble(),
            heightFactor: 1,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, const Color(0xFFFDE047)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingMissionBadge extends StatelessWidget {
  final _GameQuestion question;
  final bool answered;
  final bool correct;

  const _FloatingMissionBadge({
    super.key,
    required this.question,
    required this.answered,
    required this.correct,
  });

  @override
  Widget build(BuildContext context) {
    final resultIcon = correct ? Icons.check_circle : Icons.cancel;
    final resultColor = correct
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: question.accent.withValues(alpha: .4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            answered ? resultIcon : question.icon,
            color: answered ? resultColor : question.accent,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            answered
                ? (correct ? '¡Bien hecho!' : 'Intenta recordar')
                : question.badge,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int count;

  const _StarRow({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final active = index < count;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Icon(
            active ? Icons.star : Icons.star_border,
            color: active ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
            size: 34,
          ),
        );
      }),
    );
  }
}

class _CelebrationPainter extends CustomPainter {
  final int stars;

  const _CelebrationPainter({required this.stars});

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFFDE047),
      const Color(0xFF22C55E),
      const Color(0xFF38BDF8),
      const Color(0xFFFB7185),
      const Color(0xFFF97316),
    ];

    for (var i = 0; i < 34; i++) {
      final x = (i * 47 % size.width).toDouble();
      final y = (i * 83 % size.height).toDouble();
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: .82);
      final rect = Rect.fromCenter(
        center: Offset(x, y),
        width: 9 + (i % 3) * 4,
        height: 9 + (i % 2) * 5,
      );
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate((i + stars) * .35);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: rect.width,
            height: rect.height,
          ),
          const Radius.circular(3),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) {
    return oldDelegate.stars != stars;
  }
}

class _CityRoadPainter extends CustomPainter {
  final double progress;
  final int lane;
  final _RoadScene scene;
  final Color accent;
  final bool successPulse;
  final bool dangerPulse;

  const _CityRoadPainter({
    required this.progress,
    required this.lane,
    required this.scene,
    required this.accent,
    this.successPulse = false,
    this.dangerPulse = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final roadTop = size.height * .27;
    _drawSky(canvas, size);
    _drawBuildings(canvas, size);
    _drawSidewalks(canvas, size, roadTop);
    _drawRoad(canvas, size, roadTop);
    _drawScene(canvas, size, roadTop);
    _drawLaneMarks(canvas, size, roadTop);
    if (scene == _RoadScene.crosswalk) {
      _drawCrosswalk(canvas, size, roadTop);
    }
    if (scene == _RoadScene.rain) {
      _drawRain(canvas, size);
    }
    _drawCar(canvas, size);
  }

  void _drawSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = switch (scene) {
      _RoadScene.night => const [Color(0xFF172554), Color(0xFF312E81)],
      _RoadScene.rain => const [Color(0xFF64748B), Color(0xFF93C5FD)],
      _ => const [Color(0xFF38BDF8), Color(0xFF67E8F9)],
    };
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
    );

    if (scene == _RoadScene.night) {
      final moonPaint = Paint()..color = const Color(0xFFF8FAFC);
      canvas.drawCircle(Offset(size.width - 58, 58), 26, moonPaint);
      canvas.drawCircle(
        Offset(size.width - 46, 50),
        24,
        Paint()..color = const Color(0xFF172554),
      );
      final starPaint = Paint()..color = Colors.white.withValues(alpha: .8);
      for (var i = 0; i < 18; i++) {
        canvas.drawCircle(
          Offset((i * 41 % size.width).toDouble(), 24 + (i * 23 % 96)),
          1.6 + (i % 2),
          starPaint,
        );
      }
      return;
    }

    final sunCenter = Offset(size.width - 58, 58);
    canvas.drawCircle(
      sunCenter,
      36,
      Paint()..color = const Color(0xFFFDE047).withValues(alpha: .34),
    );
    canvas.drawCircle(sunCenter, 27, Paint()..color = const Color(0xFFFDE047));
    _drawCloud(
      canvas,
      Offset(72 + math.sin(progress * math.pi * 2) * 12, 72),
      1,
    );
    _drawCloud(
      canvas,
      Offset(size.width * .58, 52 + math.cos(progress * math.pi * 2) * 4),
      .72,
    );
  }

  void _drawCloud(Canvas canvas, Offset center, double scale) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .88);
    canvas.drawCircle(
      center + Offset(-20 * scale, 6 * scale),
      15 * scale,
      paint,
    );
    canvas.drawCircle(center + Offset(0, -4 * scale), 18 * scale, paint);
    canvas.drawCircle(
      center + Offset(20 * scale, 5 * scale),
      13 * scale,
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + Offset(0, 9 * scale),
          width: 62 * scale,
          height: 20 * scale,
        ),
        Radius.circular(10 * scale),
      ),
      paint,
    );
  }

  void _drawRoad(Canvas canvas, Size size, double roadTop) {
    final road = Path()
      ..moveTo(size.width * .20, roadTop)
      ..lineTo(size.width * .80, roadTop)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(road, Colors.black.withValues(alpha: .4), 8, false);
    canvas.drawPath(road, Paint()..color = const Color(0xFF334155));

    final shoulder = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: .75);
    canvas.drawLine(
      Offset(size.width * .20, roadTop),
      Offset(0, size.height),
      shoulder..strokeWidth = 7,
    );
    canvas.drawLine(
      Offset(size.width * .80, roadTop),
      Offset(size.width, size.height),
      shoulder,
    );

    if (scene == _RoadScene.rain) {
      final puddlePaint = Paint()
        ..color = const Color(0xFF93C5FD).withValues(alpha: .36);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .68, size.height * .67),
          width: 76,
          height: 18,
        ),
        puddlePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .32, size.height * .55),
          width: 48,
          height: 12,
        ),
        puddlePaint,
      );
    }
  }

  void _drawSidewalks(Canvas canvas, Size size, double roadTop) {
    final grass = Paint()..color = const Color(0xFF22C55E);
    canvas.drawPath(
      Path()
        ..moveTo(0, roadTop)
        ..lineTo(size.width * .20, roadTop)
        ..lineTo(0, size.height)
        ..close(),
      grass,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width, roadTop)
        ..lineTo(size.width * .80, roadTop)
        ..lineTo(size.width, size.height)
        ..close(),
      grass,
    );

    final pathPaint = Paint()
      ..color = const Color(0xFF86EFAC).withValues(alpha: .55);
    canvas.drawPath(
      Path()
        ..moveTo(0, roadTop + 12)
        ..lineTo(size.width * .16, roadTop)
        ..lineTo(size.width * .04, size.height)
        ..lineTo(0, size.height)
        ..close(),
      pathPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width, roadTop + 12)
        ..lineTo(size.width * .84, roadTop)
        ..lineTo(size.width * .96, size.height)
        ..lineTo(size.width, size.height)
        ..close(),
      pathPaint,
    );
    _drawTrees(canvas, size, roadTop);
  }

  void _drawLaneMarks(Canvas canvas, Size size, double roadTop) {
    final lanePaint = Paint()
      ..color = Colors.white.withValues(alpha: .76)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final y = roadTop + ((i + progress) * 70) % (size.height - roadTop + 70);
      final spread = (y - roadTop) / (size.height - roadTop);
      final center = size.width / 2;
      canvas.drawLine(
        Offset(center - 42 * spread, y),
        Offset(center - 24 * spread, y + 34),
        lanePaint,
      );
      canvas.drawLine(
        Offset(center + 42 * spread, y),
        Offset(center + 24 * spread, y + 34),
        lanePaint,
      );
    }

    final motionPaint = Paint()
      ..color = accent.withValues(alpha: successPulse ? .28 : .16)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final y = size.height - 120 - i * 44 - progress * 22;
      canvas.drawLine(
        Offset(size.width * .18, y),
        Offset(size.width * .08, y + 28),
        motionPaint,
      );
    }
  }

  void _drawBuildings(Canvas canvas, Size size) {
    final horizon = size.height * .27;
    final colors = [
      const Color(0xFF075985),
      const Color(0xFF7C3AED),
      const Color(0xFFEA580C),
      const Color(0xFF0F766E),
      const Color(0xFFBE123C),
    ];
    for (var i = 0; i < 9; i++) {
      final width = size.width / 6.7;
      final left = i * width - 26;
      final height = 64.0 + (i % 4) * 22;
      final rect = Rect.fromLTWH(left, horizon - height, width, height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(7)),
        Paint()..color = colors[i % colors.length],
      );
      final roof = Path()
        ..moveTo(rect.left + 8, rect.top)
        ..lineTo(rect.center.dx, rect.top - 13)
        ..lineTo(rect.right - 8, rect.top)
        ..close();
      canvas.drawPath(
        roof,
        Paint()..color = Colors.black.withValues(alpha: .15),
      );
      final windowPaint = Paint()
        ..color =
            (scene == _RoadScene.night ? const Color(0xFFFDE047) : Colors.white)
                .withValues(alpha: .78);
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 2; c++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left + 15 + c * 25, rect.top + 15 + r * 23, 12, 11),
              const Radius.circular(2),
            ),
            windowPaint,
          );
        }
      }
    }
  }

  void _drawTrees(Canvas canvas, Size size, double roadTop) {
    for (final x in [size.width * .10, size.width * .91]) {
      final trunk = Paint()..color = const Color(0xFF92400E);
      final leaves = Paint()..color = const Color(0xFF15803D);
      final baseY = roadTop + 58;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, baseY + 19), width: 11, height: 38),
          const Radius.circular(5),
        ),
        trunk,
      );
      canvas.drawCircle(Offset(x, baseY), 24, leaves);
      canvas.drawCircle(
        Offset(x - 16, baseY + 9),
        16,
        leaves..color = const Color(0xFF16A34A),
      );
      canvas.drawCircle(Offset(x + 16, baseY + 10), 16, leaves);
    }
  }

  void _drawScene(Canvas canvas, Size size, double roadTop) {
    switch (scene) {
      case _RoadScene.crosswalk:
        _drawPedestrian(canvas, Offset(size.width * .25, roadTop + 82), 1);
      case _RoadScene.trafficLight:
        _drawTrafficLight(canvas, Offset(size.width * .78, roadTop + 80));
      case _RoadScene.ball:
        _drawBall(canvas, Offset(size.width * .46, roadTop + 124));
        _drawPedestrian(canvas, Offset(size.width * .22, roadTop + 75), .82);
      case _RoadScene.stopSign:
        _drawStopSign(canvas, Offset(size.width * .22, roadTop + 82));
      case _RoadScene.seatbelt:
        _drawSeatbelt(canvas, Offset(size.width * .75, roadTop + 90));
      case _RoadScene.phone:
        _drawPhone(canvas, Offset(size.width * .78, roadTop + 92));
      case _RoadScene.school:
        _drawSchoolSign(canvas, Offset(size.width * .20, roadTop + 86));
        _drawPedestrian(canvas, Offset(size.width * .79, roadTop + 78), .72);
        _drawPedestrian(canvas, Offset(size.width * .86, roadTop + 96), .58);
      case _RoadScene.rain:
        _drawTrafficLight(canvas, Offset(size.width * .82, roadTop + 76));
      case _RoadScene.ambulance:
        _drawAmbulance(canvas, Offset(size.width * .58, roadTop + 104));
      case _RoadScene.bicycle:
        _drawBicycle(canvas, Offset(size.width * .70, roadTop + 116));
      case _RoadScene.night:
        _drawStreetLight(canvas, Offset(size.width * .18, roadTop + 90));
        _drawStreetLight(canvas, Offset(size.width * .84, roadTop + 96));
      case _RoadScene.busStop:
        _drawBus(canvas, Offset(size.width * .25, roadTop + 93));
      case _RoadScene.construction:
        _drawCones(canvas, size, roadTop);
      case _RoadScene.railroad:
        _drawRailroad(canvas, size, roadTop);
      case _RoadScene.speedLimit:
        _drawSpeedSign(canvas, Offset(size.width * .22, roadTop + 84));
      case _RoadScene.officer:
        _drawOfficer(canvas, Offset(size.width * .76, roadTop + 96));
    }
  }

  void _drawTrafficLight(Canvas canvas, Offset base) {
    final pole = Paint()..color = const Color(0xFF475569);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: base + const Offset(0, 34),
          width: 8,
          height: 74,
        ),
        const Radius.circular(4),
      ),
      pole,
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: base + const Offset(0, -18),
        width: 34,
        height: 74,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF0F172A));
    final lights = [
      (
        const Offset(0, -40),
        const Color(0xFFEF4444),
        scene == _RoadScene.trafficLight ? .25 : .8,
      ),
      (const Offset(0, -18), const Color(0xFFFDE047), 1.0),
      (
        const Offset(0, 4),
        const Color(0xFF22C55E),
        scene == _RoadScene.trafficLight ? .25 : .7,
      ),
    ];
    for (final light in lights) {
      canvas.drawCircle(
        base + light.$1,
        8,
        Paint()..color = light.$2.withValues(alpha: light.$3),
      );
    }
  }

  void _drawStopSign(Canvas canvas, Offset center) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = math.pi / 8 + i * math.pi / 4;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * 34;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + const Offset(0, 47),
          width: 7,
          height: 62,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF475569),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xFFDC2626));
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    _drawText(canvas, 'ALTO', center - const Offset(0, 7), 13, Colors.white);
  }

  void _drawSpeedSign(Canvas canvas, Offset center) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + const Offset(0, 52),
          width: 7,
          height: 70,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF475569),
    );
    canvas.drawCircle(center, 34, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      34,
      Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    _drawText(
      canvas,
      '30',
      center - const Offset(0, 11),
      24,
      const Color(0xFF0F172A),
    );
  }

  void _drawSchoolSign(Canvas canvas, Offset center) {
    final diamond = Path()
      ..moveTo(center.dx, center.dy - 38)
      ..lineTo(center.dx + 38, center.dy)
      ..lineTo(center.dx, center.dy + 38)
      ..lineTo(center.dx - 38, center.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = const Color(0xFFFDE047));
    canvas.drawPath(
      diamond,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    _drawText(
      canvas,
      'ESCUELA',
      center - const Offset(0, 13),
      11,
      const Color(0xFF0F172A),
    );
    _drawText(
      canvas,
      '30',
      center + const Offset(0, 5),
      17,
      const Color(0xFF0F172A),
    );
  }

  void _drawPedestrian(Canvas canvas, Offset center, double scale) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 5 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center + Offset(0, -23 * scale), 8 * scale, paint);
    canvas.drawLine(
      center + Offset(0, -13 * scale),
      center + Offset(0, 12 * scale),
      paint,
    );
    canvas.drawLine(
      center + Offset(0, -2 * scale),
      center + Offset(-14 * scale, 8 * scale),
      paint,
    );
    canvas.drawLine(
      center + Offset(0, -1 * scale),
      center + Offset(13 * scale, 6 * scale),
      paint,
    );
    canvas.drawLine(
      center + Offset(0, 12 * scale),
      center + Offset(-12 * scale, 30 * scale),
      paint,
    );
    canvas.drawLine(
      center + Offset(0, 12 * scale),
      center + Offset(13 * scale, 29 * scale),
      paint,
    );
  }

  void _drawBall(Canvas canvas, Offset center) {
    final wobble = math.sin(progress * math.pi * 2) * 12;
    final shifted = center + Offset(wobble, 0);
    canvas.drawCircle(shifted, 18, Paint()..color = Colors.white);
    canvas.drawCircle(
      shifted,
      18,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      shifted + const Offset(-15, -4),
      shifted + const Offset(15, 4),
      Paint()
        ..color = const Color(0xFF0F172A)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      shifted + const Offset(4, -15),
      shifted + const Offset(-4, 15),
      Paint()
        ..color = const Color(0xFF0F172A)
        ..strokeWidth = 2,
    );
  }

  void _drawSeatbelt(Canvas canvas, Offset center) {
    final belt = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final seat = Paint()..color = const Color(0xFFBAE6FD);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 78, height: 78),
        const Radius.circular(22),
      ),
      Paint()..color = Colors.white.withValues(alpha: .86),
    );
    canvas.drawCircle(center + const Offset(-14, -20), 12, seat);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + const Offset(-6, 14),
          width: 34,
          height: 40,
        ),
        const Radius.circular(12),
      ),
      seat,
    );
    canvas.drawLine(
      center + const Offset(-28, -30),
      center + const Offset(30, 32),
      belt,
    );
    canvas.drawCircle(
      center + const Offset(13, 13),
      7,
      Paint()..color = const Color(0xFFF97316),
    );
  }

  void _drawPhone(Canvas canvas, Offset center) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 46, height: 76),
      const Radius.circular(12),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF0F172A));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 34, height: 55),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFFBAE6FD),
    );
    canvas.drawLine(
      center + const Offset(-34, -44),
      center + const Offset(34, 44),
      Paint()
        ..color = const Color(0xFFEF4444)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawAmbulance(Canvas canvas, Offset center) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 106, height: 48),
        const Radius.circular(13),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + const Offset(30, -7),
          width: 28,
          height: 22,
        ),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFBAE6FD),
    );
    final red = Paint()..color = const Color(0xFFEF4444);
    canvas.drawRect(
      Rect.fromCenter(
        center: center + const Offset(-20, 0),
        width: 9,
        height: 28,
      ),
      red,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: center + const Offset(-20, 0),
        width: 28,
        height: 9,
      ),
      red,
    );
    canvas.drawCircle(
      center + const Offset(-34, 25),
      8,
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawCircle(
      center + const Offset(34, 25),
      8,
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawCircle(
      center + Offset(math.sin(progress * math.pi * 2) * 8, -32),
      7,
      Paint()..color = const Color(0xFF38BDF8),
    );
  }

  void _drawBicycle(Canvas canvas, Offset center) {
    final stroke = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center + const Offset(-25, 24), 18, stroke);
    canvas.drawCircle(center + const Offset(28, 24), 18, stroke);
    canvas.drawLine(
      center + const Offset(-25, 24),
      center + const Offset(0, -4),
      stroke,
    );
    canvas.drawLine(
      center + const Offset(0, -4),
      center + const Offset(28, 24),
      stroke,
    );
    canvas.drawLine(
      center + const Offset(-25, 24),
      center + const Offset(28, 24),
      stroke,
    );
    _drawPedestrian(canvas, center + const Offset(2, -14), .62);
  }

  void _drawStreetLight(Canvas canvas, Offset base) {
    final pole = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      base + const Offset(0, 62),
      base + const Offset(0, -32),
      pole,
    );
    canvas.drawLine(
      base + const Offset(0, -32),
      base + const Offset(36, -32),
      pole,
    );
    canvas.drawCircle(
      base + const Offset(42, -27),
      11,
      Paint()..color = const Color(0xFFFDE047),
    );
    canvas.drawCircle(
      base + const Offset(42, -27),
      30,
      Paint()..color = const Color(0xFFFDE047).withValues(alpha: .18),
    );
  }

  void _drawBus(Canvas canvas, Offset center) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 104, height: 56),
        const Radius.circular(13),
      ),
      Paint()..color = const Color(0xFFFACC15),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(center.dx - 42 + i * 28, center.dy - 19, 20, 16),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFBAE6FD),
      );
    }
    canvas.drawCircle(
      center + const Offset(-34, 29),
      8,
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawCircle(
      center + const Offset(34, 29),
      8,
      Paint()..color = const Color(0xFF0F172A),
    );
    _drawText(
      canvas,
      'BUS',
      center - const Offset(0, 3),
      13,
      const Color(0xFF0F172A),
    );
  }

  void _drawCones(Canvas canvas, Size size, double roadTop) {
    for (var i = 0; i < 4; i++) {
      final center = Offset(
        size.width * (.33 + i * .09),
        roadTop + 82 + i * 28,
      );
      final cone = Path()
        ..moveTo(center.dx, center.dy - 22)
        ..lineTo(center.dx - 17, center.dy + 22)
        ..lineTo(center.dx + 17, center.dy + 22)
        ..close();
      canvas.drawPath(cone, Paint()..color = const Color(0xFFF97316));
      canvas.drawRect(
        Rect.fromCenter(
          center: center + const Offset(0, 7),
          width: 26,
          height: 6,
        ),
        Paint()..color = Colors.white,
      );
    }
  }

  void _drawRailroad(Canvas canvas, Size size, double roadTop) {
    final railPaint = Paint()
      ..color = const Color(0xFF78350F)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final y = roadTop + 105;
    canvas.drawLine(
      Offset(size.width * .20, y),
      Offset(size.width * .80, y + 70),
      railPaint,
    );
    canvas.drawLine(
      Offset(size.width * .24, y - 30),
      Offset(size.width * .84, y + 38),
      railPaint,
    );
    final barrier = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .21, y - 42),
      Offset(size.width * .63, y + 2),
      barrier,
    );
    _drawText(
      canvas,
      'TREN',
      Offset(size.width * .75, y - 33),
      13,
      const Color(0xFF0F172A),
    );
  }

  void _drawOfficer(Canvas canvas, Offset center) {
    _drawPedestrian(canvas, center, .9);
    final blue = Paint()..color = const Color(0xFF1D4ED8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + const Offset(0, -8),
          width: 30,
          height: 30,
        ),
        const Radius.circular(8),
      ),
      blue,
    );
    canvas.drawLine(
      center + const Offset(-7, -6),
      center + const Offset(-42, -30),
      Paint()
        ..color = const Color(0xFF0F172A)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      center + const Offset(-45, -32),
      8,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }

  void _drawCrosswalk(Canvas canvas, Size size, double roadTop) {
    final y = roadTop + 64 + math.sin(progress * math.pi * 2) * 5;
    final paint = Paint()..color = Colors.white.withValues(alpha: .92);
    for (var i = 0; i < 6; i++) {
      final w = 42.0 + i * 12;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, y + i * 13),
            width: w,
            height: 7,
          ),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  void _drawRain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDBEAFE).withValues(alpha: .72)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 36; i++) {
      final x = (i * 31 % size.width).toDouble();
      final y = ((i * 47 + progress * 90) % size.height).toDouble();
      canvas.drawLine(Offset(x, y), Offset(x - 8, y + 18), paint);
    }
  }

  void _drawCar(Canvas canvas, Size size) {
    final laneCenters = [size.width * .29, size.width * .50, size.width * .71];
    final laneIndex = lane < 0
        ? 0
        : lane > 2
        ? 2
        : lane;
    final x = laneCenters[laneIndex];
    final y = size.height - 84;
    final pulse = successPulse ? 1.08 : 1.0;
    final shake = dangerPulse ? math.sin(progress * math.pi * 12) * .04 : 0.0;

    if (successPulse) {
      canvas.drawCircle(
        Offset(x, y + 4),
        56,
        Paint()..color = const Color(0xFF22C55E).withValues(alpha: .18),
      );
    }

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(shake);
    canvas.scale(pulse);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 42), width: 88, height: 18),
      Paint()..color = Colors.black.withValues(alpha: .22),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-38, -42, 76, 88),
        const Radius.circular(22),
      ),
      Paint()..color = const Color(0xFFE11D48),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-26, -32, 52, 31),
        const Radius.circular(12),
      ),
      Paint()..color = const Color(0xFFBAE6FD),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-25, 13, 50, 25),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFFFFEDD5),
    );
    final wheel = Paint()..color = const Color(0xFF0F172A);
    canvas.drawCircle(const Offset(-43, -12), 9, wheel);
    canvas.drawCircle(const Offset(43, -12), 9, wheel);
    canvas.drawCircle(const Offset(-43, 28), 9, wheel);
    canvas.drawCircle(const Offset(43, 28), 9, wheel);
    final light = Paint()..color = const Color(0xFFFDE047);
    canvas.drawCircle(const Offset(-18, -43), 5, light);
    canvas.drawCircle(const Offset(18, -43), 5, light);
    canvas.restore();
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w900,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 86);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CityRoadPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.lane != lane ||
        oldDelegate.scene != scene ||
        oldDelegate.accent != accent ||
        oldDelegate.successPulse != successPulse ||
        oldDelegate.dangerPulse != dangerPulse;
  }
}
