import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/estadisticas_globales_service.dart';
import '../../widgets/app_drawer.dart';
import '../../main.dart' show AppRoutes;

class EstadisticasGlobalesHomeScreen extends StatefulWidget {
  const EstadisticasGlobalesHomeScreen({super.key});

  @override
  State<EstadisticasGlobalesHomeScreen> createState() =>
      _EstadisticasGlobalesHomeScreenState();
}

class _EstadisticasGlobalesHomeScreenState
    extends State<EstadisticasGlobalesHomeScreen> {
  final _svc = EstadisticasGlobalesService();

  // ===== filtros =====
  DateTime? _desde;
  DateTime? _hasta;
  String _sector = '';
  String _tipoHecho = '';
  String _vehTipo = '';
  String _conLesionados = ''; // '', '1', '0'
  String _group = 'day'; // day|month

  final TextEditingController _q = TextEditingController();
  final TextEditingController _vehPlacas = TextEditingController();
  final TextEditingController _vehSerie = TextEditingController();

  // ===== data =====
  bool _loading = true;
  bool _busy = false;
  String? _error;

  Map<String, dynamic>? _kpis;

  // dists para selects + charts
  Map<String, dynamic>? _distSector;
  Map<String, dynamic>? _distTipoHecho;
  Map<String, dynamic>? _distVehTipo;

  // series
  Map<String, dynamic>? _timeHechos;

  // tabla
  Map<String, dynamic>? _hechosPage;

  int _page = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _setDefaultDates();
    _loadAll(resetPage: true);
  }

  @override
  void dispose() {
    _q.dispose();
    _vehPlacas.dispose();
    _vehSerie.dispose();
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

  void _setDefaultDates() {
    final now = DateTime.now();
    _hasta = DateTime(now.year, now.month, now.day);
    final start = _hasta!.subtract(const Duration(days: 30));
    _desde = DateTime(start.year, start.month, start.day);
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Map<String, dynamic> _buildParams({int? pageOverride}) {
    final p = <String, dynamic>{};

    final desde = _fmtDate(_desde);
    final hasta = _fmtDate(_hasta);
    if (desde.isNotEmpty) p['desde'] = desde;
    if (hasta.isNotEmpty) p['hasta'] = hasta;

    if (_sector.trim().isNotEmpty) p['sector'] = _sector.trim();
    if (_tipoHecho.trim().isNotEmpty) p['tipo_hecho'] = _tipoHecho.trim();
    if (_vehTipo.trim().isNotEmpty) p['veh_tipo'] = _vehTipo.trim();
    if (_conLesionados.trim().isNotEmpty) p['con_lesionados'] = _conLesionados;

    p['group'] = _group;

    final q = _q.text.trim();
    if (q.isNotEmpty) p['q'] = q;

    final placas = _vehPlacas.text.trim();
    if (placas.isNotEmpty) p['veh_placas'] = placas;

    final serie = _vehSerie.text.trim();
    if (serie.isNotEmpty) p['veh_serie'] = serie;

    p['per'] = 25;
    p['page'] = pageOverride ?? _page;

    return p;
  }

  String _keepOrEmpty(String current, Map<String, dynamic>? dist) {
    if (current.trim().isEmpty) return '';
    final series = (dist?['series'] as List?) ?? const [];
    final ok = series.any(
      (r) => (r is Map) && (r['label']?.toString() == current),
    );
    return ok ? current : '';
  }

  Future<void> _loadAll({required bool resetPage}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (resetPage) _page = 1;
    });

    try {
      final params = _buildParams(pageOverride: _page);

      // KPIs
      final k = await _svc.kpis(params: params);

      // Selects (distribuciones)
      final sectorDist = await _svc.distribution('sector', params: params);
      final tipoHechoDist = await _svc.distribution(
        'tipo-hecho',
        params: params,
      );
      final vehTipoDist = await _svc.distribution(
        'vehiculos/tipo',
        params: params,
      );

      // Serie de hechos en el tiempo
      final time = await _svc.seriesHechos(params: params);

      // Tabla drilldown
      final hechos = await _svc.hechos(params: params);

      final lpRaw = hechos['last_page'];
      final lp = lpRaw is int
          ? lpRaw
          : int.tryParse(lpRaw?.toString() ?? '1') ?? 1;

      setState(() {
        _kpis = k;

        _distSector = sectorDist;
        _distTipoHecho = tipoHechoDist;
        _distVehTipo = vehTipoDist;

        _timeHechos = time;
        _hechosPage = hechos;

        _lastPage = lp <= 0 ? 1 : lp;

        // mantener selección solo si existe en opciones
        _sector = _keepOrEmpty(_sector, _distSector);
        _tipoHecho = _keepOrEmpty(_tipoHecho, _distTipoHecho);
        _vehTipo = _keepOrEmpty(_vehTipo, _distVehTipo);

        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ===== Export (descarga real + visible) =====
  Future<void> _exportCsv() async {
    await _runBusy(() async {
      try {
        final params = _buildParams(pageOverride: 1);
        params.remove('page');
        params.remove('per');

        final bytes = await _svc.exportHechos(params: params);

        if (bytes.isEmpty) {
          throw Exception('El servidor regresó el archivo vacío.');
        }

        final baseName =
            'hechos_export_${DateTime.now().millisecondsSinceEpoch}';

        // 1) Intento: FileSaver (Downloads / Files según el SO)
        String? savedPath;
        try {
          savedPath = await FileSaver.instance.saveFile(
            name: baseName,
            bytes: bytes,
            ext: 'csv',
            mimeType: MimeType.csv,
          );
        } catch (_) {
          savedPath = null;
        }

        // 2) Siempre: escribimos una copia REAL en Documents para poder compartir/abrir sí o sí
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$baseName.csv');
        await file.writeAsBytes(bytes, flush: true);

        if (!mounted) return;

        final msg = (savedPath != null && savedPath.trim().isNotEmpty)
            ? 'Export guardado. Ruta: $savedPath'
            : 'Export listo. Guardado en: ${file.path}';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));

        // 3) Abrir/compartir (así lo ves SIEMPRE)
        await Share.shareXFiles([
          XFile(file.path, mimeType: 'text/csv'),
        ], text: 'Export CSV de hechos');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exportando: $e')));
      }
    });
  }

  // ===== Helpers UI =====
  Future<void> _pickDate({required bool isDesde}) async {
    final initial = isDesde
        ? (_desde ?? DateTime.now())
        : (_hasta ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      if (isDesde) {
        _desde = picked;
      } else {
        _hasta = picked;
      }
    });
  }

  // ===== Charts builders =====
  Widget _chartTimeHechos() {
    final rows = (_timeHechos?['series'] as List?) ?? const [];
    if (rows.isEmpty) return _emptyChart('Sin datos');

    final labels = rows.map((r) => (r as Map)['x']?.toString() ?? '').toList();
    final values = rows
        .map((r) => num.tryParse(((r as Map)['y'] ?? 0).toString()) ?? 0)
        .toList();

    final maxY = values.isEmpty
        ? 0
        : values.reduce((a, b) => a > b ? a : b).toDouble();

    final bars = <BarChartGroupData>[];
    for (var i = 0; i < values.length; i++) {
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i].toDouble(),
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 5 : (maxY * 1.2),
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 36),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= labels.length) {
                    return const SizedBox.shrink();
                  }

                  final txt = labels[idx];
                  final show = labels.length <= 8
                      ? txt
                      : (idx % 2 == 0 ? txt : '');

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      show,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: bars,
        ),
      ),
    );
  }

  Widget _pieFromDistribution(
    Map<String, dynamic>? dist, {
    required String emptyMsg,
  }) {
    final series = (dist?['series'] as List?) ?? const [];
    if (series.isEmpty) return _emptyChart(emptyMsg);

    final top = series.take(10).toList();

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < top.length; i++) {
      final r = top[i] as Map;
      final total = num.tryParse((r['total'] ?? 0).toString()) ?? 0;

      sections.add(
        PieChartSectionData(
          value: total.toDouble(),
          title: total.toInt().toString(),
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...top.map((e) {
          final r = e as Map;
          final label = (r['label'] ?? '').toString();
          final total = (r['total'] ?? '').toString();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 10),
                const SizedBox(width: 8),
                Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
                Text(total),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _emptyChart(String msg) {
    return Container(
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: Text(msg),
    );
  }

  // ===== Table helpers =====
  List<Map<String, dynamic>> _hechosData() {
    final items = (_hechosPage?['data'] as List?) ?? const [];
    return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hechos = _hechosData();

    final totalHechos = _kpis?['totales']?['hechos']?.toString() ?? '0';
    final totalLesionados = _kpis?['totales']?['lesionados']?.toString() ?? '0';
    final totalVehiculos = _kpis?['totales']?['vehiculos']?.toString() ?? '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas Globales'),
        actions: [
          IconButton(
            onPressed: (_loading || _busy) ? null : _exportCsv,
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
          ),
        ],
      ),
      drawer: AppDrawer(
        trackingOn: false,
        onLogout: () {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.login,
            (_) => false,
          );
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: () => _loadAll(resetPage: false),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ===== Filtros =====
                  _panel(
                    title: 'Filtros',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _dateField(
                                label: 'Desde',
                                value: _fmtDate(_desde),
                                onTap: () => _pickDate(isDesde: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _dateField(
                                label: 'Hasta',
                                value: _fmtDate(_hasta),
                                onTap: () => _pickDate(isDesde: false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _selectFromDist(
                                label: 'Sector',
                                value: _sector,
                                dist: _distSector,
                                onChanged: (v) => setState(() => _sector = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _selectFromDist(
                                label: 'Tipo de Hecho',
                                value: _tipoHecho,
                                dist: _distTipoHecho,
                                onChanged: (v) =>
                                    setState(() => _tipoHecho = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _selectFromDist(
                                label: 'Tipo de Vehículo',
                                value: _vehTipo,
                                dist: _distVehTipo,
                                onChanged: (v) => setState(() => _vehTipo = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _dropdown(
                                label: 'Lesionados',
                                value: _conLesionados,
                                items: const [
                                  DropdownMenuItem(
                                    value: '',
                                    child: Text('(Todos)'),
                                  ),
                                  DropdownMenuItem(
                                    value: '1',
                                    child: Text('Solo con lesionados'),
                                  ),
                                  DropdownMenuItem(
                                    value: '0',
                                    child: Text('Solo sin lesionados'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _conLesionados = v ?? ''),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _dropdown(
                                label: 'Agrupar',
                                value: _group,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'day',
                                    child: Text('Día'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'month',
                                    child: Text('Mes'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _group = v ?? 'day'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 56,
                                child: ElevatedButton.icon(
                                  onPressed: (_busy)
                                      ? null
                                      : () => _runBusy(() async {
                                          await _loadAll(resetPage: true);
                                        }),
                                  icon: const Icon(Icons.sync),
                                  label: const Text('Aplicar'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _q,
                          decoration: const InputDecoration(
                            labelText:
                                'Búsqueda (folio, perito, unidad, calle, colonia…)',
                            hintText: 'Ej: MOR/2026, ALONSO, PERIFERICO...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _vehPlacas,
                                decoration: const InputDecoration(
                                  labelText: 'Placas',
                                  hintText: 'Ej: PGD',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _vehSerie,
                                decoration: const InputDecoration(
                                  labelText: 'Serie',
                                  hintText: 'Ej: LJX',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: (_busy) ? null : _exportCsv,
                            icon: const Icon(Icons.file_download),
                            label: const Text('Export CSV'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== KPIs =====
                  Row(
                    children: [
                      _kpiBox('Hechos', totalHechos, Colors.blue),
                      const SizedBox(width: 12),
                      _kpiBox('Lesionados', totalLesionados, Colors.red),
                      const SizedBox(width: 12),
                      _kpiBox('Vehículos', totalVehiculos, Colors.green),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ===== Charts =====
                  _panel(
                    title: 'Hechos en el tiempo',
                    child: _chartTimeHechos(),
                  ),
                  const SizedBox(height: 16),

                  _panel(
                    title: 'Tipos de Hecho (Top)',
                    child: _pieFromDistribution(
                      _distTipoHecho,
                      emptyMsg: 'Sin datos de tipos de hecho',
                    ),
                  ),
                  const SizedBox(height: 16),

                  _panel(
                    title: 'Tipos de Vehículo (Top)',
                    child: _pieFromDistribution(
                      _distVehTipo,
                      emptyMsg: 'Sin datos de tipos de vehículo',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Tabla drilldown =====
                  _panel(
                    title: 'Hechos filtrados (drilldown)',
                    child: Column(
                      children: [
                        if (hechos.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Sin datos…'),
                          )
                        else
                          ...hechos.map((h) {
                            final idRaw = h['id'];
                            final intId = (idRaw is int)
                                ? idRaw
                                : int.tryParse('$idRaw') ?? 0;

                            final folio = h['folio_c5i']?.toString() ?? '';
                            final fecha = h['fecha']?.toString() ?? '';
                            final sector = h['sector']?.toString() ?? '';
                            final tipo = h['tipo_hecho']?.toString() ?? '';
                            final situacion = h['situacion']?.toString() ?? '';

                            return ListTile(
                              dense: true,
                              title: Text('$folio  •  $fecha'),
                              subtitle: Text(
                                '$sector  •  $tipo  •  $situacion',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                if (intId <= 0) return;

                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.accidentesShow,
                                  arguments: {'hechoId': intId},
                                );
                              },
                            );
                          }),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton(
                              onPressed: (_page <= 1 || _busy)
                                  ? null
                                  : () => _runBusy(() async {
                                      setState(() => _page--);
                                      await _loadAll(resetPage: false);
                                    }),
                              child: const Icon(Icons.chevron_left),
                            ),
                            Text('Página $_page de $_lastPage'),
                            OutlinedButton(
                              onPressed: (_page >= _lastPage || _busy)
                                  ? null
                                  : () => _runBusy(() async {
                                      setState(() => _page++);
                                      await _loadAll(resetPage: false);
                                    }),
                              child: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ===== UI bits =====
  Widget _panel({required String title, required Widget child}) {
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
            children: [
              const Icon(Icons.insights, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _kpiBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(value.isEmpty ? 'Seleccionar' : value),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _selectFromDist({
    required String label,
    required String value,
    required Map<String, dynamic>? dist,
    required ValueChanged<String> onChanged,
  }) {
    final series = (dist?['series'] as List?) ?? const [];
    final options = <String>[''];
    for (final e in series) {
      if (e is Map) {
        options.add((e['label'] ?? '').toString());
      }
    }

    return DropdownButtonFormField<String>(
      value: options.contains(value) ? value : '',
      items: options.map((v) {
        final txt = v.isEmpty ? '(Todos)' : v;
        return DropdownMenuItem(
          value: v,
          child: Text(txt, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (v) => onChanged(v ?? ''),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
