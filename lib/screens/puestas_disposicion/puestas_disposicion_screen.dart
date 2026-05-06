import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/puestas_disposicion_service.dart';

class PuestasDisposicionScreen extends StatefulWidget {
  const PuestasDisposicionScreen({super.key});

  @override
  State<PuestasDisposicionScreen> createState() =>
      _PuestasDisposicionScreenState();
}

class _PuestasDisposicionScreenState extends State<PuestasDisposicionScreen> {
  final _service = PuestasDisposicionService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _service.index(anio: DateTime.now().year);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudieron cargar las puestas.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _text(dynamic value, [String fallback = '-']) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _nestedName(Map<String, dynamic> item, String key) {
    final nested = item[key];
    if (nested is Map) {
      return _text(nested['nombre']);
    }
    return '-';
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse((value ?? '').toString());
    if (parsed == null) return _text(value);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year}';
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  int _hechoId(Map<String, dynamic> item) {
    final direct = _toInt(item['hecho_id']);
    if (direct > 0) return direct;

    final nested = item['hecho'];
    if (nested is Map) return _toInt(nested['id'] ?? nested['hecho_id']);

    return 0;
  }

  Future<void> _openShow(Map<String, dynamic> item) async {
    final id = _toInt(item['id']);
    if (id <= 0) return;

    await Navigator.of(context).pushNamed(
      AppRoutes.puestasDisposicionShow,
      arguments: {'puesta_disposicion_id': id},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Puestas a disposición'),
        backgroundColor: Colors.blue,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(
            context,
          ).pushNamed(AppRoutes.puestasDisposicionCreate);
          if (created == true) {
            await _load();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva puesta'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Builder(
          builder: (context) {
            if (_loading && _items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_error != null && _items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Reintentar'),
                  ),
                ],
              );
            }

            if (_items.isEmpty) {
              return const Center(child: Text('Sin puestas registradas.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _items[index];
                final numero = _text(item['numero_puesta']);
                final anio = _text(item['anio']);
                final hechoId = _hechoId(item);
                final unidad = _nestedName(item, 'unidad') == '-'
                    ? _text(item['area'])
                    : _nestedName(item, 'unidad');

                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openShow(item),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Puesta $numero/$anio',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              Text(
                                _date(item['fecha_puesta']),
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_text(item['tipo_puesta'])} · ${_text(item['motivo'])}',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            unidad,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          if (hechoId > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Hecho vinculado: #$hechoId',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            _text(item['nombre_policia'], 'Sin policia'),
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
