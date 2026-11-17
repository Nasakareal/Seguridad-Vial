import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/depositos_vehiculares_reporte_service.dart';

class DepositosVehicularesReporteScreen extends StatefulWidget {
  const DepositosVehicularesReporteScreen({super.key});

  @override
  State<DepositosVehicularesReporteScreen> createState() =>
      _DepositosVehicularesReporteScreenState();
}

class _DepositosVehicularesReporteScreenState
    extends State<DepositosVehicularesReporteScreen> {
  final _service = const DepositosVehicularesReporteService();
  final _search = TextEditingController();
  final _municipality = TextEditingController();
  final _line = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();

  DepositosVehicularesReportePage? _data;
  bool _loading = true;
  bool _downloading = false;
  bool _filtersExpanded = false;
  int _page = 1;
  int _perPage = 25;
  DateTime? _from;
  DateTime? _to;
  String _dateField = 'ingreso';
  String? _unitId;
  String? _origin;
  String? _status;
  String? _type;
  String? _brand;
  String? _deposit;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _setDefaultDateRange();
    _load();
  }

  void _setDefaultDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _to = today;
    _from = DepositosVehicularesReporteService.oneMonthBefore(today);
  }

  @override
  void dispose() {
    for (final controller in [_search, _municipality, _line, _model, _color]) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _filters => <String, dynamic>{
    'q': _search.text,
    'desde': _date(_from),
    'hasta': _date(_to),
    'fecha_campo': _dateField,
    'unidad_id': _unitId,
    'origen': _origin,
    'estado': _status,
    'municipio': _municipality.text,
    'corralon': _deposit,
    'tipo': _type,
    'marca': _brand,
    'color': _color.text,
    'linea': _line.text,
    'modelo': _model.text,
  };

  int get _activeFilterCount => _filters.entries.where((entry) {
    if (entry.key == 'fecha_campo' && entry.value == 'ingreso') return false;
    return entry.value != null && entry.value.toString().trim().isNotEmpty;
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
      if (mounted) setState(() => _error = error);
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
        '${directory.path}/depositos_vehiculares_${_date(DateTime.now())}.xlsx',
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
        ], text: 'Reporte general de depósitos vehiculares');
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
    for (final controller in [_search, _municipality, _line, _model, _color]) {
      controller.clear();
    }
    setState(() {
      _setDefaultDateRange();
      _dateField = 'ingreso';
      _unitId = null;
      _origin = null;
      _status = null;
      _type = null;
      _brand = null;
      _deposit = null;
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
        title: const Text('Depósitos vehiculares'),
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
    final units =
        options?.units.entries
            .map((entry) => MapEntry(entry.key.toString(), entry.value))
            .toList() ??
        const <MapEntry<String, String>>[];
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
                hintText: 'Placas, serie, inventario, marca, folio…',
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
                    _dropdown(
                      'Fecha que se consulta',
                      _dateField,
                      const ['ingreso', 'egreso'],
                      (value) =>
                          setState(() => _dateField = value ?? 'ingreso'),
                      labels: const {
                        'ingreso': 'Fecha de ingreso',
                        'egreso': 'Fecha de egreso',
                      },
                      allowEmpty: false,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _dateInput('Desde', _from, true)),
                        const SizedBox(width: 10),
                        Expanded(child: _dateInput('Hasta', _to, false)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _dropdownEntries('Unidad', _unitId, units, (value) {
                      setState(() => _unitId = value);
                    }),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _dropdown(
                            'Origen',
                            _origin,
                            const ['SINIESTROS', 'ACTIVIDADES', 'OTROS'],
                            (value) => setState(() => _origin = value),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dropdown(
                            'Estado',
                            _status,
                            const ['sin_liberacion', 'liberado'],
                            (value) => setState(() => _status = value),
                            labels: const {
                              'sin_liberacion': 'Sin liberación',
                              'liberado': 'Liberado',
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _dropdown(
                      'Corralón',
                      _deposit,
                      options?.deposits ?? const [],
                      (value) => setState(() => _deposit = value),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _dropdown(
                            'Tipo',
                            _type,
                            options?.types ?? const [],
                            (value) => setState(() => _type = value),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dropdown(
                            'Marca',
                            _brand,
                            options?.brands ?? const [],
                            (value) => setState(() => _brand = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _textRow('Municipio', _municipality, 'Color', _color),
                    const SizedBox(height: 10),
                    _textRow('Línea', _line, 'Modelo', _model),
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

  Widget _dateInput(String label, DateTime? value, bool from) {
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
    bool allowEmpty = true,
  }) {
    return _dropdownEntries(
      label,
      value,
      values.map((item) => MapEntry(item, labels[item] ?? item)).toList(),
      onChanged,
      allowEmpty: allowEmpty,
    );
  }

  Widget _dropdownEntries(
    String label,
    String? value,
    List<MapEntry<String, String>> values,
    ValueChanged<String?> onChanged, {
    bool allowEmpty = true,
  }) {
    final safeValue = values.any((item) => item.key == value) ? value : null;
    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        if (allowEmpty)
          const DropdownMenuItem<String>(value: null, child: Text('Todos')),
        for (final item in values)
          DropdownMenuItem<String>(
            value: item.key,
            child: Text(item.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _textRow(
    String leftLabel,
    TextEditingController left,
    String rightLabel,
    TextEditingController right,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: left,
            decoration: InputDecoration(labelText: leftLabel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: right,
            decoration: InputDecoration(labelText: rightLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_data!.total} vehículo${_data!.total == 1 ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          DropdownButton<int>(
            value: _perPage,
            underline: const SizedBox.shrink(),
            items: const [25, 50, 100]
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text('$value por página'),
                  ),
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
    if (_data == null || _data!.lastPage <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          tooltip: 'Página anterior',
          onPressed: _loading || _page <= 1
              ? null
              : () => _load(page: _page - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Página $_page de ${_data!.lastPage}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Página siguiente',
          onPressed: _loading || _page >= _data!.lastPage
              ? null
              : () => _load(page: _page + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
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
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFCCFBF1),
                foregroundColor: Color(0xFF0F766E),
                child: Icon(Icons.warehouse_outlined),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vehículos resguardados',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Consulta ingresos y liberaciones de todos los orígenes, incluido Conduce con Legalidad.',
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
  final DepositosVehicularesReporteSummary summary;

  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        Icons.directions_car_outlined,
        'Total',
        summary.total,
        const Color(0xFF2563EB),
      ),
      (
        Icons.lock_open_outlined,
        'Liberados',
        summary.released,
        const Color(0xFF059669),
      ),
      (
        Icons.warehouse_outlined,
        'En resguardo',
        summary.pendingRelease,
        const Color(0xFFD97706),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 600
            ? (constraints.maxWidth - 20) / 3
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in cards)
              SizedBox(
                width: width,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: item.$4.withValues(alpha: .12),
                          foregroundColor: item.$4,
                          child: Icon(item.$1),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.$3}',
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final DepositoVehicularReporteRow vehicle;

  const _VehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      vehicle.type,
      vehicle.model,
      vehicle.color,
    ].where((value) => value.isNotEmpty).join(' · ');
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
                CircleAvatar(
                  backgroundColor: vehicle.released
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFEF3C7),
                  foregroundColor: vehicle.released
                      ? const Color(0xFF047857)
                      : const Color(0xFFB45309),
                  child: Icon(
                    vehicle.released
                        ? Icons.lock_open_outlined
                        : Icons.warehouse_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.title.isEmpty
                            ? 'Vehículo #${vehicle.vehicleId}'
                            : vehicle.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(vehicle.released ? 'Liberado' : 'En resguardo'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _info(
              Icons.login,
              'Ingreso: ${_displayDateText(vehicle.admissionDate)}',
            ),
            if (vehicle.releaseDate.isNotEmpty)
              _info(
                Icons.logout,
                'Egreso: ${_displayDateText(vehicle.releaseDate)}${vehicle.releaseFolio.isEmpty ? '' : ' · Folio ${vehicle.releaseFolio}'}',
              ),
            _info(
              Icons.location_on_outlined,
              vehicle.location.isEmpty ? 'Sin ubicación' : vehicle.location,
            ),
            _info(
              Icons.warehouse_outlined,
              vehicle.deposit.isEmpty ? 'Sin corralón' : vehicle.deposit,
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (vehicle.origin.isNotEmpty)
                  _tag(Icons.source_outlined, vehicle.origin),
                if (vehicle.plates.isNotEmpty)
                  _tag(Icons.badge_outlined, vehicle.plates),
                if (vehicle.inventory.isNotEmpty)
                  _tag(Icons.tag, 'Inv. ${vehicle.inventory}'),
                if (vehicle.serialNumber.isNotEmpty)
                  _tag(Icons.qr_code, vehicle.serialNumber),
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
