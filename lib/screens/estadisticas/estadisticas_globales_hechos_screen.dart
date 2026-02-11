import 'package:flutter/material.dart';

import '../../services/estadisticas_globales_service.dart';
import '../../main.dart' show AppRoutes;

class EstadisticasGlobalesHechosScreen extends StatefulWidget {
  const EstadisticasGlobalesHechosScreen({super.key});

  @override
  State<EstadisticasGlobalesHechosScreen> createState() =>
      _EstadisticasGlobalesHechosScreenState();
}

class _EstadisticasGlobalesHechosScreenState
    extends State<EstadisticasGlobalesHechosScreen> {
  late final EstadisticasGlobalesService _service;

  bool _loading = true;
  bool _paging = false;
  Map<String, dynamic>? _data;
  String? _error;

  int _page = 1;
  int _lastPage = 1;
  int _total = 0;

  // Filtros recibidos (desde dashboard)
  Map<String, dynamic> _filters = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _service = EstadisticasGlobalesService();

    // Espera al build para leer arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _filters = Map<String, dynamic>.from(args);
      }
      _load(reset: true);
    });
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      setState(() {
        _paging = true;
        _error = null;
      });
    }

    try {
      final params = <String, dynamic>{..._filters, 'per': 25, 'page': _page};

      final res = await _service.hechos(params: params);

      setState(() {
        _data = res;
        _loading = false;
        _paging = false;

        _page = (res['current_page'] is int)
            ? res['current_page'] as int
            : _page;
        _lastPage = (res['last_page'] is int) ? res['last_page'] as int : 1;
        _total = (res['total'] is int) ? res['total'] as int : 0;

        if (_lastPage <= 0) _lastPage = 1;
        if (_page <= 0) _page = 1;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _paging = false;
      });
    }
  }

  Future<void> _prev() async {
    if (_page <= 1) return;
    setState(() => _page--);
    await _load(reset: false);
  }

  Future<void> _next() async {
    if (_page >= _lastPage) return;
    setState(() => _page++);
    await _load(reset: false);
  }

  @override
  Widget build(BuildContext context) {
    final items = (_data?['data'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Hechos (Estadísticas)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorView()
          : RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _topInfo(items.length),
                  const SizedBox(height: 10),

                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('Sin datos…')),
                    )
                  else
                    ...items.map((e) {
                      final h = (e as Map).cast<String, dynamic>();

                      final id = h['id'];
                      final folio = (h['folio_c5i'] ?? 'Sin folio').toString();
                      final fecha = (h['fecha'] ?? '').toString();
                      final sector = (h['sector'] ?? '').toString();
                      final tipo = (h['tipo_hecho'] ?? '').toString();
                      final situacion = (h['situacion'] ?? '').toString();

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          title: Text(
                            folio,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            [
                              fecha,
                              sector,
                              situacion,
                            ].where((s) => s.trim().isNotEmpty).join(' • '),
                          ),
                          trailing: Text(tipo, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            final intId = (id is int)
                                ? id
                                : int.tryParse('$id') ?? 0;
                            if (intId <= 0) return;

                            Navigator.pushNamed(
                              context,
                              AppRoutes.accidentesShow,
                              arguments: {'hechoId': intId},
                            );
                          },
                        ),
                      );
                    }),

                  const SizedBox(height: 12),
                  _pager(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
    );
  }

  Widget _topInfo(int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mostrando $count de $_total • Página $_page de $_lastPage',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (_paging) const SizedBox(width: 10),
          if (_paging)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _pager() {
    final canPrev = !_paging && _page > 1;
    final canNext = !_paging && _page < _lastPage;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton.icon(
          onPressed: canPrev ? _prev : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Anterior'),
        ),
        OutlinedButton.icon(
          onPressed: canNext ? _next : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Siguiente'),
        ),
      ],
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _load(reset: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
