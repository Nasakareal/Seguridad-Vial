import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

import '../../services/auth_service.dart';

class GruasScreen extends StatefulWidget {
  const GruasScreen({super.key});

  @override
  State<GruasScreen> createState() => _GruasScreenState();
}

class _GruasScreenState extends State<GruasScreen> {
  bool _cargandoLista = true;
  bool _cargandoChart = true;

  String? _errorLista;
  String? _errorChart;

  List<Map<String, dynamic>> _gruas = <Map<String, dynamic>>[];

  Map<String, dynamic>? _semana;

  List<Map<String, dynamic>> _gruasView = <Map<String, dynamic>>[];

  final Set<int> _hiddenGruas = <int>{};
  bool _hideZero = false;

  DateTime _anchor = DateTime.now();
  late DateTime _start;
  late DateTime _end;

  static const String _baseUrl = 'https://seguridadvial-mich.com/api';

  @override
  void initState() {
    super.initState();
    _recalcWeek();
    _cargarTodo();
  }

  void _recalcWeek() {
    final d = DateTime(_anchor.year, _anchor.month, _anchor.day);
    final weekday = d.weekday;
    final monday = d.subtract(Duration(days: weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    _start = DateTime(monday.year, monday.month, monday.day);
    _end = DateTime(sunday.year, sunday.month, sunday.day);
  }

  String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _fmtShort(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final mon = d.month.toString().padLeft(2, '0');
    return '$day/$mon/${d.year}';
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _cargarTodo() async {
    await Future.wait([_cargarCatalogoGruas(), _cargarSemanaDetallada()]);
    _rebuildViewDetallado();
  }

  Future<void> _cargarCatalogoGruas() async {
    setState(() {
      _cargandoLista = true;
      _errorLista = null;
    });

    try {
      final uri = Uri.parse('$_baseUrl/gruas');
      final res = await http.get(uri, headers: await _headers());

      if (res.statusCode != 200) {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }

      final decoded = jsonDecode(res.body);

      final list = (decoded is Map && decoded['data'] is List)
          ? (decoded['data'] as List)
          : (decoded is List ? decoded : <dynamic>[]);

      final items = <Map<String, dynamic>>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) items.add(e);
      }

      if (!mounted) return;
      setState(() {
        _gruas = items;
        _cargandoLista = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorLista = '$e';
        _cargandoLista = false;
      });
    }
  }

  Future<void> _cargarSemanaDetallada() async {
    setState(() {
      _cargandoChart = true;
      _errorChart = null;
    });

    try {
      final from = _fmtYmd(_start);
      final to = _fmtYmd(_end);

      final uri = Uri.parse(
        '$_baseUrl/gruas/resumen-semanal-detallado?from=$from&to=$to',
      );

      final res = await http.get(uri, headers: await _headers());

      if (res.statusCode != 200) {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Respuesta inesperada en resumen semanal detallado');
      }

      if (!mounted) return;
      setState(() {
        _semana = decoded;
        _cargandoChart = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorChart = '$e';
        _cargandoChart = false;
      });
    }
  }

  void _rebuildViewDetallado() {
    final semanaRoot = _semana ?? const <String, dynamic>{};
    final rawSem = (semanaRoot['data'] as List? ?? const []);

    final byIdSemana = <int, Map<String, dynamic>>{};
    for (final e in rawSem) {
      if (e is Map<String, dynamic>) {
        final id = _toInt(e['id']);
        if (id > 0) byIdSemana[id] = e;
      }
    }

    final merged = <Map<String, dynamic>>[];
    for (final g in _gruas) {
      final id = _toInt(g['id']);
      final nombre = (g['nombre'] ?? '').toString();

      final sem = byIdSemana[id];

      final semanal = sem != null ? _toInt(sem['servicios_count']) : 0;
      final ultimo = sem?['fecha_ultimo_servicio'];

      final vehiculos = (sem?['vehiculos'] is List)
          ? (sem!['vehiculos'] as List)
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList()
          : <Map<String, dynamic>>[];

      merged.add({
        'id': id,
        'nombre': nombre,
        'servicios_semana': semanal,
        'fecha_ultimo_servicio': ultimo,
        'vehiculos': vehiculos,
      });
    }

    if (!mounted) return;
    setState(() {
      _gruasView = merged;
    });
  }

  void _refresh() => _cargarTodo();

  void _prevWeek() {
    setState(() {
      _anchor = _anchor.subtract(const Duration(days: 7));
      _recalcWeek();
    });
    _cargarTodo();
  }

  void _nextWeek() {
    setState(() {
      _anchor = _anchor.add(const Duration(days: 7));
      _recalcWeek();
    });
    _cargarTodo();
  }

  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Elige un día de la semana',
    );

    if (picked == null) return;

    setState(() {
      _anchor = picked;
      _recalcWeek();
    });

    _cargarTodo();
  }

  void _toggleHidden(int gruaId) {
    setState(() {
      if (_hiddenGruas.contains(gruaId)) {
        _hiddenGruas.remove(gruaId);
      } else {
        _hiddenGruas.add(gruaId);
      }
    });
  }

  void _clearHidden() {
    setState(() {
      _hiddenGruas.clear();
      _hideZero = false;
    });
  }

  List<Map<String, dynamic>> _filteredGruasView() {
    var list = [..._gruasView];

    list = list.where((g) => !_hiddenGruas.contains(_toInt(g['id']))).toList();

    if (_hideZero) {
      list = list.where((g) => _toInt(g['servicios_semana']) > 0).toList();
    }

    list.sort((a, b) {
      final ta = _toInt(a['servicios_semana']);
      final tb = _toInt(b['servicios_semana']);
      return tb.compareTo(ta);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final rango = '${_fmtShort(_start)} - ${_fmtShort(_end)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Grúas'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            tooltip: 'Semana anterior',
            onPressed: _prevWeek,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Elegir semana',
            onPressed: _pickWeek,
            icon: const Icon(Icons.date_range),
          ),
          IconButton(
            tooltip: 'Semana siguiente',
            onPressed: _nextWeek,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          _WeekBanner(
            rango: rango,
            onPrev: _prevWeek,
            onPick: _pickWeek,
            onNext: _nextWeek,
          ),
          const SizedBox(height: 12),
          _buildFiltersCard(),
          const SizedBox(height: 12),
          _buildChartCard(rango),
          const SizedBox(height: 12),
          const Text(
            'Listado (semana seleccionada)',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          _buildLista(),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    if (_cargandoLista || _cargandoChart) {
      return const SizedBox.shrink();
    }

    final list = [..._gruasView];
    list.sort(
      (a, b) => (a['nombre'] ?? '').toString().compareTo(
        (b['nombre'] ?? '').toString(),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.06),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtros',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ocultar grúas sin servicios'),
                  value: _hideZero,
                  onChanged: (v) => setState(() => _hideZero = v),
                ),
              ),
              TextButton.icon(
                onPressed: _clearHidden,
                icon: const Icon(Icons.clear),
                label: const Text('Limpiar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Toca para ocultar/mostrar grúas:',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: list.map((g) {
              final id = _toInt(g['id']);
              final nombre = (g['nombre'] ?? '').toString();
              final hidden = _hiddenGruas.contains(id);

              return FilterChip(
                selected: !hidden,
                label: Text(nombre),
                onSelected: (_) => _toggleHidden(id),
                selectedColor: Colors.blue.withOpacity(.15),
                checkmarkColor: Colors.blue,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String rango) {
    if (_cargandoChart) {
      return const _ChartCardShell(
        title: 'Servicios por grúa (semana)',
        subtitle: 'Conteo semanal',
        child: _ChartLoading(),
      );
    }
    if (_errorChart != null) {
      return _ChartCardShell(
        title: 'Servicios por grúa (semana)',
        subtitle: rango,
        child: _ChartError(message: '$_errorChart'),
      );
    }

    final visible = _filteredGruasView();

    final totalSemanal = visible.fold<int>(
      0,
      (sum, e) => sum + _toInt(e['servicios_semana']),
    );

    final top = visible.take(10).toList();

    final maxY = _safeMax(
      top.map((e) => _toInt(e['servicios_semana'])),
    ).toDouble();

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < top.length; i++) {
      final c = _toInt(top[i]['servicios_semana']);
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: c.toDouble(),
              width: 14,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      );
    }

    return _ChartCardShell(
      title: 'Servicios por grúa (semana)',
      subtitle: rango,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BigNumberLine(
            label: 'Total semanal (visible)',
            value: '$totalSemanal',
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: (maxY <= 1) ? 1 : (maxY + 1),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: _niceInterval(maxY),
                      getTitlesWidget: (v, meta) {
                        return Text(
                          v.toInt().toString(),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= top.length) {
                          return const SizedBox.shrink();
                        }

                        final name = (top[i]['nombre'] ?? '').toString();
                        final short = name.length > 8
                            ? '${name.substring(0, 8)}…'
                            : name;

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            short,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 10.5,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: groups,
              ),
            ),
          ),
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Sin servicios (o todas ocultas) en la semana seleccionada.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    if (_cargandoLista || _cargandoChart) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorLista != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Error: $_errorLista'),
      );
    }

    if (_errorChart != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Error: $_errorChart'),
      );
    }

    final list = _filteredGruasView();

    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No hay grúas visibles con los filtros actuales.'),
      );
    }

    return Column(
      children: list.map((g) {
        final gruaId = _toInt(g['id']);
        final nombre = (g['nombre'] ?? 'Sin nombre').toString();
        final semanal = _toInt(g['servicios_semana']);

        final vehiculos = (g['vehiculos'] is List)
            ? (g['vehiculos'] as List)
                  .whereType<Map>()
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList()
            : <Map<String, dynamic>>[];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ExpansionTile(
            leading: const Icon(Icons.local_shipping),
            title: Text(nombre),
            subtitle: Text('Servicios (semana): $semanal'),
            trailing: IconButton(
              tooltip: 'Ocultar esta grúa',
              onPressed: () => _toggleHidden(gruaId),
              icon: const Icon(Icons.visibility_off),
            ),
            children: [
              if (vehiculos.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Text(
                    'Sin vehículos/servicios en esta semana.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  child: Column(
                    children: vehiculos.map((v) {
                      final placas = (v['placas'] ?? '').toString().trim();
                      final marca = (v['marca'] ?? '').toString().trim();
                      final linea = (v['linea'] ?? '').toString().trim();
                      final modelo = (v['modelo'] ?? '').toString().trim();
                      final color = (v['color'] ?? '').toString().trim();

                      final tipo = (v['tipo_vehiculo'] ?? v['tipo'] ?? '')
                          .toString()
                          .trim();

                      final aseguradora = (v['aseguradora'] ?? '')
                          .toString()
                          .trim();

                      final tieneSeguroInt = _toInt(v['tiene_seguro']);
                      final tieneSeguro = tieneSeguroInt == 1;

                      final servicioId = _toInt(v['servicio_id']);
                      final fecha = (v['fecha_servicio'] ?? '').toString();

                      final title = [
                        if (placas.isNotEmpty) placas,
                        if (tipo.isNotEmpty) tipo,
                      ].join(' · ');

                      final desc = [
                        if (marca.isNotEmpty ||
                            linea.isNotEmpty ||
                            modelo.isNotEmpty)
                          '${[marca, linea, modelo].where((s) => s.isNotEmpty).join(' ')}',
                        if (color.isNotEmpty) color,
                        if (aseguradora.isNotEmpty) 'Aseg: $aseguradora',
                        'Seguro: ${tieneSeguro ? 'SÍ' : 'NO'}',
                        if (servicioId > 0) 'Servicio #$servicioId',
                        if (fecha.isNotEmpty) fecha,
                      ].where((s) => s.trim().isNotEmpty).join(' · ');

                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                          color: const Color(0xFFF9FAFB),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            tieneSeguro ? Icons.verified : Icons.warning_amber,
                          ),
                          title: Text(title.isEmpty ? 'Vehículo' : title),
                          subtitle: Text(desc),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static int _safeMax(Iterable<int> values) {
    var m = 0;
    for (final v in values) {
      if (v > m) m = v;
    }
    return m;
  }

  static double _niceInterval(double maxY) {
    if (maxY <= 5) return 1;
    if (maxY <= 10) return 2;
    if (maxY <= 20) return 5;
    if (maxY <= 50) return 10;
    return 20;
  }
}

class _WeekBanner extends StatelessWidget {
  final String rango;
  final VoidCallback onPrev;
  final Future<void> Function() onPick;
  final VoidCallback onNext;

  const _WeekBanner({
    required this.rango,
    required this.onPrev,
    required this.onPick,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Semana seleccionada',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(rango, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () async => onPick(),
            icon: const Icon(Icons.date_range),
            label: const Text('Cambiar'),
          ),
          const SizedBox(width: 6),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _ChartCardShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCardShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.06),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BigNumberLine extends StatelessWidget {
  final String label;
  final String value;

  const _BigNumberLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      ),
    );
  }
}

class _ChartError extends StatelessWidget {
  final String message;

  const _ChartError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.red.withOpacity(.06),
        border: Border.all(color: Colors.red.withOpacity(.2)),
      ),
      child: Text(
        'No se pudo cargar.\n$message',
        style: const TextStyle(fontSize: 12.5),
      ),
    );
  }
}
