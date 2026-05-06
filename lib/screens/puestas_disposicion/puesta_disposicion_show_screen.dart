import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/puestas_disposicion_service.dart';

class PuestaDisposicionShowScreen extends StatefulWidget {
  const PuestaDisposicionShowScreen({super.key});

  @override
  State<PuestaDisposicionShowScreen> createState() =>
      _PuestaDisposicionShowScreenState();
}

class _PuestaDisposicionShowScreenState
    extends State<PuestaDisposicionShowScreen> {
  final _service = PuestasDisposicionService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _puesta;
  bool _bootstrapped = false;

  int _idFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;

    int parse(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    final direct = parse(args);
    if (direct > 0) return direct;

    if (args is Map) {
      final candidates = [
        args['puesta_disposicion_id'],
        args['puestaDisposicionId'],
        args['id'],
      ];

      for (final candidate in candidates) {
        final id = parse(candidate);
        if (id > 0) return id;
      }
    }

    return 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    _load();
  }

  Future<void> _load() async {
    final id = _idFromArgs();
    if (id <= 0) {
      setState(() {
        _loading = false;
        _error = 'Falta puesta_disposicion_id';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _service.show(id);
      if (!mounted) return;
      setState(() {
        _puesta = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la puesta.\n$e';
        _loading = false;
      });
    }
  }

  String _text(dynamic value, [String fallback = '-']) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _nestedName(String key) {
    final nested = _puesta?[key];
    if (nested is Map) {
      return _text(
        nested['nombre'] ??
            nested['name'] ??
            nested['nombre_completo'] ??
            nested['descripcion'],
      );
    }
    return _text(nested);
  }

  String _date(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year}';
  }

  String _boolText(dynamic value) {
    final text = (value ?? '').toString().trim().toLowerCase();
    if (text == '1' || text == 'true' || text == 'si' || text == 'sí') {
      return 'Si';
    }
    if (text == '0' || text == 'false' || text == 'no') return 'No';
    return _text(value);
  }

  List<Map<String, dynamic>> _list(String key) {
    final value = _puesta?[key];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (value is Map && value['data'] is List) {
      return (value['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return <Map<String, dynamic>>[];
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  int _hechoId(Map<String, dynamic> p) {
    final direct = _toInt(p['hecho_id']);
    if (direct > 0) return direct;

    final nested = p['hecho'];
    if (nested is Map) {
      return _toInt(nested['id'] ?? nested['hecho_id']);
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final p = _puesta ?? <String, dynamic>{};
    final numero = _text(p['numero_puesta']);
    final anio = _text(p['anio']);
    final hechoId = _hechoId(p);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          numero == '-' ? 'Detalle de puesta' : 'Puesta $numero/$anio',
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              else if (_puesta == null)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text('Sin datos.')),
                )
              else ...[
                _card(
                  title: 'Resumen',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('ID', _text(p['id'])),
                      _kv('Numero', numero),
                      _kv('Anio', anio),
                      if (hechoId > 0) _kv('Hecho vinculado', '#$hechoId'),
                      _kv('Tipo', _text(p['tipo_puesta'])),
                      _kv('Motivo', _text(p['motivo'])),
                      _kv('Estatus', _text(p['estatus'])),
                      if (hechoId > 0)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.accidentesShow,
                              arguments: {'hechoId': hechoId},
                            ),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Abrir hecho'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Fecha y lugar',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('Fecha', _date(p['fecha_puesta'])),
                      _kv('Hora', _text(p['hora_puesta'])),
                      _kv('Lugar', _text(p['lugar_puesta'])),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Registro',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(
                        'Unidad',
                        _nestedName('unidad') == '-'
                            ? _text(p['area'])
                            : _nestedName('unidad'),
                      ),
                      _kv('Delegacion', _nestedName('delegacion')),
                      _kv('Destacamento', _nestedName('destacamento')),
                      _kv('Capturo', _nestedName('creador')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Autoridad',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('Policia', _text(p['nombre_policia'])),
                      _kv('MP', _text(p['nombre_mp'])),
                      _kv('Autoridad', _text(p['autoridad_receptora'])),
                      _kv('Carpeta', _text(p['carpeta_investigacion'])),
                      _kv('Oficio', _text(p['oficio'])),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Contenido',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionText('Narrativa', p['narrativa']),
                      _sectionText('Observaciones', p['observaciones']),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Personas',
                  child: _detailList(
                    emptyText: 'Sin personas registradas.',
                    items: _list('personas'),
                    titleBuilder: (item) => _text(item['nombre_completo']),
                    linesBuilder: (item) => [
                      if (_text(item['alias'], '').isNotEmpty)
                        'Alias: ${_text(item['alias'])}',
                      'Calidad: ${_text(item['calidad'])}',
                      if (_text(item['edad'], '').isNotEmpty)
                        'Edad: ${_text(item['edad'])}',
                      if (_text(item['sexo'], '').isNotEmpty)
                        'Sexo: ${_text(item['sexo'])}',
                      if (_text(item['delito_o_motivo'], '').isNotEmpty)
                        'Motivo: ${_text(item['delito_o_motivo'])}',
                      'Orden de aprehension: ${_boolText(item['orden_aprehension'])}',
                      if (_text(item['mandamiento_judicial'], '').isNotEmpty)
                        'Mandamiento: ${_text(item['mandamiento_judicial'])}',
                      if (_text(item['observaciones'], '').isNotEmpty)
                        'Obs: ${_text(item['observaciones'])}',
                      if (_text(
                        item['archivo_uso_fuerza_url'] ??
                            item['uso_fuerza_pdf_url'] ??
                            item['archivo_uso_fuerza'],
                        '',
                      ).isNotEmpty)
                        'PDF uso de fuerza: cargado',
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Vehiculos',
                  child: _detailList(
                    emptyText: 'Sin vehiculos registrados.',
                    items: _list('vehiculos'),
                    titleBuilder: (item) {
                      final placas = _text(item['placas'], '').trim();
                      final tipo = _text(item['tipo'], '').trim();
                      if (placas.isNotEmpty && tipo.isNotEmpty) {
                        return '$placas · $tipo';
                      }
                      return placas.isNotEmpty ? placas : _text(item['tipo']);
                    },
                    linesBuilder: (item) => [
                      [
                        _text(item['marca'], ''),
                        _text(item['submarca'], ''),
                        _text(item['modelo'], ''),
                      ].where((part) => part.trim().isNotEmpty).join(' '),
                      if (_text(item['color'], '').isNotEmpty)
                        'Color: ${_text(item['color'])}',
                      if (_text(item['serie'], '').isNotEmpty)
                        'Serie: ${_text(item['serie'])}',
                      'Calidad: ${_text(item['calidad'])}',
                      if (_text(item['motivo_relacion'], '').isNotEmpty)
                        'Motivo: ${_text(item['motivo_relacion'])}',
                      'Reporte de robo: ${_boolText(item['con_reporte_robo'])}',
                      if (_text(item['numero_reporte_robo'], '').isNotEmpty)
                        'Reporte: ${_text(item['numero_reporte_robo'])}',
                      if (_text(item['observaciones'], '').isNotEmpty)
                        'Obs: ${_text(item['observaciones'])}',
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Objetos',
                  child: _detailList(
                    emptyText: 'Sin objetos registrados.',
                    items: _list('objetos'),
                    titleBuilder: (item) => _text(item['tipo_objeto']),
                    linesBuilder: (item) => [
                      if (_text(item['descripcion'], '').isNotEmpty)
                        _text(item['descripcion']),
                      if (_text(item['cantidad'], '').isNotEmpty)
                        'Cantidad: ${_text(item['cantidad'])}',
                      if (_text(item['unidad_medida'], '').isNotEmpty)
                        'Unidad: ${_text(item['unidad_medida'])}',
                      if (_text(item['cadena_custodia'], '').isNotEmpty)
                        'Cadena: ${_text(item['cadena_custodia'])}',
                      if (_text(item['observaciones'], '').isNotEmpty)
                        'Obs: ${_text(item['observaciones'])}',
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    final clean = value.trim().isEmpty ? '-' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(text: clean),
          ],
        ),
      ),
    );
  }

  Widget _sectionText(String title, dynamic value) {
    final text = _text(value, '').trim();
    if (text.isEmpty) return const Text('-');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.blue.shade900,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(text),
        ],
      ),
    );
  }

  Widget _detailList({
    required String emptyText,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) titleBuilder,
    required List<String> Function(Map<String, dynamic>) linesBuilder,
  }) {
    if (items.isEmpty) return Text(emptyText);

    return Column(
      children: items.map((item) {
        final title = titleBuilder(item).trim();
        final lines = linesBuilder(item)
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty && line != '-')
            .toList();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty ? 'Registro' : title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  lines.join('\n'),
                  style: TextStyle(color: Colors.grey.shade800, height: 1.35),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
