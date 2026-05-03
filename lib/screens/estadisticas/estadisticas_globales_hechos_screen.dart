import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/estadisticas_globales_service.dart';
import '../../app/routes.dart';

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
  bool _loadingDelegaciones = false;
  Map<String, dynamic>? _data;
  String? _error;

  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  int _unidadOrgId = 0;
  String _conFallecidos = '';
  int? _delegacionFiltroId;
  List<Map<String, dynamic>> _delegaciones = [];

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
        _unidadOrgId = _toInt(_filters['unidad_org_id']);
        _conFallecidos = (_filters['con_fallecidos'] ?? '').toString().trim();
        final rawDelegacionId = _toInt(_filters['delegacion_id']);
        _delegacionFiltroId = rawDelegacionId > 0 ? rawDelegacionId : null;
      }
      _loadDelegaciones();
      _load(reset: true);
    });
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  String _delegacionNombre(Map<String, dynamic> item) {
    final nombre =
        item['nombre'] ??
        item['name'] ??
        item['delegacion'] ??
        item['descripcion'] ??
        '';
    final text = nombre.toString().trim();
    return text.isEmpty ? 'Delegación ${_toInt(item['id'])}' : text;
  }

  Future<void> _loadDelegaciones() async {
    if (_loadingDelegaciones) return;
    setState(() => _loadingDelegaciones = true);

    try {
      final delegaciones = await _service.catalogoDelegaciones();
      if (!mounted) return;
      setState(() => _delegaciones = delegaciones);
    } catch (_) {
      if (!mounted) return;
      setState(() => _delegaciones = <Map<String, dynamic>>[]);
    } finally {
      if (mounted) setState(() => _loadingDelegaciones = false);
    }
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
                  _filtersPanel(),
                  const SizedBox(height: 10),
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

  Widget _filtersPanel() {
    final selected = _delegacionFiltroId ?? 0;
    final enabled =
        !_loadingDelegaciones &&
        (_unidadOrgId == 0 || _unidadOrgId == AuthService.unidadDelegacionesId);
    final items = <DropdownMenuItem<int>>[
      const DropdownMenuItem(value: 0, child: Text('(Todas)')),
    ];

    final seen = <int>{0};
    for (final delegacion in _delegaciones) {
      final id = _toInt(delegacion['id']);
      if (id <= 0 || !seen.add(id)) continue;
      items.add(
        DropdownMenuItem(
          value: id,
          child: Text(
            _delegacionNombre(delegacion),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _unidadDropdown()),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: seen.contains(selected) ? selected : 0,
                  items: items,
                  onChanged: !enabled
                      ? null
                      : (value) {
                          final id = value ?? 0;
                          setState(() {
                            _delegacionFiltroId = id > 0 ? id : null;
                            if (id > 0) {
                              _unidadOrgId = AuthService.unidadDelegacionesId;
                              _filters['unidad_org_id'] = _unidadOrgId;
                              _filters['delegacion_id'] = id;
                            } else {
                              _filters.remove('delegacion_id');
                            }
                          });
                          _load(reset: true);
                        },
                  decoration: InputDecoration(
                    labelText: _loadingDelegaciones
                        ? 'Delegación (cargando...)'
                        : 'Delegación',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _fallecidosDropdown(),
        ],
      ),
    );
  }

  Widget _unidadDropdown() {
    final value =
        (_unidadOrgId == 1 || _unidadOrgId == AuthService.unidadDelegacionesId)
        ? _unidadOrgId
        : 0;

    return DropdownButtonFormField<int>(
      value: value,
      items: const [
        DropdownMenuItem(value: 0, child: Text('(Todas)')),
        DropdownMenuItem(value: 1, child: Text('Siniestros')),
        DropdownMenuItem(
          value: AuthService.unidadDelegacionesId,
          child: Text('Delegaciones'),
        ),
      ],
      onChanged: (value) {
        final id = value ?? 0;
        setState(() {
          _unidadOrgId = id;
          if (id > 0) {
            _filters['unidad_org_id'] = id;
          } else {
            _filters.remove('unidad_org_id');
          }
          if (id != 0 && id != AuthService.unidadDelegacionesId) {
            _delegacionFiltroId = null;
            _filters.remove('delegacion_id');
          }
        });
        _load(reset: true);
      },
      decoration: const InputDecoration(
        labelText: 'Unidad',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _fallecidosDropdown() {
    final value = const ['', '1', '0'].contains(_conFallecidos)
        ? _conFallecidos
        : '';

    return DropdownButtonFormField<String>(
      value: value,
      items: const [
        DropdownMenuItem(value: '', child: Text('Fallecidos: todos')),
        DropdownMenuItem(value: '1', child: Text('Solo con fallecidos')),
        DropdownMenuItem(value: '0', child: Text('Solo sin fallecidos')),
      ],
      onChanged: (value) {
        final v = value ?? '';
        setState(() {
          _conFallecidos = v;
          if (v.isEmpty) {
            _filters.remove('con_fallecidos');
          } else {
            _filters['con_fallecidos'] = v;
          }
        });
        _load(reset: true);
      },
      decoration: const InputDecoration(
        labelText: 'Fallecidos',
        border: OutlineInputBorder(),
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
