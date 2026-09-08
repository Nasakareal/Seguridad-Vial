import 'package:flutter/material.dart';
import '../../services/calea_survey_service.dart';

class CaleaSurveyFormScreen extends StatefulWidget {
  const CaleaSurveyFormScreen({super.key});
  @override
  State<CaleaSurveyFormScreen> createState() => _CaleaSurveyFormScreenState();
}

class _QuestionDraft {
  final text = TextEditingController();
  final options = [TextEditingController(), TextEditingController()];
  int correct = 0;
  void dispose() {
    text.dispose();
    for (final o in options) o.dispose();
  }
}

class _CaleaSurveyFormScreenState extends State<CaleaSurveyFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(),
      _description = TextEditingController();
  final List<_QuestionDraft> _questions = [_QuestionDraft()];
  Map<String, dynamic>? _catalogs;
  int _minutes = 10, _passing = 70;
  bool _public = false, _saving = false;
  String _assignment = 'unidad';
  int? _unitId;
  final Set<int> _users = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final q in _questions) q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await CaleaSurveyService.catalogs();
      final units = c['unidades'] as List? ?? [];
      if (mounted)
        setState(() {
          _catalogs = c;
          if (units.isNotEmpty)
            _unitId = int.tryParse('${(units.first as Map)['id']}');
          if (c['alcance_global'] != true) _assignment = 'unidad';
        });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(CaleaSurveyService.clean(e))));
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_assignment == 'usuarios' && _users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un usuario.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await CaleaSurveyService.create({
        'titulo': _title.text.trim(),
        'descripcion': _description.text.trim(),
        'duracion_minutos': _minutes,
        'calificacion_minima': _passing,
        'activa': true,
        'permite_externos': _public,
        'asignacion': {
          'tipo': _assignment,
          if (_assignment == 'unidad') 'unidad_id': _unitId,
          if (_assignment == 'usuarios') 'usuarios': _users.toList(),
        },
        'preguntas': _questions
            .map(
              (q) => {
                'texto': q.text.text.trim(),
                'tipo': 'opcion_unica',
                'puntos': 1,
                'opciones': q.options
                    .asMap()
                    .entries
                    .map(
                      (e) => {
                        'texto': e.value.text.trim(),
                        'es_correcta': e.key == q.correct,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(CaleaSurveyService.clean(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final global = _catalogs?['alcance_global'] == true;
    final units = (_catalogs?['unidades'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final users = (_catalogs?['usuarios'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102A43),
        foregroundColor: Colors.white,
        title: const Text('Nueva encuesta CALEA'),
      ),
      body: _catalogs == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section('Identidad y reglas', Icons.badge_outlined, [
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Título de la encuesta',
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción e instrucciones',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _minutes,
                            decoration: const InputDecoration(
                              labelText: 'Tiempo límite',
                              border: OutlineInputBorder(),
                            ),
                            items: [5, 10, 15, 20, 30, 45, 60]
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text('$v minutos'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _minutes = v ?? 10),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _passing,
                            decoration: const InputDecoration(
                              labelText: 'Aprobación',
                              border: OutlineInputBorder(),
                            ),
                            items: [0, 60, 70, 80, 90, 100]
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text('$v%'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _passing = v ?? 70),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Permitir personas sin cuenta',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        'Se generará un código público; se pedirán nombre, teléfono e identificador.',
                      ),
                      value: _public,
                      onChanged: (v) => setState(() => _public = v),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _section('Asignación', Icons.groups_outlined, [
                    DropdownButtonFormField<String>(
                      value: _assignment,
                      decoration: const InputDecoration(
                        labelText: 'Quién debe contestar',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        if (global)
                          const DropdownMenuItem(
                            value: 'todos',
                            child: Text('Todos los usuarios'),
                          ),
                        const DropdownMenuItem(
                          value: 'unidad',
                          child: Text('Una unidad completa'),
                        ),
                        const DropdownMenuItem(
                          value: 'usuarios',
                          child: Text('Usuarios específicos'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _assignment = v ?? 'unidad'),
                    ),
                    if (_assignment == 'unidad') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _unitId,
                        decoration: const InputDecoration(
                          labelText: 'Unidad',
                          border: OutlineInputBorder(),
                        ),
                        items: units
                            .map(
                              (u) => DropdownMenuItem(
                                value: int.parse('${u['id']}'),
                                child: Text('${u['nombre']}'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _unitId = v),
                      ),
                    ],
                    if (_assignment == 'usuarios') ...[
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 240),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blueGrey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          children: users.map((u) {
                            final id = int.parse('${u['id']}');
                            return CheckboxListTile(
                              value: _users.contains(id),
                              title: Text('${u['name']}'),
                              subtitle: Text('${u['email']}'),
                              onChanged: (v) => setState(
                                () => v == true
                                    ? _users.add(id)
                                    : _users.remove(id),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 14),
                  ..._questions.asMap().entries.map(
                    (entry) => _question(entry.key, entry.value),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _questions.add(_QuestionDraft())),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar pregunta'),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.rocket_launch_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Text(
                        'Publicar y asignar encuesta',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
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
          Row(
            children: [
              Icon(icon, color: const Color(0xFF245B78)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    ),
  );
  Widget _question(int index, _QuestionDraft q) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _section('Pregunta ${index + 1}', Icons.quiz_outlined, [
        TextFormField(
          controller: q.text,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Enunciado',
            border: OutlineInputBorder(),
          ),
          validator: _required,
        ),
        const SizedBox(height: 10),
        const Text(
          'Marca la respuesta correcta:',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        ...q.options.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Radio<int>(
                  value: entry.key,
                  groupValue: q.correct,
                  onChanged: (v) => setState(() => q.correct = v ?? 0),
                ),
                Expanded(
                  child: TextFormField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      labelText: 'Opción ${entry.key + 1}',
                      border: const OutlineInputBorder(),
                    ),
                    validator: _required,
                  ),
                ),
                if (q.options.length > 2)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        entry.value.dispose();
                        q.options.removeAt(entry.key);
                        if (q.correct >= q.options.length) q.correct = 0;
                      });
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => q.options.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: const Text('Agregar opción'),
        ),
        if (_questions.length > 1)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  q.dispose();
                  _questions.removeAt(index);
                });
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar pregunta'),
            ),
          ),
      ]),
    );
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Campo obligatorio' : null;
}
