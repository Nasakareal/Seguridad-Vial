import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/conduce_legalidad_reporte_service.dart';

class ConduceLegalidadReporteScreen extends StatefulWidget {
  const ConduceLegalidadReporteScreen({super.key});

  @override
  State<ConduceLegalidadReporteScreen> createState() =>
      _ConduceLegalidadReporteScreenState();
}

class _ConduceLegalidadReporteScreenState
    extends State<ConduceLegalidadReporteScreen> {
  final _service = const ConduceLegalidadReporteService();
  final _search = TextEditingController();
  final _line = TextEditingController();
  final _model = TextEditingController();
  final _plates = TextEditingController();
  final _serial = TextEditingController();
  final _inventory = TextEditingController();
  final _reason = TextEditingController();

  ConduceLegalidadReportePage? _data;
  bool _loading = true;
  bool _downloading = false;
  bool _filtersExpanded = false;
  int _page = 1;
  int _perPage = 25;
  DateTime? _from;
  DateTime? _to;
  String? _municipality;
  String? _brand;
  String? _type;
  String? _color;
  String? _retained;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _search,
      _line,
      _model,
      _plates,
      _serial,
      _inventory,
      _reason,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _filters => <String, dynamic>{
    'q': _search.text,
    'desde': _date(_from),
    'hasta': _date(_to),
    'municipio': _municipality,
    'marca': _brand,
    'tipo': _type,
    'color': _color,
    'linea': _line.text,
    'modelo': _model.text,
    'placas': _plates.text,
    'serie': _serial.text,
    'inventario': _inventory.text,
    'motivo': _reason.text,
    'retenido': _retained,
  };

  int get _activeFilterCount => _filters.values.where((value) {
    return value != null && value.toString().trim().isNotEmpty;
  }).length;

  Future<void> _load({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.fetch(
        filters: _filters,
        page: targetPage,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _data = result;
        _page = result.currentPage;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final bytes = await _service.downloadExcel(filters: _filters);
      if (bytes.isEmpty) {
        throw Exception('El servidor devolvió un archivo vacío.');
      }
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/vehiculos_conduce_con_legalidad_${_date(DateTime.now())}.xlsx',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel descargado correctamente.')),
      );
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Vehículos de Conduce con Legalidad');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar: ${_cleanError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _clearFilters() {
    for (final controller in [
      _search,
      _line,
      _model,
      _plates,
      _serial,
      _inventory,
      _reason,
    ]) {
      controller.clear();
    }
    setState(() {
      _from = null;
      _to = null;
      _municipality = null;
      _brand = null;
      _type = null;
      _color = null;
      _retained = null;
      _page = 1;
    });
    _load(page: 1);
  }

  Future<void> _pickDate({required bool from}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (from) {
        _from = selected;
        if (_to != null && _to!.isBefore(selected)) _to = selected;
      } else {
        _to = selected;
        if (_from != null && _from!.isAfter(selected)) _from = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Conduce con Legalidad'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(page: _page),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [
            _HeroCard(downloading: _downloading, onDownload: _download),
            const SizedBox(height: 12),
            if (_data != null) _SummaryGrid(summary: _data!.summary),
            const SizedBox(height: 12),
            _buildFilters(),
            const SizedBox(height: 12),
            if (_loading && _data == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorCard(message: _cleanError(_error!), onRetry: _load)
            else if (_data != null) ...[
              _buildResultsHeader(),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_data!.vehicles.isEmpty)
                const _EmptyCard()
              else
                for (final vehicle in _data!.vehicles)
                  _VehicleCard(vehicle: vehicle),
              _buildPagination(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final options = _data?.options;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: Color(0xFF0F766E)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Filtros del reporte',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                if (_activeFilterCount > 0)
                  Badge(label: Text('$_activeFilterCount')),
                IconButton(
                  tooltip: _filtersExpanded
                      ? 'Ocultar filtros'
                      : 'Mostrar filtros',
                  onPressed: () =>
                      setState(() => _filtersExpanded = !_filtersExpanded),
                  icon: Icon(
                    _filtersExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ),
              ],
            ),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(page: 1),
              decoration: const InputDecoration(
                labelText: 'Búsqueda general',
                hintText: 'Lugar, operativo, marca, placas, serie…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _filtersExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(height: 8),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _dateField('Desde', _from, true)),
                        const SizedBox(width: 10),
                        Expanded(child: _dateField('Hasta', _to, false)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _dropdown(
                      'Municipio',
                      _municipality,
                      options?.municipalities ?? const [],
                      (value) => setState(() => _municipality = value),
                    ),
                    const SizedBox(height: 10),
                    _dropdown(
                      'Retención',
                      _retained,
                      const ['1', '0'],
                      (value) => setState(() => _retained = value),
                      labels: const {
                        '1': 'Solo retenidos',
                        '0': 'No retenidos',
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _dropdown(
                            'Marca',
                            _brand,
                            options?.brands ?? const [],
                            (value) => setState(() => _brand = value),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dropdown(
                            'Tipo',
                            _type,
                            options?.types ?? const [],
                            (value) => setState(() => _type = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _dropdown(
                      'Color',
                      _color,
                      options?.colors ?? const [],
                      (value) => setState(() => _color = value),
                    ),
                    const SizedBox(height: 10),
                    _textRow('Línea', _line, 'Modelo', _model),
                    const SizedBox(height: 10),
                    _textRow('Placas', _plates, 'Serie', _serial),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _inventory,
                      decoration: const InputDecoration(
                        labelText: 'No. de inventario',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _reason,
                      decoration: const InputDecoration(
                        labelText: 'Motivo o fundamento',
                        hintText: 'Artículo, fracción o texto',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : () => _load(page: 1),
                    icon: const Icon(Icons.filter_alt_outlined),
                    label: const Text('Aplicar filtros'),
                  ),
                ),
                if (_activeFilterCount > 0) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Limpiar filtros',
                    onPressed: _loading ? null : _clearFilters,
                    icon: const Icon(Icons.restart_alt),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, bool from) {
    return InkWell(
      onTap: () => _pickDate(from: from),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_month_outlined)
              : IconButton(
                  tooltip: 'Quitar fecha',
                  onPressed: () => setState(() {
                    if (from) {
                      _from = null;
                    } else {
                      _to = null;
                    }
                  }),
                  icon: const Icon(Icons.close),
                ),
        ),
        child: Text(value == null ? 'Todas' : _displayDate(value)),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> onChanged, {
    Map<String, String> labels = const {},
  }) {
    final safeValue = value != null && values.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Todos')),
        for (final item in values)
          DropdownMenuItem(value: item, child: Text(labels[item] ?? item)),
      ],
      onChanged: onChanged,
    );
  }

  Widget _textRow(
    String firstLabel,
    TextEditingController first,
    String secondLabel,
    TextEditingController second,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: first,
            decoration: InputDecoration(labelText: firstLabel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: second,
            decoration: InputDecoration(labelText: secondLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_data!.total} vehículos encontrados',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          DropdownButton<int>(
            value: _perPage,
            items: const [25, 50, 100]
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text('$value')),
                )
                .toList(),
            onChanged: _loading
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _perPage = value);
                    _load(page: 1);
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final data = _data!;
    if (data.lastPage <= 1) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Página anterior',
              onPressed: !_loading && data.currentPage > 1
                  ? () => _load(page: data.currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              'Página ${data.currentPage} de ${data.lastPage}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            IconButton(
              tooltip: 'Página siguiente',
              onPressed: !_loading && data.currentPage < data.lastPage
                  ? () => _load(page: data.currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool downloading;
  final VoidCallback onDownload;

  const _HeroCard({required this.downloading, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0F3B3B)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OPERATIVOS · CONDUCE CON LEGALIDAD',
            style: TextStyle(
              color: Color(0xFF99F6E4),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vehículos registrados',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Consulta el padrón, aplica filtros y descarga exactamente los resultados visibles.',
            style: TextStyle(color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
            ),
            onPressed: downloading ? null : onDownload,
            icon: downloading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            label: Text(downloading ? 'Generando…' : 'Descargar Excel'),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final ConduceLegalidadReporteSummary summary;

  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        Icons.two_wheeler,
        'Vehículos',
        summary.vehicles,
        const Color(0xFF059669),
      ),
      (
        Icons.traffic,
        'Operativos',
        summary.operations,
        const Color(0xFF2563EB),
      ),
      (
        Icons.map_outlined,
        'Municipios',
        summary.municipalities,
        const Color(0xFF7C3AED),
      ),
      (
        Icons.warehouse_outlined,
        'Retenidos',
        summary.retained,
        const Color(0xFFD97706),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in cards)
              SizedBox(
                width: width,
                child: _SummaryCard(
                  icon: item.$1,
                  label: item.$2,
                  value: item.$3,
                  color: item.$4,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .12),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(label, style: const TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final ConduceLegalidadReporteVehiculo vehicle;

  const _VehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFCCFBF1),
                  foregroundColor: Color(0xFF0F766E),
                  child: Icon(Icons.two_wheeler),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.title.isEmpty
                            ? 'Vehículo sin marca o línea'
                            : vehicle.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        [
                          vehicle.model,
                          vehicle.color,
                        ].where((value) => value.isNotEmpty).join(' · '),
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                if (vehicle.retained)
                  const Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(Icons.warehouse_outlined, size: 17),
                    label: Text('Retenido'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _info(
              Icons.calendar_today_outlined,
              '${_displayDateText(vehicle.date)} · Operativo #${vehicle.operationId}',
            ),
            _info(
              Icons.location_on_outlined,
              vehicle.place.isEmpty ? 'Sin lugar' : vehicle.place,
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (vehicle.plates.isNotEmpty)
                  _tag(Icons.badge_outlined, vehicle.plates),
                if (vehicle.inventoryNumber.isNotEmpty)
                  _tag(Icons.tag, 'Inv. ${vehicle.inventoryNumber}'),
                if (vehicle.serialNumber.isNotEmpty)
                  _tag(Icons.qr_code, vehicle.serialNumber),
              ],
            ),
            if (vehicle.reason.isNotEmpty) ...[
              const Divider(height: 22),
              const Text(
                'Motivo',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(vehicle.reason),
            ],
            if (vehicle.vehicleData.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text(
                  'Ver ficha completa',
                  style: TextStyle(
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(vehicle.vehicleData),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0F766E)),
        const SizedBox(width: 7),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _tag(IconData icon, String text) => Chip(
    visualDensity: VisualDensity.compact,
    avatar: Icon(icon, size: 16),
    label: Text(text, overflow: TextOverflow.ellipsis),
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 42,
            color: Colors.orange,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 42,
            color: Color(0xFF0F766E),
          ),
          SizedBox(height: 8),
          Text(
            'Sin resultados',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text('No hay vehículos que coincidan con los filtros seleccionados.'),
        ],
      ),
    ),
  );
}

String _date(DateTime? value) {
  if (value == null) return '';
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _displayDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _displayDateText(String value) {
  final date = DateTime.tryParse(value);
  return date == null
      ? (value.isEmpty ? 'Sin fecha' : value)
      : _displayDate(date);
}

String _cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
