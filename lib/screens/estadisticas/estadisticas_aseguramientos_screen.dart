import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../services/estadisticas_aseguramientos_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_drawer.dart';

class EstadisticasAseguramientosScreen extends StatefulWidget {
  final int? unidadId;
  final String? unidadNombre;

  const EstadisticasAseguramientosScreen({
    super.key,
    this.unidadId,
    this.unidadNombre,
  });

  @override
  State<EstadisticasAseguramientosScreen> createState() =>
      _EstadisticasAseguramientosScreenState();
}

class _EstadisticasAseguramientosScreenState
    extends State<EstadisticasAseguramientosScreen> {
  static const _colors = <Color>[
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFF59E0B),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
  ];

  final _service = EstadisticasAseguramientosService();
  final _search = TextEditingController();
  DateTime? _desde;
  DateTime? _hasta;
  int? _unidadId;
  int? _delegacionId;
  int? _destacamentoId;
  bool _loading = true;
  bool _loggingOut = false;
  String? _error;
  Map<String, dynamic> _catalogos = const {};
  Map<String, dynamic> _resumen = const {};

  bool get _unidadFija => widget.unidadId != null && widget.unidadId! > 0;

  @override
  void initState() {
    super.initState();
    _unidadId = widget.unidadId;
    final today = DateTime.now();
    _hasta = DateTime(today.year, today.month, today.day);
    _desde = _hasta!.subtract(const Duration(days: 30));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _date(DateTime? value) => value == null
      ? ''
      : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  int _int(dynamic value) => int.tryParse('${value ?? ''}') ?? 0;

  List<Map<String, dynamic>> _rows(String key) =>
      ((_catalogos[key] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalogos = await _service.catalogos();
      final resumen = await _service.resumen({
        'desde': _date(_desde),
        'hasta': _date(_hasta),
        if (_unidadId != null) 'unidad_id': _unidadId,
        if (_delegacionId != null) 'delegacion_id': _delegacionId,
        if (_destacamentoId != null) 'destacamento_id': _destacamentoId,
        if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _catalogos = catalogos;
        _resumen = resumen;
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

  Future<void> _pick(bool from) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (from ? _desde : _hasta) ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() => from ? _desde = selected : _hasta = selected);
  }

  Future<void> _logout() async {
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
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.unidadNombre ?? '').trim().isEmpty
        ? 'Aseguramientos'
        : 'Aseguramientos · ${widget.unidadNombre}';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const AccountMenuAction(),
        ],
      ),
      drawer: const AppDrawer(trackingOn: false),
      endDrawer: AppAccountDrawer(onLogout: _logout),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _panel('Filtros', _filters()),
                  const SizedBox(height: 16),
                  _kpis(),
                  const SizedBox(height: 16),
                  _chartPanel('Rubros principales', 'grupos'),
                  const SizedBox(height: 16),
                  _chartPanel('Vehículos por motivo', 'vehiculos'),
                  const SizedBox(height: 16),
                  _chartPanel('Personas', 'personas'),
                  const SizedBox(height: 16),
                  _shareCard(),
                  const SizedBox(height: 16),
                  _details(),
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
            Expanded(child: _dateField('Desde', _desde, () => _pick(true))),
            const SizedBox(width: 12),
            Expanded(child: _dateField('Hasta', _hasta, () => _pick(false))),
          ],
        ),
        if (!_unidadFija && _rows('unidades').length > 1) ...[
          const SizedBox(height: 12),
          _catalogDropdown('Unidad', _unidadId, _rows('unidades'), (value) {
            setState(() {
              _unidadId = value;
              _destacamentoId = null;
            });
          }),
        ],
        if (_rows('delegaciones').isNotEmpty) ...[
          const SizedBox(height: 12),
          _catalogDropdown(
            'Delegación',
            _delegacionId,
            _rows('delegaciones'),
            (value) => setState(() => _delegacionId = value),
          ),
        ],
        if (_filteredDestacamentos().isNotEmpty) ...[
          const SizedBox(height: 12),
          _catalogDropdown(
            'Destacamento',
            _destacamentoId,
            _filteredDestacamentos(),
            (value) => setState(() => _destacamentoId = value),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            labelText: 'Búsqueda',
            hintText: 'Folio, motivo, vehículo, objeto, persona o lugar',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _load(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.filter_alt),
            label: const Text('Aplicar filtros'),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _filteredDestacamentos() {
    return _rows('destacamentos').where((row) {
      if (_unidadId != null &&
          _int(row['unidad_id']) > 0 &&
          _int(row['unidad_id']) != _unidadId) {
        return false;
      }
      if (_delegacionId != null &&
          _int(row['delegacion_id']) > 0 &&
          _int(row['delegacion_id']) != _delegacionId) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _dateField(String label, DateTime? value, VoidCallback tap) => InkWell(
    onTap: tap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: Text(_date(value)),
    ),
  );

  Widget _catalogDropdown(
    String label,
    int? value,
    List<Map<String, dynamic>> rows,
    ValueChanged<int?> changed,
  ) {
    final ids = rows
        .map((row) => _int(row['id']))
        .where((id) => id > 0)
        .toSet();
    return DropdownButtonFormField<int?>(
      value: ids.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('(Todos)')),
        ...rows.where((row) => _int(row['id']) > 0).map((row) {
          final name = (row['nombre'] ?? row['clave'] ?? 'Registro').toString();
          return DropdownMenuItem<int?>(
            value: _int(row['id']),
            child: Text(name, overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: changed,
    );
  }

  Widget _kpis() {
    final data = (_resumen['kpis'] as Map?) ?? const {};
    const keys = [
      'puestas',
      'personas',
      'vehiculos',
      'armas',
      'drogas',
      'dinero',
    ];
    const labels = [
      'Puestas',
      'Personas',
      'Vehículos',
      'Armas',
      'Droga/alcohol',
      'Dinero',
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(keys.length, (index) {
        final item = data[keys[index]];
        final value = item is Map ? item['value'] : 0;
        return SizedBox(
          width: (MediaQuery.sizeOf(context).width - 42) / 2,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _colors[index % _colors.length],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[index], textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _chartPanel(String title, String key) {
    final charts = (_resumen['charts'] as Map?) ?? const {};
    final rows = ((charts[key] as List?) ?? const []).whereType<Map>().toList();
    final maxValue = rows.fold<double>(0, (max, row) {
      final value = double.tryParse('${row['total'] ?? 0}') ?? 0;
      return value > max ? value : max;
    });
    final chart = rows.isEmpty || maxValue <= 0
        ? const SizedBox(height: 140, child: Center(child: Text('Sin datos')))
        : SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                maxY: maxValue * 1.2,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true),
                titlesData: const FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                barGroups: rows.asMap().entries.map((entry) {
                  final value =
                      double.tryParse('${entry.value['total'] ?? 0}') ?? 0;
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        width: 18,
                        color: _colors[entry.key % _colors.length],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
    return _panel(
      title,
      Column(
        children: [
          chart,
          ...rows.asMap().entries.map(
            (entry) => ListTile(
              dense: true,
              leading: Icon(
                Icons.circle,
                size: 12,
                color: _colors[entry.key % _colors.length],
              ),
              title: Text('${entry.value['label'] ?? ''}'),
              trailing: Text('${entry.value['total'] ?? 0}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shareCard() {
    final card = (_resumen['tarjeta'] as Map?) ?? const {};
    final text = (card['texto'] ?? '').toString();
    return _panel(
      'Tarjeta compartible',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(text.isEmpty ? 'Sin datos para compartir.' : text),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: text.isEmpty ? null : () => Share.share(text),
            icon: const Icon(Icons.share),
            label: const Text('Compartir'),
          ),
        ],
      ),
    );
  }

  Widget _details() {
    final groups = ((_resumen['detalle_grupos'] as List?) ?? const [])
        .whereType<Map>()
        .toList();
    return _panel(
      'Detalle de lo contabilizado',
      Column(
        children: groups.map((group) {
          final total = group['total'] ?? 0;
          return ListTile(
            dense: true,
            title: Text('${group['label'] ?? group['key'] ?? ''}'),
            trailing: Text(
              '$total',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _panel(String title, Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}
