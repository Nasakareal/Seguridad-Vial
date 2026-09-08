import 'package:flutter/material.dart';
import '../../services/calea_survey_service.dart';
import 'calea_survey_attempt_screen.dart';

class CaleaSurveyPublicScreen extends StatefulWidget {
  const CaleaSurveyPublicScreen({super.key});
  @override
  State<CaleaSurveyPublicScreen> createState() =>
      _CaleaSurveyPublicScreenState();
}

class _CaleaSurveyPublicScreenState extends State<CaleaSurveyPublicScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController(),
      _name = TextEditingController(),
      _phone = TextEditingController(),
      _id = TextEditingController(),
      _email = TextEditingController();
  Map<String, dynamic>? _survey;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_code, _name, _phone, _id, _email]) c.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (_code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await CaleaSurveyService.publicSurvey(
        _code.text.trim().toUpperCase(),
      );
      if (mounted)
        setState(() {
          _survey = s;
          _busy = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = CaleaSurveyService.clean(e);
        });
    }
  }

  Future<void> _start() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final attempt = await CaleaSurveyService.publicStart(
        _code.text.trim().toUpperCase(),
        {
          'nombre': _name.text.trim(),
          'telefono': _phone.text.trim(),
          'identificador': _id.text.trim(),
          if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        },
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CaleaSurveyAttemptScreen(
            attemptUuid: '${attempt['uuid']}',
            publicAccess: true,
          ),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = CaleaSurveyService.clean(e);
        });
    }
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Campo obligatorio' : null;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F6F8),
    appBar: AppBar(
      backgroundColor: const Color(0xFF102A43),
      foregroundColor: Colors.white,
      title: const Text('Encuesta CALEA sin cuenta'),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 64,
            color: Color(0xFF245B78),
          ),
          const SizedBox(height: 12),
          const Text(
            'Acceso para participante externo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ingresa el código proporcionado por tu administrador. Tus datos quedarán vinculados al resultado.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  enabled: _survey == null,
                  decoration: const InputDecoration(
                    labelText: 'Código de encuesta',
                    prefixIcon: Icon(Icons.key),
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy || _survey != null ? null : _find,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Buscar'),
                ),
              ),
            ],
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
          if (_survey != null) ...[
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              color: const Color(0xFFFFF4D1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_survey!['titulo']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text('${_survey!['descripcion'] ?? ''}'),
                    const SizedBox(height: 8),
                    Text(
                      '${_survey!['duracion_minutos']} minutos · ${_survey!['preguntas_count']} preguntas',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 11),
            TextFormField(
              controller: _id,
              decoration: const InputDecoration(
                labelText: 'CURP, número de empleado o identificación',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 11),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 11),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo (opcional)',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Al comenzar, no podrás salir de la pantalla: abandonar o agotar el tiempo cancela el intento.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _start,
              icon: const Icon(Icons.play_arrow),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Text(
                  'Comenzar ahora',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
