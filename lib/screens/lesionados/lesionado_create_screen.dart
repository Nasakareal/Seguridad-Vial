import 'package:flutter/material.dart';

import '../../services/offline_sync_service.dart';

class LesionadoCreateScreen extends StatefulWidget {
  const LesionadoCreateScreen({super.key});

  @override
  State<LesionadoCreateScreen> createState() => _LesionadoCreateScreenState();
}

class _LesionadoCreateScreenState extends State<LesionadoCreateScreen> {
  static const String _baseUrl = 'https://seguridadvial-mich.com/api';

  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;
  bool _draftHydrated = false;

  // ===== Campos que TU backend espera =====
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _edadCtrl = TextEditingController();
  String? _sexo; // Masculino | Femenino | Otro

  String _tipoLesion = 'Leve'; // Leve | Moderada | Grave | Fallecido
  bool _hospitalizado = false;
  final TextEditingController _hospitalCtrl = TextEditingController();

  bool _atencionEnSitio = true;
  final TextEditingController _ambulanciaCtrl = TextEditingController();
  final TextEditingController _paramedicoCtrl = TextEditingController();

  final TextEditingController _observacionesCtrl = TextEditingController();

  int _hechoIdFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['hechoId'] != null) {
      return int.tryParse(args['hechoId'].toString()) ?? 0;
    }
    return 0;
  }

  String? _hechoClientUuidFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['hechoClientUuid'] != null) {
      final value = args['hechoClientUuid'].toString().trim();
      return value.isEmpty ? null : value;
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draftHydrated) return;
    _draftHydrated = true;
    _hydrateDraftFromArgs();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _edadCtrl.dispose();
    _hospitalCtrl.dispose();
    _ambulanciaCtrl.dispose();
    _paramedicoCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  int? _toIntOrNull(String v) {
    final t = v.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Uri _createUri() {
    return Uri.parse('$_baseUrl/lesionados');
  }

  void _hydrateDraftFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map || args['offlineDraft'] is! Map) return;

    final draft = Map<String, dynamic>.from(args['offlineDraft'] as Map);
    final body = draft['body'] is Map
        ? Map<String, dynamic>.from(draft['body'] as Map)
        : const <String, dynamic>{};

    _nombreCtrl.text = (body['nombre'] ?? '').toString();
    _edadCtrl.text = (body['edad'] ?? '').toString();

    final sexo = (body['sexo'] ?? '').toString().trim();
    _sexo = sexo.isEmpty ? null : sexo;

    final tipoLesion = (body['tipo_lesion'] ?? '').toString().trim();
    if (tipoLesion.isNotEmpty) {
      _tipoLesion = tipoLesion;
    }

    _hospitalizado = _toBool(body['hospitalizado'], fallback: false);
    _hospitalCtrl.text = (body['hospital'] ?? '').toString();

    _atencionEnSitio = _toBool(body['atencion_en_sitio'], fallback: true);
    _ambulanciaCtrl.text = (body['ambulancia'] ?? '').toString();
    _paramedicoCtrl.text = (body['paramedico'] ?? '').toString();
    _observacionesCtrl.text = (body['observaciones'] ?? '').toString();
  }

  bool _toBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    if (s == '1' || s == 'true' || s == 'si' || s == 'sí') return true;
    if (s == '0' || s == 'false' || s == 'no') return false;
    return fallback;
  }

  Future<void> _guardar() async {
    if (_guardando) return;

    final hechoId = _hechoIdFromArgs(context);
    final hechoClientUuid = _hechoClientUuidFromArgs(context);
    final normalizedHechoClientUuid = (hechoClientUuid ?? '').trim();
    if (hechoId <= 0 && normalizedHechoClientUuid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No llegó el contexto del hecho para crear lesionado.'),
        ),
      );
      return;
    }

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _guardando = true);

    final routeArgs = ModalRoute.of(context)?.settings.arguments;

    try {
      final draftOpId = routeArgs is Map
          ? (routeArgs['offlineDraft'] is Map
                ? (routeArgs['offlineDraft'] as Map)['id']
                : null)
          : null;
      final clientUuid = (draftOpId ?? '').toString().trim().isNotEmpty
          ? (draftOpId ?? '').toString().trim()
          : OfflineSyncService.newClientUuid();
      final body = <String, dynamic>{
        'client_uuid': clientUuid,
        if (hechoId > 0) 'hecho_id': hechoId,
        if (hechoId <= 0 && normalizedHechoClientUuid.isNotEmpty)
          'hecho_client_uuid': normalizedHechoClientUuid,
        'nombre': _nombreCtrl.text.trim(),
        if (_toIntOrNull(_edadCtrl.text) != null)
          'edad': _toIntOrNull(_edadCtrl.text),
        if (_sexo != null && _sexo!.trim().isNotEmpty) 'sexo': _sexo,

        'tipo_lesion': _tipoLesion,
        'hospitalizado': _hospitalizado,
        if (_hospitalizado && _hospitalCtrl.text.trim().isNotEmpty)
          'hospital': _hospitalCtrl.text.trim(),

        'atencion_en_sitio': _atencionEnSitio,
        if (_ambulanciaCtrl.text.trim().isNotEmpty)
          'ambulancia': _ambulanciaCtrl.text.trim(),
        if (_paramedicoCtrl.text.trim().isNotEmpty)
          'paramedico': _paramedicoCtrl.text.trim(),

        if (_observacionesCtrl.text.trim().isNotEmpty)
          'observaciones': _observacionesCtrl.text.trim(),
      };

      final result = await OfflineSyncService.submitJson(
        label: 'Lesionado',
        method: 'POST',
        uri: _createUri(),
        body: body,
        requestId: clientUuid,
        dependsOnOperationId: hechoId > 0 ? null : normalizedHechoClientUuid,
        successCodes: const <int>{200, 201},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hechoId = _hechoIdFromArgs(context);
    final hechoClientUuid = _hechoClientUuidFromArgs(context);
    final pendingParent =
        hechoId <= 0 && (hechoClientUuid?.trim().isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text(
          pendingParent
              ? 'Nuevo lesionado (Hecho pendiente)'
              : 'Nuevo lesionado (Hecho #$hechoId)',
        ),
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            children: [
              if (pendingParent)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Text(
                    'Este hecho todavía no tiene ID de servidor. El lesionado se guardará con el UUID local del hecho y se sincronizará cuando el hecho padre suba primero.',
                  ),
                ),
              _CardShell(
                title: 'Datos del lesionado',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nombreCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'El nombre es obligatorio';
                        if (t.length < 3) return 'Nombre demasiado corto';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _edadCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Edad (opcional)',
                              prefixIcon: Icon(Icons.numbers),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return null;
                              final n = int.tryParse(t);
                              if (n == null) return 'Edad inválida';
                              if (n < 0 || n > 120) {
                                return 'Edad fuera de rango';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _sexo,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Sexo (opcional)',
                              prefixIcon: Icon(Icons.wc),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: null,
                                child: Text('Sin especificar'),
                              ),
                              DropdownMenuItem(
                                value: 'Masculino',
                                child: Text('Masculino'),
                              ),
                              DropdownMenuItem(
                                value: 'Femenino',
                                child: Text('Femenino'),
                              ),
                              DropdownMenuItem(
                                value: 'Otro',
                                child: Text('Otro'),
                              ),
                            ],
                            onChanged: (v) => setState(() => _sexo = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _tipoLesion,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de lesión',
                        prefixIcon: Icon(Icons.healing),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Leve', child: Text('Leve')),
                        DropdownMenuItem(
                          value: 'Moderada',
                          child: Text('Moderada'),
                        ),
                        DropdownMenuItem(value: 'Grave', child: Text('Grave')),
                        DropdownMenuItem(
                          value: 'Fallecido',
                          child: Text('Fallecido'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _tipoLesion = v ?? 'Leve'),
                    ),
                    const SizedBox(height: 12),

                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hospitalizado'),
                      value: _hospitalizado,
                      onChanged: (v) => setState(() => _hospitalizado = v),
                    ),
                    if (_hospitalizado) ...[
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _hospitalCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Hospital (opcional)',
                          prefixIcon: Icon(Icons.local_hospital),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Atención en sitio'),
                      value: _atencionEnSitio,
                      onChanged: (v) => setState(() => _atencionEnSitio = v),
                    ),
                    const SizedBox(height: 6),

                    TextFormField(
                      controller: _ambulanciaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ambulancia (opcional)',
                        prefixIcon: Icon(Icons.airport_shuttle),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _paramedicoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Paramédico (opcional)',
                        prefixIcon: Icon(Icons.medical_services),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _observacionesCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones (opcional)',
                        prefixIcon: Icon(Icons.note),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(Icons.save),
                label: Text(_guardando ? 'Guardando…' : 'Guardar'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _CardShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: .06),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
