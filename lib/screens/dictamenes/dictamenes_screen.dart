import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/dictamenes_service.dart';
import '../../main.dart' show AppRoutes;

class DictamenesScreen extends StatefulWidget {
  const DictamenesScreen({super.key});

  @override
  State<DictamenesScreen> createState() => _DictamenesScreenState();
}

class _DictamenesScreenState extends State<DictamenesScreen> {
  final _svc = DictamenesService();

  bool _loading = true;
  bool _busy = false;
  String? _error;

  // data index()
  int _anioActual = DateTime.now().year;
  int _anioSeleccionado = DateTime.now().year;
  List<int> _anios = <int>[];

  // lista mostrada (puede venir de index o de buscar)
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  // búsqueda
  final TextEditingController _q = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadIndex(resetYear: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _runBusy(Future<void> Function() fn) async {
    if (!mounted) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _toInt(dynamic v, {int def = 0}) {
    if (v == null) return def;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? def;
  }

  List<int> _toIntList(dynamic v) {
    if (v is List) {
      return v.map((e) => _toInt(e, def: 0)).where((x) => x > 0).toList();
    }
    return <int>[];
  }

  List<Map<String, dynamic>> _toMapList(dynamic v) {
    if (v is List) {
      return v
          .where((e) => e is Map)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<void> _refreshRespectingSearch() async {
    final q = _q.text.trim();
    if (q.isNotEmpty) {
      await _searchNow(q);
    } else {
      await _loadIndex(resetYear: false);
    }
  }

  Future<void> _loadIndex({required bool resetYear}) async {
    setState(() {
      _loading = true;
      _error = null;
      _isSearching = false;
      if (resetYear) _anioSeleccionado = DateTime.now().year;
    });

    try {
      final res = await _svc.index(anio: _anioSeleccionado);

      if (!mounted) return;
      setState(() {
        _anioActual = _toInt(res['anio_actual'], def: DateTime.now().year);
        _anioSeleccionado = _toInt(
          res['anio_seleccionado'],
          def: _anioSeleccionado,
        );

        _anios = _toIntList(res['anios']);
        if (_anios.isEmpty) {
          _anios = <int>{_anioActual, _anioSeleccionado}.toList()
            ..sort((a, b) => b.compareTo(a));
        }

        _items = _toMapList(res['data']);
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

  Future<void> _searchNow(String text) async {
    final q = text.trim();

    // Si borró la búsqueda, vuelve al index normal
    if (q.isEmpty) {
      setState(() => _isSearching = false);
      await _loadIndex(resetYear: false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _isSearching = true;
    });

    try {
      final res = await _svc.buscar(q: q, anio: _anioSeleccionado);

      if (!mounted) return;
      setState(() {
        _items = _toMapList(res['data']);
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

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _searchNow(text);
    });
  }

  Future<void> _changeYear(int year) async {
    if (_anioSeleccionado == year) return;

    setState(() {
      _anioSeleccionado = year;
    });

    // respeta si está buscando
    final q = _q.text.trim();
    if (q.isNotEmpty) {
      await _searchNow(q);
    } else {
      await _loadIndex(resetYear: false);
    }
  }

  void _openItem(Map<String, dynamic> d) {
    final id = _toInt(d['id'], def: 0);
    if (id <= 0) return;

    Navigator.pushNamed(
      context,
      AppRoutes.dictamenesShow,
      arguments: {'dictamenId': id},
    );
  }

  Future<void> _goCreate() async {
    if (_busy) return;

    final res = await Navigator.pushNamed(
      context,
      AppRoutes.dictamenesCreate,
      // si quieres pasar algo al create, aquí va:
      // arguments: {'anio': _anioSeleccionado},
    );

    // si el create hace: Navigator.pop(context, true);
    if (res == true) {
      await _refreshRespectingSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _items.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictámenes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: (_busy)
                ? null
                : () => _runBusy(_refreshRespectingSearch),
            icon: const Icon(Icons.refresh),
          ),

          // Opcional: botón para abrir la pantalla dedicada de búsqueda
          // (si ya la tienes en rutas)
          IconButton(
            tooltip: 'Búsqueda avanzada',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.dictamenesBuscar);
            },
            icon: const Icon(Icons.manage_search),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? _errorView()
          : RefreshIndicator(
              onRefresh: _refreshRespectingSearch,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _topBar(count: count),
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          _isSearching ? 'Sin resultados…' : 'Sin dictámenes…',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  else
                    ..._items.map((d) => _itemCard(d)),
                  const SizedBox(height: 10),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goCreate,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
    );
  }

  Widget _topBar({required int count}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month),
              const SizedBox(width: 10),
              const Text('Año', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _anioSeleccionado,
                  items: _anios.map((y) {
                    return DropdownMenuItem<int>(
                      value: y,
                      child: Text(
                        y == _anioActual ? '$y (actual)' : '$y',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    _changeYear(v);
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _q,
            onChanged: (t) {
              _onSearchChanged(t);
              setState(() {}); // para refrescar suffixIcon en vivo
            },
            decoration: InputDecoration(
              labelText: 'Buscar',
              hintText: 'Nombre policía, MP, área o número…',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: (_q.text.trim().isEmpty)
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar',
                      onPressed: () {
                        _q.clear();
                        _searchNow('');
                        setState(() {}); // refresca suffixIcon
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.list_alt, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mostrando $count dictámenes • Año $_anioSeleccionado',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> d) {
    final numero = _s(d['numero_dictamen']);
    final anio = _s(d['anio']);
    final nombrePolicia = _s(d['nombre_policia']);
    final nombreMp = _s(d['nombre_mp']);
    final area = _s(d['area']);
    final hasPdf = _s(d['archivo_dictamen']).isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _openItem(d),
        leading: CircleAvatar(
          child: Text(
            numero.isEmpty ? '—' : numero,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        title: Text(
          'Dictamen $numero/$anio',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          [
            if (nombrePolicia.isNotEmpty) 'Policía: $nombrePolicia',
            if (nombreMp.isNotEmpty) 'MP: $nombreMp',
            if (area.isNotEmpty) 'Área: $area',
          ].join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(hasPdf ? Icons.picture_as_pdf : Icons.description_outlined),
            const SizedBox(height: 4),
            Text(
              hasPdf ? 'PDF' : '—',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 10),
            Text(_error ?? 'Error', textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _loadIndex(resetYear: false),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
