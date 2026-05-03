import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../services/estadisticas_actividades_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_drawer.dart';

class EstadisticasActividadesHomeScreen extends StatefulWidget {
  const EstadisticasActividadesHomeScreen({super.key});

  @override
  State<EstadisticasActividadesHomeScreen> createState() =>
      _EstadisticasActividadesHomeScreenState();
}

class _EstadisticasActividadesHomeScreenState
    extends State<EstadisticasActividadesHomeScreen> {
  final _svc = EstadisticasActividadesService();
  final _q = TextEditingController();

  DateTime? _desde;
  DateTime? _hasta;
  int? _categoriaId;
  int? _subcategoriaId;
  int? _delegacionId;
  String _estadoRevision = '';
  String _group = 'day';

  bool _loading = true;
  bool _busy = false;
  bool _loggingOut = false;
  bool _canFilterDelegacion = false;
  bool _mostrarGruasEnGraficas = false;
  String? _error;

  Map<String, dynamic>? _kpis;
  Map<String, dynamic>? _timeActividades;
  Map<String, dynamic>? _distCategoria;
  Map<String, dynamic>? _distSubcategoria;
  Map<String, dynamic>? _distDelegacion;
  Map<String, dynamic>? _actividadesPage;

  List<Map<String, dynamic>> _categorias = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _subcategorias = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _delegaciones = const <Map<String, dynamic>>[];

  int _page = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _setDefaultDates();
    _bootstrapAccessAndLoad();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
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

    if (_categoriaId != null && _categoriaId! > 0) {
      p['actividad_categoria_id'] = _categoriaId;
    }
    if (_subcategoriaId != null && _subcategoriaId! > 0) {
      p['actividad_subcategoria_id'] = _subcategoriaId;
    }
    if (_delegacionId != null && _delegacionId! > 0) {
      p['delegacion_id'] = _delegacionId;
    }
    if (_estadoRevision.trim().isNotEmpty) {
      p['estado_revision'] = _estadoRevision;
    }

    final q = _q.text.trim();
    if (q.isNotEmpty) p['q'] = q;

    p['group'] = _group;
    p['per'] = 25;
    p['page'] = pageOverride ?? _page;

    return p;
  }

  Future<void> _bootstrapAccessAndLoad() async {
    try {
      final canFilterDelegacion =
          await AuthService.hasFullOperationalAccess() ||
          await AuthService.isDelegacionesUser();
      if (!mounted) return;
      setState(() => _canFilterDelegacion = canFilterDelegacion);
    } catch (_) {}

    if (!mounted) return;
    await _loadAll(resetPage: true);
  }

  Future<void> _runBusy(Future<void> Function() fn) async {
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadAll({required bool resetPage}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (resetPage) _page = 1;
    });

    try {
      final params = _buildParams(pageOverride: resetPage ? 1 : _page);
      final results = await Future.wait<dynamic>([
        _svc.kpis(params: params),
        _svc.seriesActividades(params: params),
        _svc.distribution('categoria', params: params),
        _svc.distribution('subcategoria', params: params),
        _svc.distribution('delegacion', params: params),
        _svc.actividades(params: params),
        _svc.catalogoCategorias(),
        _svc.catalogoSubcategorias(actividadCategoriaId: _categoriaId),
        if (_canFilterDelegacion)
          _svc.catalogoDelegaciones()
        else
          Future.value(const <Map<String, dynamic>>[]),
      ]);

      final actividades = (results[5] as Map).cast<String, dynamic>();
      final lpRaw = actividades['last_page'];
      final lp = lpRaw is int
          ? lpRaw
          : int.tryParse(lpRaw?.toString() ?? '1') ?? 1;

      final cats = (results[6] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final subs = (results[7] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final delegs = (results[8] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;
      setState(() {
        _kpis = (results[0] as Map).cast<String, dynamic>();
        _timeActividades = (results[1] as Map).cast<String, dynamic>();
        _distCategoria = (results[2] as Map).cast<String, dynamic>();
        _distSubcategoria = (results[3] as Map).cast<String, dynamic>();
        _distDelegacion = (results[4] as Map).cast<String, dynamic>();
        _actividadesPage = actividades;
        _categorias = cats;
        _subcategorias = subs;
        _delegaciones = delegs;
        _lastPage = lp <= 0 ? 1 : lp;
        _loading = false;

        if (_categoriaId != null &&
            !_categorias.any((c) => _asInt(c['id']) == _categoriaId)) {
          _categoriaId = null;
          _subcategoriaId = null;
        }
        if (_subcategoriaId != null &&
            !_subcategorias.any((s) => _asInt(s['id']) == _subcategoriaId)) {
          _subcategoriaId = null;
        }
        if (_delegacionId != null &&
            !_delegaciones.any((d) => _asInt(d['id']) == _delegacionId)) {
          _delegacionId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _exportCsv() async {
    await _runBusy(() async {
      try {
        final params = _buildParams(pageOverride: 1);
        params.remove('page');
        params.remove('per');

        final bytes = await _svc.exportActividades(params: params);
        if (bytes.isEmpty) {
          throw Exception('El servidor regresó el archivo vacío.');
        }

        final baseName =
            'actividades_export_${DateTime.now().millisecondsSinceEpoch}';
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

        await Share.shareXFiles([
          XFile(file.path, mimeType: 'text/csv'),
        ], text: 'Export CSV de actividades');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exportando: $e')));
      }
    });
  }

  Future<void> _logout(BuildContext context) async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    try {
      try {
        await TrackingService.stop();
      } catch (_) {}
      await AuthService.logout();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

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

  List<Map<String, dynamic>> _actividadesData() {
    final items = (_actividadesPage?['data'] as List?) ?? const [];
    return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  num _num(dynamic value) => num.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final actividades = _actividadesData();
    final totales = (_kpis?['totales'] as Map?) ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas de Actividades'),
        actions: [
          IconButton(
            onPressed: (_loading || _busy) ? null : _exportCsv,
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
          ),
          const AccountMenuAction(),
        ],
      ),
      drawer: const AppDrawer(trackingOn: false),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorView()
          : RefreshIndicator(
              onRefresh: () => _loadAll(resetPage: false),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _panel(title: 'Filtros', child: _filters()),
                  const SizedBox(height: 16),
                  _kpisGrid(totales),
                  const SizedBox(height: 16),
                  _panel(
                    title: 'Actividades en el tiempo',
                    child: _chartTimeActividades(),
                  ),
                  const SizedBox(height: 16),
                  _panel(
                    title: 'Categorías',
                    child: _pieFromDistribution(
                      _distCategoria,
                      emptyMsg: 'Sin datos de categorías',
                      excludeGruas: !_mostrarGruasEnGraficas,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _panel(
                    title: 'Subcategorías',
                    child: _pieFromDistribution(
                      _distSubcategoria,
                      emptyMsg: 'Sin datos de subcategorías',
                      excludeGruas: !_mostrarGruasEnGraficas,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _panel(
                    title: 'Delegaciones',
                    child: _pieFromDistribution(
                      _distDelegacion,
                      emptyMsg: 'Sin datos de delegaciones',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _panel(
                    title: 'Actividades filtradas',
                    child: _actividadesList(actividades),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _filters() {
    return Column(
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
            Expanded(child: _categoriaDropdown()),
            const SizedBox(width: 12),
            Expanded(child: _subcategoriaDropdown()),
          ],
        ),
        if (_canFilterDelegacion) ...[
          const SizedBox(height: 12),
          _delegacionDropdown(),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _dropdown(
                label: 'Revisión',
                value: _estadoRevision,
                items: const [
                  DropdownMenuItem(value: '', child: Text('(Todas)')),
                  DropdownMenuItem(
                    value: 'pendiente',
                    child: Text('Pendiente'),
                  ),
                  DropdownMenuItem(value: 'aprobado', child: Text('Aprobado')),
                  DropdownMenuItem(
                    value: 'rechazado',
                    child: Text('Rechazado'),
                  ),
                ],
                onChanged: (v) => setState(() => _estadoRevision = v ?? ''),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdown(
                label: 'Agrupar',
                value: _group,
                items: const [
                  DropdownMenuItem(value: 'day', child: Text('Día')),
                  DropdownMenuItem(value: 'month', child: Text('Mes')),
                ],
                onChanged: (v) => setState(() => _group = v ?? 'day'),
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar grúas en gráficas'),
          value: _mostrarGruasEnGraficas,
          onChanged: (v) => setState(() => _mostrarGruasEnGraficas = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _q,
          decoration: const InputDecoration(
            labelText: 'Búsqueda',
            hintText: 'Lugar, municipio, carretera, motivo...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _runBusy(() => _loadAll(resetPage: true)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _runBusy(() => _loadAll(resetPage: true)),
                  icon: const Icon(Icons.sync),
                  label: const Text('Aplicar'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _exportCsv,
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export CSV'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kpisGrid(Map totales) {
    final data = <({String label, String value, Color color})>[
      (
        label: 'Actividades',
        value: _num(totales['actividades']).toInt().toString(),
        color: Colors.indigo,
      ),
      (
        label: 'Cantidad',
        value: _num(totales['cantidad']).toInt().toString(),
        color: Colors.teal,
      ),
      (
        label: 'Alcanzadas',
        value: _num(totales['personas_alcanzadas']).toInt().toString(),
        color: Colors.orange,
      ),
      (
        label: 'Participantes',
        value: _num(totales['personas_participantes']).toInt().toString(),
        color: Colors.green,
      ),
      (
        label: 'Detenidas',
        value: _num(totales['personas_detenidas']).toInt().toString(),
        color: Colors.red,
      ),
      (
        label: 'Km recorridos',
        value: _num(totales['km_recorridos']).toStringAsFixed(1),
        color: Colors.blue,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final columns = isWide ? 3 : 2;
        final width = (constraints.maxWidth - (12 * (columns - 1))) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: data
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _kpiBox(item.label, item.value, item.color),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _actividadesList(List<Map<String, dynamic>> actividades) {
    return Column(
      children: [
        if (actividades.isEmpty)
          const Padding(padding: EdgeInsets.all(12), child: Text('Sin datos.'))
        else
          ...actividades.map((a) {
            final intId = _asInt(a['id']);
            final fecha = (a['fecha'] ?? '').toString();
            final hora = (a['hora'] ?? '').toString();
            final categoria = (a['categoria_nombre'] ?? '').toString();
            final subcategoria = (a['subcategoria_nombre'] ?? '').toString();
            final lugar = (a['lugar'] ?? a['municipio'] ?? '').toString();
            final cantidad = _num(a['cantidad']).toInt();

            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                [
                  categoria,
                  subcategoria,
                ].where((s) => s.trim().isNotEmpty).join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  fecha,
                  if (hora.length >= 5) hora.substring(0, 5),
                  lugar,
                ].where((s) => s.trim().isNotEmpty).join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(cantidad.toString()),
              onTap: () {
                if (intId <= 0) return;
                Navigator.pushNamed(
                  context,
                  AppRoutes.actividadesShow,
                  arguments: {'actividad_id': intId},
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
    );
  }

  Widget _chartTimeActividades() {
    final rows = (_timeActividades?['series'] as List?) ?? const [];
    if (rows.isEmpty) return _emptyChart('Sin datos');

    final labels = rows.map((r) => (r as Map)['x']?.toString() ?? '').toList();
    final values = rows
        .map((r) => num.tryParse(((r as Map)['y'] ?? 0).toString()) ?? 0)
        .toList();

    final maxY = values.isEmpty
        ? 0
        : values.reduce((a, b) => a > b ? a : b).toDouble();

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
          barGroups: [
            for (var i = 0; i < values.length; i++)
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
          ],
        ),
      ),
    );
  }

  Widget _pieFromDistribution(
    Map<String, dynamic>? dist, {
    required String emptyMsg,
    bool excludeGruas = false,
  }) {
    final series = _seriesFromDistribution(dist, excludeGruas: excludeGruas);
    if (series.isEmpty) return _emptyChart(emptyMsg);

    final top = series.take(10).toList();

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 0,
              sections: [
                for (final e in top)
                  PieChartSectionData(
                    value: _num(e['total']).toDouble(),
                    title: _num(e['total']).toInt().toString(),
                    radius: 70,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...top.map((e) {
          final label = (e['label'] ?? '').toString();
          final total = (e['total'] ?? '').toString();
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

  List<Map<String, dynamic>> _seriesFromDistribution(
    Map<String, dynamic>? dist, {
    required bool excludeGruas,
  }) {
    final raw = (dist?['series'] as List?) ?? const [];
    final rows = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (!excludeGruas) return rows;
    return rows.where((e) => !_isGruaLabel(e['label'])).toList();
  }

  bool _isGruaLabel(dynamic value) {
    final text = _plainSearchText(value?.toString() ?? '');
    if (text.isEmpty) return false;
    final tokens = text.split(' ');
    return tokens.contains('grua') || tokens.contains('gruas');
  }

  String _plainSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
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
            color: Colors.black.withValues(alpha: .04),
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
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

  Widget _categoriaDropdown() {
    return DropdownButtonFormField<int?>(
      value: _categoriaId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Categoría',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('(Todas)')),
        ..._categorias.map((c) {
          return DropdownMenuItem<int?>(
            value: _asInt(c['id']),
            child: Text(
              (c['nombre'] ?? '').toString(),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _categoriaId = value;
          _subcategoriaId = null;
        });
      },
    );
  }

  Widget _subcategoriaDropdown() {
    return DropdownButtonFormField<int?>(
      value: _subcategoriaId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Subcategoría',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('(Todas)')),
        ..._subcategorias.map((s) {
          return DropdownMenuItem<int?>(
            value: _asInt(s['id']),
            child: Text(
              (s['nombre'] ?? '').toString(),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: (value) => setState(() => _subcategoriaId = value),
    );
  }

  Widget _delegacionDropdown() {
    return DropdownButtonFormField<int?>(
      value: _delegacionId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Delegación',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('(Todas las delegaciones)'),
        ),
        ..._delegaciones.map((d) {
          final clave = (d['clave'] ?? '').toString().trim();
          final nombre = (d['nombre'] ?? '').toString().trim();
          final label = clave.isEmpty ? nombre : '$clave - $nombre';
          return DropdownMenuItem<int?>(
            value: _asInt(d['id']),
            child: Text(
              label.trim().isEmpty ? 'Delegación' : label,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: (value) => setState(() => _delegacionId = value),
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
              onPressed: () => _loadAll(resetPage: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
