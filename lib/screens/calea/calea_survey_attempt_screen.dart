import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/calea_survey_service.dart';

class CaleaSurveyAttemptScreen extends StatefulWidget {
  final int? surveyId;
  final String? attemptUuid;
  final bool publicAccess;
  const CaleaSurveyAttemptScreen({
    super.key,
    this.surveyId,
    this.attemptUuid,
    this.publicAccess = false,
  });
  @override
  State<CaleaSurveyAttemptScreen> createState() =>
      _CaleaSurveyAttemptScreenState();
}

class _CaleaSurveyAttemptScreenState extends State<CaleaSurveyAttemptScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _attempt;
  final Map<int, dynamic> _answers = {};
  final Map<int, TextEditingController> _texts = {};
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _busy = true, _terminal = false, _backgroundCancellationSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    for (final c in _texts.values) c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        !_terminal &&
        !_backgroundCancellationSent &&
        _attempt != null) {
      _backgroundCancellationSent = true;
      _cancel(silent: true);
    }
  }

  Future<void> _load() async {
    try {
      final data = widget.attemptUuid != null
          ? await CaleaSurveyService.attempt(
              widget.attemptUuid!,
              public: widget.publicAccess,
            )
          : await CaleaSurveyService.start(widget.surveyId!);
      _hydrate(data);
    } catch (e) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = CaleaSurveyService.clean(e);
        });
    }
  }

  void _hydrate(Map<String, dynamic> data) {
    _attempt = data;
    for (final raw in (data['respuestas'] as List? ?? const [])) {
      final r = Map<String, dynamic>.from(raw as Map);
      final id = int.tryParse('${r['pregunta_id']}') ?? 0;
      _answers[id] = r['opcion_id'] ?? r['respuesta_texto'];
    }
    final expires = DateTime.tryParse('${data['expira_at']}')?.toUtc();
    final server =
        DateTime.tryParse('${data['server_now']}')?.toUtc() ??
        DateTime.now().toUtc();
    _remaining = expires?.difference(server) ?? Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _terminal) return;
      setState(() => _remaining -= const Duration(seconds: 1));
      if (_remaining.inSeconds <= 0) {
        _timer?.cancel();
        _expire();
      }
    });
    if (mounted)
      setState(() {
        _busy = false;
        _error = null;
      });
  }

  Future<void> _save(int questionId, dynamic value, String type) async {
    setState(() => _answers[questionId] = value);
    try {
      await CaleaSurveyService.answer('${_attempt!['uuid']}', {
        'pregunta_id': questionId,
        if (type == 'opcion_unica')
          'opcion_id': value
        else
          'respuesta_texto': value,
      }, public: widget.publicAccess);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(CaleaSurveyService.clean(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      for (final entry in _texts.entries)
        await _save(entry.key, entry.value.text.trim(), 'texto');
      final result = await CaleaSurveyService.finish(
        '${_attempt!['uuid']}',
        public: widget.publicAccess,
      );
      _terminal = true;
      _timer?.cancel();
      if (!mounted) return;
      final passed = result['aprobado'] == true;
      final score = result['calificacion'];
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: Icon(
            passed ? Icons.workspace_premium : Icons.fact_check_outlined,
            size: 52,
            color: passed ? const Color(0xFFC59D2A) : Colors.blueGrey,
          ),
          title: Text(passed ? 'Encuesta aprobada' : 'Encuesta finalizada'),
          content: Text(
            'Calificación: $score/100\nTu resultado quedó guardado y auditado.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = CaleaSurveyService.clean(e);
        });
    }
  }

  Future<void> _cancel({bool silent = false}) async {
    if (_terminal || _attempt == null) return;
    try {
      await CaleaSurveyService.cancel(
        '${_attempt!['uuid']}',
        public: widget.publicAccess,
      );
    } catch (_) {}
    _terminal = true;
    _timer?.cancel();
    if (!silent && mounted) Navigator.pop(context, true);
  }

  Future<void> _askCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Cancelar este intento?'),
        content: const Text(
          'Se cerrará de forma definitiva y necesitarás autorización de un administrador para volver a realizarlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar encuesta'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar intento'),
          ),
        ],
      ),
    );
    if (ok == true) await _cancel();
  }

  Future<void> _expire() async {
    await _cancel(silent: true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Tiempo agotado'),
        content: const Text(
          'El intento expiró. Tus respuestas guardadas se conservaron, pero necesitarás una reautorización para repetir la encuesta.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_busy && _attempt == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_attempt == null)
      return Scaffold(
        appBar: AppBar(title: const Text('Encuesta CALEA')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error ?? 'No fue posible abrir la encuesta.'),
          ),
        ),
      );
    final survey = Map<String, dynamic>.from(_attempt!['encuesta'] as Map);
    final questions = (survey['preguntas'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final seconds = _remaining.inSeconds.clamp(0, 999999);
    final clock =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return PopScope(
      canPop: _terminal,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askCancel();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF102A43),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${survey['titulo']}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Intento protegido',
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: seconds < 60
                    ? Colors.red.shade700
                    : const Color(0xFF245B78),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                clock,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              onPressed: _askCancel,
              tooltip: 'Cancelar intento',
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No cierres ni abandones esta pantalla. Salir o cambiar de aplicación cancela el intento.',
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ...questions.asMap().entries.map(
              (entry) => _question(entry.key, entry.value),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _finish,
              icon: const Icon(Icons.task_alt),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Text(
                  'Entregar encuesta',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _question(int index, Map<String, dynamic> q) {
    final id = int.parse('${q['id']}');
    final type = '${q['tipo']}';
    return Card(
      margin: const EdgeInsets.only(top: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PREGUNTA ${index + 1}',
              style: const TextStyle(
                color: Color(0xFF997300),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${q['texto']}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            if (type == 'opcion_unica')
              ...(q['opciones'] as List? ?? const []).map((raw) {
                final o = Map<String, dynamic>.from(raw as Map);
                final oid = int.parse('${o['id']}');
                return RadioListTile<int>(
                  value: oid,
                  groupValue: _answers[id] is int
                      ? _answers[id] as int
                      : int.tryParse('${_answers[id]}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('${o['texto']}'),
                  onChanged: (v) {
                    if (v != null) _save(id, v, type);
                  },
                );
              })
            else
              TextField(
                controller: _texts.putIfAbsent(
                  id,
                  () => TextEditingController(text: '${_answers[id] ?? ''}'),
                ),
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Tu respuesta',
                  border: OutlineInputBorder(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
