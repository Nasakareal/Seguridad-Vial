import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/cultura_vial_audio_service.dart';
import '../../services/cultura_vial_progress_service.dart';
import '../content/vial_question_bank.dart';
import '../models/vial_question.dart';
import '../widgets/academy_question_card.dart';

const _navy = Color(0xFF102E49);
const _blue = Color(0xFF176BE0);
const _teal = Color(0xFF11A88A);
const _paper = Color(0xFFF1F6FC);

class _TopicStyle {
  final IconData icon;
  final Color color;
  final String caption;

  const _TopicStyle(this.icon, this.color, this.caption);
}

const _topicStyles = <String, _TopicStyle>{
  'Señales y semáforos': _TopicStyle(
    Icons.traffic_rounded,
    Color(0xFFE4644D),
    'Interpreta lo que indica la vía',
  ),
  'Cruces y preferencias': _TopicStyle(
    Icons.alt_route_rounded,
    Color(0xFF477ED3),
    'Resuelve conflictos en intersecciones',
  ),
  'Peatones y ciclistas': _TopicStyle(
    Icons.directions_bike_rounded,
    Color(0xFF169B82),
    'Protege a las personas vulnerables',
  ),
  'Motocicletas': _TopicStyle(
    Icons.two_wheeler_rounded,
    Color(0xFFF29A3C),
    'Reconoce riesgos en dos ruedas',
  ),
  'Velocidad y frenado': _TopicStyle(
    Icons.speed_rounded,
    Color(0xFF6374D2),
    'Conserva distancia y control',
  ),
  'Clima y visibilidad': _TopicStyle(
    Icons.cloud_rounded,
    Color(0xFF2C99C5),
    'Conduce cuando cambia el entorno',
  ),
  'Protección y pasajeros': _TopicStyle(
    Icons.health_and_safety_rounded,
    Color(0xFF209C72),
    'Protección antes de arrancar',
  ),
  'Atención y decisiones': _TopicStyle(
    Icons.psychology_rounded,
    Color(0xFFC47BBA),
    'Evita distracciones y fatiga',
  ),
  'Maniobras y estacionamiento': _TopicStyle(
    Icons.turn_right_rounded,
    Color(0xFF478DCD),
    'Anticipa cada movimiento',
  ),
  'Emergencias y convivencia': _TopicStyle(
    Icons.emergency_rounded,
    Color(0xFFD25A66),
    'Actúa sin crear otro riesgo',
  ),
};

enum _AcademyStage { menu, playing, results }

class AcademiaVialScreen extends StatefulWidget {
  final AcademiaMode initialMode;

  const AcademiaVialScreen({
    super.key,
    this.initialMode = AcademiaMode.aprender,
  });

  @override
  State<AcademiaVialScreen> createState() => _AcademiaVialScreenState();
}

class _AcademiaVialScreenState extends State<AcademiaVialScreen> {
  late AcademiaMode _mode;
  _AcademyStage _stage = _AcademyStage.menu;
  List<VialQuestion> _questions = <VialQuestion>[];
  List<int?> _answers = <int?>[];
  int _index = 0;
  int _practiceCount = 15;
  int _seconds = 25 * 60;
  Timer? _timer;
  bool _recorded = false;
  bool _reviewingMistakes = false;
  String? _selectedTopic;
  Set<String> _mistakeIds = <String>{};
  Map<String, List<int>> _topicProgress = <String, List<int>>{};

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    unawaited(CulturaVialAudioService.instance.enterModule());
    unawaited(_loadProgress());
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(CulturaVialAudioService.instance.exitModule());
    super.dispose();
  }

  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonDecode(
        prefs.getString('academy_topic_progress_v3') ?? '{}',
      );
      final data = <String, List<int>>{};
      if (raw is Map) {
        for (final entry in raw.entries) {
          if (entry.value is List && (entry.value as List).length >= 2) {
            final pair = entry.value as List;
            data[entry.key.toString()] = <int>[
              int.tryParse('${pair[0]}') ?? 0,
              int.tryParse('${pair[1]}') ?? 0,
            ];
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _topicProgress = data;
        _mistakeIds =
            prefs.getStringList('academy_error_ids_v3')?.toSet() ?? <String>{};
      });
    } catch (_) {}
  }

  void _switchMode(AcademiaMode mode) {
    _timer?.cancel();
    setState(() {
      _mode = mode;
      _stage = _AcademyStage.menu;
      _selectedTopic = null;
      _reviewingMistakes = false;
    });
  }

  List<VialQuestion> _sampleBalanced(int count) {
    final random = Random();
    final shuffled = <VialQuestion>[];
    final buckets = <List<VialQuestion>>[];
    for (final category in _topicStyles.keys) {
      buckets.add(
        (vialQuestionBank
            .where((question) => question.category == category)
            .toList()
          ..shuffle(random)),
      );
    }
    while (shuffled.length < count &&
        buckets.any((bucket) => bucket.isNotEmpty)) {
      buckets.shuffle(random);
      for (final bucket in buckets) {
        if (bucket.isNotEmpty && shuffled.length < count) {
          shuffled.add(bucket.removeLast());
        }
      }
    }
    shuffled.shuffle(random);
    return shuffled;
  }

  void _start({String? category, bool errorsOnly = false}) {
    _timer?.cancel();
    final pool = errorsOnly
        ? vialQuestionBank
              .where((question) => _mistakeIds.contains(question.id))
              .toList()
        : category == null
        ? <VialQuestion>[]
        : vialQuestionBank
              .where((question) => question.category == category)
              .toList();
    List<VialQuestion> chosen;
    if (_mode == AcademiaMode.simulacro) {
      chosen = _sampleBalanced(30);
    } else if (errorsOnly) {
      chosen = pool..shuffle(Random());
    } else if (_mode == AcademiaMode.aprender) {
      chosen = pool;
    } else if (category != null) {
      chosen = pool..shuffle(Random());
      chosen = chosen.take(_practiceCount).toList();
    } else {
      chosen = _sampleBalanced(_practiceCount);
    }
    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay preguntas en esta selección.')),
      );
      return;
    }
    setState(() {
      _questions = chosen;
      _answers = List<int?>.filled(chosen.length, null);
      _index = 0;
      _seconds = 25 * 60;
      _stage = _AcademyStage.playing;
      _selectedTopic = category;
      _recorded = false;
      _reviewingMistakes = errorsOnly;
    });
    if (_mode == AcademiaMode.simulacro) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _stage != _AcademyStage.playing) return;
        if (_seconds <= 1) {
          _finish();
        } else {
          setState(() => _seconds--);
        }
      });
    }
  }

  void _answer(int index) {
    if (_stage != _AcademyStage.playing) return;
    if (_mode != AcademiaMode.simulacro && _answers[_index] != null) return;
    unawaited(CulturaVialAudioService.instance.notifyInteraction());
    setState(() => _answers[_index] = index);
    if (_mode != AcademiaMode.simulacro) {
      unawaited(
        CulturaVialAudioService.instance.playEffect(
          index == _questions[_index].correct
              ? CulturaVialSound.correct
              : CulturaVialSound.wrong,
        ),
      );
    }
  }

  void _next() {
    if (_stage != _AcademyStage.playing) return;
    if (_index + 1 >= _questions.length) {
      _finish();
      return;
    }
    setState(() => _index++);
  }

  int get _correctCount {
    var total = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_answers[i] == _questions[i].correct) total++;
    }
    return total;
  }

  Future<void> _finish() async {
    if (_recorded || _questions.isEmpty) return;
    _recorded = true;
    _timer?.cancel();
    final correct = _correctCount;
    final percent = (correct * 100 / _questions.length).round();
    setState(() => _stage = _AcademyStage.results);
    final gameId = switch (_mode) {
      AcademiaMode.aprender => 'academia_aprender',
      AcademiaMode.practicar => 'academia_practicar',
      AcademiaMode.simulacro => 'academia_simulacro',
    };
    try {
      await CulturaVialProgressService.instance.recordGame(
        gameId: gameId,
        score: percent * 10,
        stars: percent >= 90
            ? 3
            : percent >= 75
            ? 2
            : 1,
        correct: correct,
        mistakes: _questions.length - correct,
      );
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final progress = <String, List<int>>{
        for (final entry in _topicProgress.entries)
          entry.key: List<int>.from(entry.value),
      };
      final missed = Set<String>.from(_mistakeIds);
      for (var i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final values = progress.putIfAbsent(q.category, () => <int>[0, 0]);
        values[0]++;
        if (_answers[i] == q.correct) {
          values[1]++;
          missed.remove(q.id);
        } else {
          missed.add(q.id);
        }
      }
      await prefs.setString('academy_topic_progress_v3', jsonEncode(progress));
      await prefs.setStringList('academy_error_ids_v3', missed.toList());
      if (mounted) {
        setState(() {
          _topicProgress = progress;
          _mistakeIds = missed;
        });
      }
    } catch (_) {}
  }

  Future<void> _confirmExit() async {
    if (_stage != _AcademyStage.playing) {
      setState(() => _stage = _AcademyStage.menu);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir de la sesión?'),
        content: const Text(
          'Si sales ahora, esta sesión no guardará resultado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Seguir practicando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      _timer?.cancel();
      setState(() => _stage = _AcademyStage.menu);
    }
  }

  void _showExamReview() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Revisar simulacro',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${_answers.where((value) => value != null).length} de ${_questions.length} respondidas. Puedes regresar a cualquier pregunta.',
                  style: const TextStyle(color: Color(0xFF637C90)),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _questions.length; i++)
                          ActionChip(
                            label: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            backgroundColor: _answers[i] == null
                                ? const Color(0xFFFFEDDE)
                                : const Color(0xFFE4F5EE),
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              setState(() => _index = i);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                FilledButton.icon(
                  onPressed: () async {
                    final missing = _answers
                        .where((value) => value == null)
                        .length;
                    if (missing > 0) {
                      final accepted = await showDialog<bool>(
                        context: sheetContext,
                        builder: (dialogContext) => AlertDialog(
                          title: Text('$missing preguntas sin responder'),
                          content: const Text(
                            'Se considerarán incorrectas. ¿Quieres entregar el simulacro?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Revisar'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Entregar'),
                            ),
                          ],
                        ),
                      );
                      if (accepted != true) return;
                    }
                    if (!mounted || !sheetContext.mounted) return;
                    Navigator.pop(sheetContext);
                    await _finish();
                  },
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('Entregar respuestas'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                    backgroundColor: _blue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      AcademiaMode.aprender => 'Aprender',
      AcademiaMode.practicar => 'Practicar',
      AcademiaMode.simulacro => 'Simulacro',
    };
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _navy,
        surfaceTintColor: Colors.white,
        title: Text(
          _stage == _AcademyStage.menu ? 'Michoacán al Volante' : title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        leading: _stage == _AcademyStage.menu
            ? null
            : IconButton(
                onPressed: _confirmExit,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        actions: [
          if (_stage != _AcademyStage.menu)
            IconButton(
              tooltip: 'Inicio de la academia',
              icon: const Icon(Icons.home_outlined),
              onPressed: _confirmExit,
            ),
        ],
      ),
      body: _stage == _AcademyStage.menu
          ? _menu()
          : _stage == _AcademyStage.playing
          ? _playing()
          : _results(),
    );
  }

  Widget _menu() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 17, 16, 36),
          children: [
            Container(
              padding: const EdgeInsets.all(23),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_navy, Color(0xFF16617A)],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACADEMIA DE SEGURIDAD VIAL',
                          style: TextStyle(
                            color: Color(0xFF8DE4D7),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'Aprende a leer la calle.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${vialQuestionBank.length} preguntas · ${_topicStyles.length} temas · 54 escenas ilustradas',
                          style: const TextStyle(
                            color: Color(0xFFC8E8EF),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Icon(
                    Icons.school_rounded,
                    size: 68,
                    color: Color(0xFFE8C16B),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _statTile(
                    'BANCO',
                    '${vialQuestionBank.length}',
                    Icons.collections_bookmark_rounded,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _statTile(
                    'POR TEMA',
                    '12',
                    Icons.auto_stories_rounded,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _statTile(
                    'POR EXAMEN',
                    '30',
                    Icons.fact_check_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              '¿Cómo quieres entrenar?',
              style: TextStyle(
                color: _navy,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _modeChip(
                  AcademiaMode.aprender,
                  'Aprender',
                  Icons.school_rounded,
                ),
                _modeChip(
                  AcademiaMode.practicar,
                  'Practicar',
                  Icons.bolt_rounded,
                ),
                _modeChip(
                  AcademiaMode.simulacro,
                  'Simulacro',
                  Icons.timer_rounded,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_mode == AcademiaMode.aprender) ...[
              const Text(
                'RUTA DE APRENDIZAJE',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF5B7187),
                ),
              ),
              const SizedBox(height: 9),
              LayoutBuilder(
                builder: (_, constraints) {
                  final columns = constraints.maxWidth > 660 ? 2 : 1;
                  final tileWidth =
                      (constraints.maxWidth - (columns - 1) * 10) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final entry in _topicStyles.entries)
                        SizedBox(
                          width: tileWidth,
                          child: _topicTile(entry.key, entry.value),
                        ),
                    ],
                  );
                },
              ),
            ] else if (_mode == AcademiaMode.practicar) ...[
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Práctica personalizada',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Responde, descubre por qué y aprende en el momento.',
                      style: TextStyle(color: Color(0xFF62798B)),
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final n in <int>[12, 15, 20, 30])
                          ChoiceChip(
                            label: Text('$n preguntas'),
                            selected: _practiceCount == n,
                            onSelected: (_) =>
                                setState(() => _practiceCount = n),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedTopic,
                      decoration: const InputDecoration(
                        labelText: 'Tema',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Todos los temas'),
                        ),
                        for (final name in _topicStyles.keys)
                          DropdownMenuItem<String>(
                            value: name,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedTopic = value),
                    ),
                    const SizedBox(height: 14),
                    _primaryButton(
                      'Comenzar práctica',
                      Icons.play_arrow_rounded,
                      () => _start(category: _selectedTopic),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.fact_check_rounded,
                      size: 62,
                      color: _blue,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Examen de entrenamiento',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 13),
                    const Row(
                      children: [
                        Expanded(
                          child: _InfoPill(
                            icon: Icons.quiz_rounded,
                            label: '30 preguntas',
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _InfoPill(
                            icon: Icons.timer_outlined,
                            label: '25 minutos',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    const Text(
                      'Preguntas nuevas en cada intento, mezcladas entre los 10 temas. Podrás regresar a revisar respuestas antes de entregar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.45, color: Color(0xFF526C80)),
                    ),
                    const SizedBox(height: 17),
                    _primaryButton(
                      'Iniciar simulacro',
                      Icons.play_arrow_rounded,
                      _start,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Simulacro educativo. No sustituye los exámenes oficiales de la autoridad.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF63798B), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
            if (_mistakeIds.isNotEmpty) ...[
              const SizedBox(height: 14),
              _panel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFE7C8),
                    child: Icon(
                      Icons.replay_circle_filled_rounded,
                      color: Color(0xFFB46D15),
                    ),
                  ),
                  title: Text(
                    'Repasar ${_mistakeIds.length} preguntas pendientes',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text(
                    'Vuelve a intentar situaciones que antes te costaron.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    setState(() => _mode = AcademiaMode.practicar);
                    _start(errorsOnly: true);
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Basado en principios de seguridad vial y señalización mexicana. Material ilustrativo de práctica; las evaluaciones oficiales y sus requisitos corresponden a la autoridad competente.',
              style: TextStyle(
                color: Color(0xFF6D8190),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(AcademiaMode mode, String label, IconData icon) {
    final active = _mode == mode;
    return ChoiceChip(
      avatar: Icon(icon, color: active ? Colors.white : _navy, size: 18),
      label: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : _navy,
          fontWeight: FontWeight.w900,
        ),
      ),
      backgroundColor: Colors.white,
      selectedColor: _blue,
      showCheckmark: false,
      selected: active,
      onSelected: (_) => _switchMode(mode),
      side: BorderSide(color: active ? _blue : const Color(0xFFD4E2EF)),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    );
  }

  Widget _statTile(String caption, String value, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Icon(icon, color: _blue, size: 24),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _navy,
          ),
        ),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Color(0xFF637D91),
          ),
        ),
      ],
    ),
  );

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(23),
      border: Border.all(color: const Color(0xFFDFEAF5)),
    ),
    child: child,
  );

  Widget _topicTile(String name, _TopicStyle style) {
    final stats = _topicProgress[name] ?? <int>[0, 0];
    final attempts = stats[0];
    final accuracy = attempts == 0 ? 0 : (stats[1] * 100 / attempts).round();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () => _start(category: name),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDFE9F2)),
            borderRadius: BorderRadius.circular(19),
          ),
          child: Row(
            children: [
              Container(
                height: 51,
                width: 51,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(style.icon, color: style.color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      style.caption,
                      style: const TextStyle(
                        color: Color(0xFF687C8C),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      attempts == 0
                          ? '12 preguntas · Nuevo'
                          : '12 preguntas · $accuracy% de aciertos acumulados',
                      style: TextStyle(
                        color: style.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF839BAD)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    ),
    style: FilledButton.styleFrom(
      backgroundColor: _blue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  Widget _playing() {
    final done = _answers.where((answer) => answer != null).length;
    final exam = _mode == AcademiaMode.simulacro;
    final answered = _answers[_index] != null;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exam
                          ? 'EXAMEN EN CURSO'
                          : _reviewingMistakes
                          ? 'REPASO DE ERRORES'
                          : (_selectedTopic ?? _mode.name.toUpperCase())
                                .toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: .6,
                      ),
                    ),
                  ),
                  if (exam) ...[
                    const Icon(Icons.timer_outlined, color: _blue, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _seconds < 120 ? const Color(0xFFC83F4E) : _navy,
                      ),
                    ),
                    const SizedBox(width: 11),
                  ],
                  Text(
                    '${_index + 1}/${_questions.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: exam
                      ? done / _questions.length
                      : (_index + 1) / _questions.length,
                  backgroundColor: const Color(0xFFE1EAF4),
                  color: exam ? _teal : _blue,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: ValueKey('${_mode.name}_$_index'),
            padding: const EdgeInsets.fromLTRB(14, 17, 14, 20),
            children: [
              AcademyQuestionCard(
                key: ValueKey(_questions[_index].id),
                question: _questions[_index],
                questionNumber: _index + 1,
                selected: _answers[_index],
                revealAnswer: answered && !exam,
                examMode: exam,
                isLast: _index == _questions.length - 1,
                onAnswer: _answer,
                onNext: _next,
              ),
              if (exam) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _index > 0
                          ? () => setState(() => _index--)
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Anterior'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _index == _questions.length - 1
                            ? _showExamReview
                            : _next,
                        icon: Icon(
                          _index == _questions.length - 1
                              ? Icons.fact_check_rounded
                              : Icons.chevron_right_rounded,
                        ),
                        label: Text(
                          _index == _questions.length - 1
                              ? 'Revisar y entregar'
                              : 'Siguiente',
                        ),
                        style: FilledButton.styleFrom(backgroundColor: _blue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _showExamReview,
                  icon: const Icon(Icons.grid_view_rounded),
                  label: Text('Ver las 30 preguntas · $done respondidas'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _results() {
    final total = _questions.length;
    final correct = _correctCount;
    final percent = (correct * 100 / total).round();
    final goal = percent >= 80;
    final missed = <int>[
      for (var i = 0; i < _questions.length; i++)
        if (_answers[i] != _questions[i].correct) i,
    ];
    final byTopic = <String, List<int>>{};
    for (var i = 0; i < _questions.length; i++) {
      final stats = byTopic.putIfAbsent(
        _questions[i].category,
        () => <int>[0, 0],
      );
      stats[0]++;
      if (_answers[i] == _questions[i].correct) stats[1]++;
    }
    final weakest = byTopic.entries.toList()
      ..sort(
        (a, b) => (a.value[1] / a.value[0]).compareTo(b.value[1] / b.value[0]),
      );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(17, 21, 17, 35),
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_navy, Color(0xFF17617C)],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                children: [
                  Icon(
                    goal
                        ? Icons.workspace_premium_rounded
                        : Icons.menu_book_rounded,
                    size: 60,
                    color: const Color(0xFFFFD477),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 58,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$correct de $total respuestas correctas',
                    style: const TextStyle(
                      color: Color(0xFFE1F3FA),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    goal
                        ? '¡Buen nivel de preparación!'
                        : 'Cada error es una oportunidad de practicar.',
                    style: const TextStyle(
                      color: Color(0xFF7CE3D3),
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 17),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tu desempeño por tema',
                    style: TextStyle(
                      fontSize: 19,
                      color: _navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final entry in weakest) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '${entry.value[1]}/${entry.value[0]}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: entry.value[1] / entry.value[0],
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE5EDF4),
                        color: entry.value[1] == entry.value[0]
                            ? _teal
                            : const Color(0xFFE3A047),
                      ),
                    ),
                    const SizedBox(height: 13),
                  ],
                ],
              ),
            ),
            if (missed.isNotEmpty) ...[
              const SizedBox(height: 13),
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Repasa tus ${missed.length} respuestas por mejorar',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _navy,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final i in missed)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          _questions[i].prompt,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          _questions[i].category,
                          style: const TextStyle(fontSize: 11, color: _blue),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Respuesta: ${_questions[i].options[_questions[i].correct]}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF178359),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _questions[i].explanation,
                                  style: const TextStyle(height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 15),
            _primaryButton('Volver a la academia', Icons.school_rounded, () {
              setState(() => _stage = _AcademyStage.menu);
            }),
            const SizedBox(height: 9),
            OutlinedButton.icon(
              onPressed: () => _start(
                category: _selectedTopic,
                errorsOnly: _reviewingMistakes,
              ),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Otra sesión'),
            ),
            const SizedBox(height: 15),
            const Text(
              'El 80% es una meta de entrenamiento de esta aplicación, no el criterio de aprobación de un examen oficial.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF687F91),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      children: [
        Icon(icon, color: _blue, size: 22),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: _navy,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}
