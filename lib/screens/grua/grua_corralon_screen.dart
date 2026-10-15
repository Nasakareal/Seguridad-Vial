import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/grua_corralon_service.dart';
import '../login_screen.dart';

const _navy = Color(0xff0b3558);
const _teal = Color(0xff087f8c);

class GruaCorralonScreen extends StatefulWidget {
  const GruaCorralonScreen({super.key});

  @override
  State<GruaCorralonScreen> createState() => _GruaCorralonScreenState();
}

class _GruaCorralonScreenState extends State<GruaCorralonScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic> _summary = const {};
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  String? _gruaNombre;
  String _estado = 'pendientes';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await GruaCorralonService.fetch(
        estado: _estado,
        search: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _summary = result.summary;
        _gruaNombre = result.gruaNombre;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    try {
      await GruaCorralonService.exportAndShare(
        format: format,
        estado: _estado,
        search: _searchController.text,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _openEntrega(Map<String, dynamic> item) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GruaEntregaScreen(item: item)),
    );
    if (saved == true) await _load();
  }

  int _metric(String key) => int.tryParse('${_summary[key] ?? 0}') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeef3f7),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Control de corralón'),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Exportar',
              icon: const Icon(Icons.file_download_outlined),
              onSelected: _export,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('Exportar PDF'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'csv',
                  child: ListTile(
                    leading: Icon(Icons.table_view_outlined),
                    title: Text('Exportar Excel/CSV'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [_navy, Color(0xff126c7a)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (_gruaNombre ?? '').trim().isEmpty ? 'Mis servicios' : _gruaNombre!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Seguimiento, evidencia y entrega de vehículos',
          style: TextStyle(color: Colors.white.withValues(alpha: .78)),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Buscar placa, NIV, marca o inventario',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Buscar',
              onPressed: _load,
              icon: const Icon(Icons.arrow_forward),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            style: SegmentedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .12),
              foregroundColor: Colors.white,
              selectedBackgroundColor: Colors.white,
              selectedForegroundColor: _navy,
            ),
            segments: const [
              ButtonSegment(
                value: 'pendientes',
                icon: Icon(Icons.local_parking),
                label: Text('En corralón'),
              ),
              ButtonSegment(
                value: 'entregados',
                icon: Icon(Icons.check_circle_outline),
                label: Text('Entregados'),
              ),
            ],
            selected: {_estado},
            onSelectionChanged: (selected) {
              setState(() => _estado = selected.first);
              _load();
            },
          ),
        ),
      ],
    ),
  );

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _buildMetrics(),
          const SizedBox(height: 12),
          _buildCharts(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  _estado == 'pendientes'
                      ? 'Vehículos en corralón'
                      : 'Historial de entregas',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${_items.length} registros',
                style: TextStyle(color: Colors.blueGrey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_items.isEmpty)
            _EmptyState(pending: _estado == 'pendientes')
          else
            ..._items.map(
              (item) => _VehicleCard(
                item: item,
                pending: _estado == 'pendientes',
                onDeliver: () => _openEntrega(item),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    final metrics = [
      (
        'En corralón',
        _metric('pendientes'),
        Icons.local_parking,
        Colors.orange,
      ),
      ('Hoy', _metric('entregados_hoy'), Icons.today, Colors.green),
      ('Este mes', _metric('entregados_mes'), Icons.calendar_month, _teal),
      ('Total', _metric('total_entregados'), Icons.done_all, _navy),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _MetricCard(
                    label: metric.$1,
                    value: metric.$2,
                    icon: metric.$3,
                    color: metric.$4,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildCharts() {
    final rawSeries = _summary['serie_7_dias'];
    final series = rawSeries is List
        ? rawSeries
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final pendientes = _metric('pendientes');
    final mes = _metric('entregados_mes');
    final observations = _metric('con_observaciones_mes');
    final pieSections = pendientes + mes == 0
        ? [
            PieChartSectionData(
              value: 1,
              color: Colors.blueGrey.shade100,
              radius: 22,
              showTitle: false,
            ),
          ]
        : [
            PieChartSectionData(
              value: pendientes.toDouble(),
              color: Colors.orange,
              radius: 22,
              showTitle: false,
            ),
            PieChartSectionData(
              value: mes.toDouble(),
              color: _teal,
              radius: 22,
              showTitle: false,
            ),
          ];

    return Column(
      children: [
        Card(
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Entregas de los últimos 7 días',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 145,
                  child: BarChart(
                    BarChartData(
                      maxY: _chartMax(series),
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 25,
                            interval: 1,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= series.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${series[index]['etiqueta'] ?? ''}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(series.length, (index) {
                        final value =
                            double.tryParse('${series[index]['total'] ?? 0}') ??
                            0;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: value,
                              width: 17,
                              color: _teal,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 106,
                  height: 106,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 28,
                      sectionsSpace: 3,
                      sections: pieSections,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Flujo del mes',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _LegendDot(
                        color: Colors.orange,
                        label: '$pendientes todavía en corralón',
                      ),
                      _LegendDot(
                        color: _teal,
                        label: '$mes entregados este mes',
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$observations entregas con observaciones',
                        style: TextStyle(
                          color: observations > 0
                              ? Colors.deepOrange
                              : Colors.blueGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _chartMax(List<Map<String, dynamic>> series) {
    var max = 1;
    for (final item in series) {
      final value = int.tryParse('${item['total'] ?? 0}') ?? 0;
      if (value > max) max = value;
    }
    return (max + 1).toDouble();
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final bool pending;

  const _EmptyState({required this.pending});

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      child: Column(
        children: [
          Icon(
            pending ? Icons.garage_outlined : Icons.history,
            size: 58,
            color: Colors.blueGrey,
          ),
          const SizedBox(height: 10),
          Text(
            pending
                ? 'No tienes vehículos pendientes en corralón.'
                : 'Todavía no hay entregas registradas.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool pending;
  final VoidCallback onDeliver;

  const _VehicleCard({
    required this.item,
    required this.pending,
    required this.onDeliver,
  });

  String _text(String key, [String fallback = 'N/A']) {
    final value = item[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    final liberacion = item['liberacion'] is Map
        ? Map<String, dynamic>.from(item['liberacion'] as Map)
        : null;
    final fotos = item['fotos'] is Map
        ? Map<String, dynamic>.from(item['fotos'] as Map)
        : const <String, dynamic>{};
    final photoEntries = <(String, String)>[
      if ((fotos['inventario']?.toString() ?? '').isNotEmpty)
        ('Inventario', fotos['inventario'].toString()),
      if ((fotos['entrega']?.toString() ?? '').isNotEmpty)
        ('Entrega', fotos['entrega'].toString()),
    ];

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoEntries.isNotEmpty)
            SizedBox(
              height: 170,
              child: Row(
                children: photoEntries
                    .map(
                      (photo) => Expanded(
                        child: _AuthenticatedPhoto(
                          endpoint: photo.$2,
                          label: photo.$1,
                        ),
                      ),
                    )
                    .toList(),
              ),
            )
          else
            Container(
              height: 84,
              width: double.infinity,
              color: const Color(0xffe7eef3),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.no_photography_outlined, color: Colors.blueGrey),
                  SizedBox(height: 4),
                  Text('Sin fotografía', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_text('marca', '')} ${_text('linea', '')}'.trim(),
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: pending
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        pending ? 'EN CORRALÓN' : 'ENTREGADO',
                        style: TextStyle(
                          color: pending
                              ? Colors.orange.shade900
                              : Colors.green.shade900,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 22),
                _row(
                  Icons.pin_outlined,
                  'Placas',
                  _text('placas', 'Sin placas'),
                ),
                _row(Icons.numbers, 'NIV', _text('serie')),
                _row(
                  Icons.palette_outlined,
                  'Color / modelo',
                  '${_text('color')} / ${_text('modelo')}',
                ),
                _row(
                  Icons.receipt_long_outlined,
                  'Inventario',
                  _text('numero_inventario_grua'),
                ),
                if (pending)
                  _row(Icons.garage_outlined, 'Corralón', _text('corralon')),
                if (liberacion != null) ...[
                  _row(
                    Icons.person_outline,
                    'Recibió',
                    liberacion['persona_recibe']?.toString() ?? 'N/A',
                  ),
                  _row(
                    Icons.description_outlined,
                    'Folio SIERSE',
                    liberacion['sierse_folio']?.toString() ?? 'N/A',
                  ),
                  _row(
                    Icons.schedule,
                    'Fecha de entrega',
                    liberacion['fecha_entrega']?.toString() ?? 'N/A',
                  ),
                ],
                if (pending) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _teal,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: onDeliver,
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Registrar entrega'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 7),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _AuthenticatedPhoto extends StatelessWidget {
  final String endpoint;
  final String label;

  const _AuthenticatedPhoto({required this.endpoint, required this.label});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: GruaCorralonService.authenticatedHeaders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ColoredBox(
            color: Color(0xffe7eef3),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final url = GruaCorralonService.imageUrl(endpoint);
        final image = Image.network(
          url,
          headers: snapshot.data,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const ColoredBox(
            color: Color(0xffe7eef3),
            child: Center(child: Icon(Icons.broken_image_outlined, size: 36)),
          ),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.black,
                  insetPadding: const EdgeInsets.all(12),
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        minScale: .8,
                        maxScale: 5,
                        child: Image.network(
                          url,
                          headers: snapshot.data,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: IconButton.filled(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              child: image,
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .68),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class GruaEntregaScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const GruaEntregaScreen({super.key, required this.item});

  @override
  State<GruaEntregaScreen> createState() => _GruaEntregaScreenState();
}

class _GruaEntregaScreenState extends State<GruaEntregaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _persona = TextEditingController();
  final _identificacion = TextEditingController();
  final _telefono = TextEditingController();
  final _sierse = TextEditingController();
  final _observaciones = TextEditingController();
  String _condicion = 'CONFORME_INVENTARIO';
  XFile? _foto;
  bool _confirmado = false;
  bool _saving = false;

  @override
  void dispose() {
    _persona.dispose();
    _identificacion.dispose();
    _telefono.dispose();
    _sierse.dispose();
    _observaciones.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (file != null && mounted) setState(() => _foto = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_foto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toma o selecciona la foto de entrega.')),
      );
      return;
    }
    if (!_confirmado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirma la entrega del vehículo.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await GruaCorralonService.entregar(
        vehiculoId: int.parse(widget.item['id'].toString()),
        personaRecibe: _persona.text,
        identificacionRecibe: _identificacion.text,
        telefono: _telefono.text,
        sierseFolio: _sierse.text,
        condicionEntrega: _condicion,
        observaciones: _observaciones.text,
        fotoEntrega: _foto!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrega registrada correctamente.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final placas = widget.item['placas']?.toString() ?? 'Sin placas';
    return Scaffold(
      backgroundColor: const Color(0xffeef3f7),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text('Entrega · $placas'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Datos de liberación',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _field(_persona, 'Persona que recibe'),
                    _field(
                      _identificacion,
                      'Tipo y folio de identificación',
                      hint: 'Ej. INE 1234567890',
                    ),
                    _field(_telefono, 'Teléfono', required: false),
                    _field(_sierse, 'Folio de memoria SIERSE'),
                    DropdownButtonFormField<String>(
                      value: _condicion,
                      decoration: const InputDecoration(
                        labelText: 'Condición al entregar',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CONFORME_INVENTARIO',
                          child: Text('Conforme al inventario'),
                        ),
                        DropdownMenuItem(
                          value: 'CON_OBSERVACIONES',
                          child: Text('Con daños, faltantes u observaciones'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _condicion = value!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _observaciones,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Evidencia fotográfica *',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_foto != null)
                      FutureBuilder<Uint8List>(
                        future: _foto!.readAsBytes(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(
                              height: 170,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              snapshot.data!,
                              height: 210,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        height: 130,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xffe7eef3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 40),
                            SizedBox(height: 7),
                            Text('Agrega la foto de entrega'),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickPhoto(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Cámara'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickPhoto(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galería'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmado,
              onChanged: (value) =>
                  setState(() => _confirmado = value ?? false),
              title: const Text(
                'Confirmo que el vehículo fue entregado y la persona manifestó conformidad con la memoria descriptiva.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _teal,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Guardando…' : 'Confirmar entrega'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool required = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) => (value ?? '').trim().isEmpty ? 'Campo obligatorio' : null
          : null,
    ),
  );
}
