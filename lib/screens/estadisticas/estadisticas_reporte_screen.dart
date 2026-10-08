import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../services/estadisticas_reportes_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_drawer.dart';

class EstadisticasReporteScreen extends StatefulWidget {
  final String reporte;
  final String titulo;

  const EstadisticasReporteScreen({
    super.key,
    required this.reporte,
    required this.titulo,
  });

  @override
  State<EstadisticasReporteScreen> createState() =>
      _EstadisticasReporteScreenState();
}

class _EstadisticasReporteScreenState extends State<EstadisticasReporteScreen> {
  final _service = EstadisticasReportesService();
  final _search = TextEditingController();
  DateTime? _desde;
  DateTime? _hasta;
  bool _loading = true;
  bool _loggingOut = false;
  String? _error;
  Map<String, dynamic> _data = const {};

  static const _hiddenKeys = <String>{
    'destacamentos',
    'peritos',
    'filtros',
    'maxPuestas',
    'maxTotal',
    'maxDias',
    'minimoRegistrosCalificacion',
    'minimoDiasCalificacion',
  };

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _hasta = DateTime(today.year, today.month, today.day);
    _desde = _hasta!.subtract(const Duration(days: 29));
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

  Future<void> _load() async {
    if (widget.reporte.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No se indicó el reporte.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final desde = _date(_desde);
      final hasta = _date(_hasta);
      final data = await _service.cargar(
        widget.reporte,
        params: {
          'desde': desde,
          'hasta': hasta,
          'fecha_inicio': desde,
          'fecha_fin': hasta,
          'fecha': hasta,
          if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
          if (_search.text.trim().isNotEmpty) 'buscar': _search.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _data = data;
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
    setState(() {
      if (from) {
        _desde = selected;
      } else {
        _hasta = selected;
      }
    });
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
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
          ? _errorView()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _filters(),
                  const SizedBox(height: 16),
                  ..._data.entries
                      .where((entry) => !_hiddenKeys.contains(entry.key))
                      .map((entry) => _section(entry.key, entry.value)),
                ],
              ),
            ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('Reintentar')),
        ],
      ),
    ),
  );

  Widget _filters() => _card(
    'Filtros',
    Column(
      children: [
        Row(
          children: [
            Expanded(child: _dateField('Desde', _desde, () => _pick(true))),
            const SizedBox(width: 12),
            Expanded(child: _dateField('Hasta', _hasta, () => _pick(false))),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            labelText: 'Búsqueda',
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
            label: const Text('Aplicar'),
          ),
        ),
      ],
    ),
  );

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

  Widget _section(String key, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    final title = _label(key);
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final scalar = map.entries.where((e) => _isScalar(e.value)).toList();
      final nested = map.entries.where((e) => !_isScalar(e.value)).toList();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _card(
          title,
          Column(
            children: [
              if (scalar.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: scalar
                      .map((entry) => _metric(entry.key, entry.value))
                      .toList(),
                ),
              ...nested.map((entry) => _nested(entry.key, entry.value)),
            ],
          ),
        ),
      );
    }
    if (value is List) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _card(title, _list(value)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _card(title, SelectableText('$value')),
    );
  }

  Widget _nested(String key, dynamic value) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_label(key), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        value is List ? _list(value) : _compactMap(value),
      ],
    ),
  );

  Widget _list(List<dynamic> rows) {
    if (rows.isEmpty) return const Text('Sin datos para el periodo.');
    final visible = rows.take(100).toList();
    return Column(
      children: visible.map((row) {
        if (row is! Map) return ListTile(dense: true, title: Text('$row'));
        final map = Map<String, dynamic>.from(row);
        final title = _rowTitle(map);
        final details = map.entries
            .where(
              (entry) =>
                  entry.value != null &&
                  entry.value.toString().trim().isNotEmpty,
            )
            .where((entry) => !_titleKeys.contains(entry.key))
            .take(7)
            .map((entry) => '${_label(entry.key)}: ${_short(entry.value)}')
            .join('\n');
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: details.isEmpty ? null : Text(details),
          ),
        );
      }).toList(),
    );
  }

  static const _titleKeys = <String>{
    'name',
    'nombre',
    'destacamento',
    'fecha',
    'folio_c5i',
    'tipo',
    'categoria',
    'label',
    'titulo',
    'municipio',
  };

  String _rowTitle(Map<String, dynamic> row) {
    for (final key in _titleKeys) {
      final text = row[key]?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return 'Registro';
  }

  Widget _compactMap(dynamic value) {
    if (value is! Map) return Text(_short(value));
    return Column(
      children: value.entries
          .take(30)
          .map(
            (entry) => ListTile(
              dense: true,
              title: Text(_label('${entry.key}')),
              trailing: Text(_short(entry.value)),
            ),
          )
          .toList(),
    );
  }

  Widget _metric(String key, dynamic value) => Container(
    width: (MediaQuery.sizeOf(context).width - 58) / 2,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF2563EB).withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(
          _short(value),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          _label(key),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );

  bool _isScalar(dynamic value) =>
      value == null || value is String || value is num || value is bool;

  String _short(dynamic value) {
    if (value is Map || value is List) {
      return '${value.length} registros';
    }
    final text = '${value ?? '—'}';
    return text.length > 90 ? '${text.substring(0, 87)}…' : text;
  }

  String _label(String value) {
    final spaced = value.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return 'Datos';
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  Widget _card(String title, Widget child) => Container(
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}
