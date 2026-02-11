import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';

class LesionadoEditScreen extends StatefulWidget {
  const LesionadoEditScreen({super.key});

  @override
  State<LesionadoEditScreen> createState() => _LesionadoEditScreenState();
}

class _LesionadoEditScreenState extends State<LesionadoEditScreen> {
  static const String _baseUrl = 'https://seguridadvial-mich.com/api';

  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;

  int _hechoId = 0;
  Map<String, dynamic>? _item;

  // ===== Campos reales del backend =====
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

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  int? _toIntOrNull(String v) {
    final t = v.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  bool _toBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    if (s == '1' || s == 'true' || s == 'si' || s == 'sí') return true;
    if (s == '0' || s == 'false' || s == 'no') return false;
    return fallback;
  }

  Uri _putUri(int hechoId, int lesionadoId) {
    return Uri.parse('$_baseUrl/hechos/$hechoId/lesionados/$lesionadoId');
  }

  void _hydrateFromItem(Map<String, dynamic> it) {
    _nombreCtrl.text = (it['nombre'] ?? '').toString();
    _edadCtrl.text = (it['edad'] == null) ? '' : it['edad'].toString();

    final sexo = it['sexo'];
    _sexo = (sexo == null || sexo.toString().trim().isEmpty)
        ? null
        : sexo.toString();

    final tl = (it['tipo_lesion'] ?? '').toString();
    if (tl == 'Leve' ||
        tl == 'Moderada' ||
        tl == 'Grave' ||
        tl == 'Fallecido') {
      _tipoLesion = tl;
    } else {
      _tipoLesion = 'Leve';
    }

    _hospitalizado = _toBool(it['hospitalizado'], fallback: false);
    _hospitalCtrl.text = (it['hospital'] ?? '').toString();

    _atencionEnSitio = _toBool(it['atencion_en_sitio'], fallback: true);
    _ambulanciaCtrl.text = (it['ambulancia'] ?? '').toString();
    _paramedicoCtrl.text = (it['paramedico'] ?? '').toString();

    _observacionesCtrl.text = (it['observaciones'] ?? '').toString();
  }

  void _initFromArgsOnce() {
    if (_item != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;

    // Esperado:
    // arguments: {'hechoId': 123, 'item': { ...lesionado... }}
    if (args is Map) {
      final hechoIdAny = args['hechoId'];
      _hechoId = int.tryParse((hechoIdAny ?? '0').toString()) ?? 0;

      final itemAny = args['item'];
      if (itemAny is Map) {
        _item = Map<String, dynamic>.from(itemAny);
      } else {
        // Por si mandaste directo el item
        _item = Map<String, dynamic>.from(args);
      }

      if (_item != null) {
        _hydrateFromItem(_item!);
      }

      setState(() {});
      return;
    }

    setState(() {});
  }

  Future<void> _guardar() async {
    if (_guardando) return;

    final it = _item;
    final lesionadoId = int.tryParse((it?['id'] ?? '0').toString()) ?? 0;

    if (_hechoId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No llegó hechoId para editar lesionado.'),
        ),
      );
      return;
    }

    if (lesionadoId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se recibió el ID del lesionado.')),
      );
      return;
    }

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _guardando = true);

    try {
      final body = <String, dynamic>{
        'nombre': _nombreCtrl.text.trim(),
        if (_toIntOrNull(_edadCtrl.text) != null)
          'edad': _toIntOrNull(_edadCtrl.text),
        if (_sexo != null && _sexo!.trim().isNotEmpty) 'sexo': _sexo,

        'tipo_lesion': _tipoLesion,

        'hospitalizado': _hospitalizado,
        if (_hospitalizado && _hospitalCtrl.text.trim().isNotEmpty)
          'hospital': _hospitalCtrl.text.trim(),
        if (!_hospitalizado) 'hospital': null, // limpia si apagaste switch

        'atencion_en_sitio': _atencionEnSitio,
        if (_ambulanciaCtrl.text.trim().isNotEmpty)
          'ambulancia': _ambulanciaCtrl.text.trim(),
        if (_paramedicoCtrl.text.trim().isNotEmpty)
          'paramedico': _paramedicoCtrl.text.trim(),

        if (_observacionesCtrl.text.trim().isNotEmpty)
          'observaciones': _observacionesCtrl.text.trim(),
      };

      final res = await http.put(
        _putUri(_hechoId, lesionadoId),
        headers: await _headers(),
        body: jsonEncode(body),
      );

      if (res.statusCode != 200 && res.statusCode != 204) {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesionado actualizado correctamente')),
      );

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
    _initFromArgsOnce();

    final lesionadoId = (_item?['id'] ?? 0).toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text('Editar lesionado #$lesionadoId (Hecho #$_hechoId)'),
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            children: [
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
                              if (n < 0 || n > 120)
                                return 'Edad fuera de rango';
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
                label: Text(_guardando ? 'Guardando…' : 'Guardar cambios'),
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
            color: Colors.black.withOpacity(.06),
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
