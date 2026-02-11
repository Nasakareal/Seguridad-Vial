import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/dictamenes_service.dart';
import '../../main.dart' show AppRoutes;

class DictamenesBusquedaScreen extends StatefulWidget {
  const DictamenesBusquedaScreen({super.key});

  @override
  State<DictamenesBusquedaScreen> createState() =>
      _DictamenesBusquedaScreenState();
}

class _DictamenesBusquedaScreenState extends State<DictamenesBusquedaScreen> {
  final _svc = DictamenesService();

  final TextEditingController _q = TextEditingController();

  bool _loading = false;
  String? _error;

  int? _anio; // null = todos
  List<int> _anios = [];

  List<Map<String, dynamic>> _items = [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadAnios();
      await _search(); // primera carga
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _loadAnios() async {
    try {
      // Re-usamos el index para obtener "anios" y "anio_actual"
      final res = await _svc.index(anio: null);

      final listRaw = (res['anios'] as List?) ?? const [];
      final years = <int>[];
      for (final y in listRaw) {
        final v = (y is int) ? y : int.tryParse('$y');
        if (v != null) years.add(v);
      }

      final current = (res['anio_actual'] is int)
          ? (res['anio_actual'] as int)
          : int.tryParse('${res['anio_actual']}');

      if (!mounted) return;
      setState(() {
        _anios = years;

        // si hay años, por default selecciona el actual si existe en la lista
        if (current != null && years.contains(current)) {
          _anio = current;
        }
      });
    } catch (_) {
      // si falla, no pasa nada: el select de años simplemente no aparece
    }
  }

  Future<void> _search() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _svc.buscar(q: _q.text.trim(), anio: _anio);

      final raw = (res['data'] as List?) ?? const [];
      final items = raw
          .where((e) => e is Map)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search();
    });
  }

  int _toInt(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;

  String _safe(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '—' : s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar dictámenes'),
        actions: [
          IconButton(
            tooltip: 'Limpiar',
            onPressed: () {
              _q.clear();
              _search();
            },
            icon: const Icon(Icons.clear),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _search,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _search,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _filtersCard(),
              const SizedBox(height: 12),

              if (_loading) ...[
                const SizedBox(height: 18),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 18),
              ] else if (_error != null) ...[
                _errorCard(_error!),
              ] else if (_items.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: Text('Sin resultados…')),
                ),
              ] else ...[
                ..._items.map((d) => _dictamenTile(d)),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filtersCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(.04),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.search),
              SizedBox(width: 8),
              Text(
                'Filtros',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _q,
            onChanged: _onQueryChanged,
            decoration: const InputDecoration(
              labelText: 'Buscar',
              hintText: 'Policía, MP, área o número de dictamen…',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
          ),

          const SizedBox(height: 12),

          if (_anios.isNotEmpty)
            DropdownButtonFormField<int?>(
              value: _anio,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('(Todos los años)'),
                ),
                ..._anios.map(
                  (y) => DropdownMenuItem<int?>(
                    value: y,
                    child: Text(y.toString()),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() => _anio = v);
                _search();
              },
              decoration: const InputDecoration(
                labelText: 'Año',
                border: OutlineInputBorder(),
              ),
            ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _search,
              icon: const Icon(Icons.manage_search),
              label: const Text('Buscar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dictamenTile(Map<String, dynamic> d) {
    final id = _toInt(d['id']);
    final numero = _safe(d['numero_dictamen']);
    final anio = _safe(d['anio']);
    final policia = _safe(d['nombre_policia']);
    final mp = _safe(d['nombre_mp']);
    final area = _safe(d['area']);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(
          'DICTAMEN $numero/$anio',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          [
            policia != '—' ? 'POL: $policia' : '',
            mp != '—' ? 'MP: $mp' : '',
            area != '—' ? area : '',
          ].where((s) => s.trim().isNotEmpty).join(' • '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (id <= 0) return;

          Navigator.pushNamed(
            context,
            AppRoutes.dictamenesShow,
            arguments: {'dictamenId': id},
          );
        },
      ),
    );
  }

  Widget _errorCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _loading ? null : _search,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
