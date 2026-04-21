import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

import '../../services/auth_service.dart';
import '../../services/gruas_share_service.dart';

// CAMBIO: ahora importamos el SHOW
import '../../screens/vehiculos/vehiculo_show_screen.dart';

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
  List<Map<String, dynamic>> _delegaciones = <Map<String, dynamic>>[];
  Map<String, dynamic>? _semana;
  List<Map<String, dynamic>> _gruasView = <Map<String, dynamic>>[];

  final Set<int> _hiddenGruas = <int>{};
  bool _hideZero = false;
  int _unidadFiltroId = 1;
  int? _delegacionFiltroId;
  int? _gruaFiltroId;

  // --- NUEVO: modo día/semana ---
  bool _modoDia = false;
  DateTime _selectedDay = DateTime.now();

  // Semana
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
    final weekday = d.weekday; // 1=lun
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

  String _rangoLabel() {
    if (_modoDia) return 'Día: ${_fmtShort(_selectedDay)}';
    return '${_fmtShort(_start)} - ${_fmtShort(_end)}';
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _apiUri(String path, Map<String, String> params) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: params);
  }

  Map<String, String> _baseFiltroParams({bool includeGrua = false}) {
    final params = <String, String>{'unidad_id': '$_unidadFiltroId'};

    if (_unidadFiltroId == 2 && _delegacionFiltroId != null) {
      params['delegacion_id'] = '$_delegacionFiltroId';
    }

    if (includeGrua && _gruaFiltroId != null) {
      params['gruas'] = '$_gruaFiltroId';
    }

    return params;
  }

  // --- Guard para cuando el server devuelve HTML ---
  Map<String, dynamic> _safeJsonMapFromResponse(http.Response res) {
    final body = res.body;

    final head = body.trimLeft();
    if (head.startsWith('<!doctype html') || head.startsWith('<html')) {
      throw Exception(
        'El servidor devolvió HTML (no JSON). '
        'Status ${res.statusCode}. '
        'Probable: token inválido / sin permisos / error del servidor.\n'
        'Primeros caracteres: ${head.substring(0, head.length > 60 ? 60 : head.length)}',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Respuesta inesperada (no es Map JSON).');
    }
    return decoded;
  }

  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarCatalogoGruas(),
      _cargarResumenDetallado(),
      if (_unidadFiltroId == 2) _cargarDelegaciones(),
    ]);
    _rebuildViewDetallado();
  }

  Future<void> _cargarCatalogoGruas() async {
    setState(() {
      _cargandoLista = true;
      _errorLista = null;
    });

    try {
      final uri = _apiUri('/gruas', _baseFiltroParams());
      final res = await http.get(uri, headers: await _headers());

      if (res.statusCode != 200) {
        final head = res.body.trimLeft();
        if (head.startsWith('<!doctype html') || head.startsWith('<html')) {
          throw Exception(
            'Error ${res.statusCode}: HTML devuelto por servidor.',
          );
        }
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }

      final decoded = _safeJsonMapFromResponse(res);

      final list = (decoded['data'] is List)
          ? (decoded['data'] as List)
          : <dynamic>[];

      final items = <Map<String, dynamic>>[];
      for (final e in list) {
        if (e is Map) items.add(Map<String, dynamic>.from(e));
      }

      if (!mounted) return;
      setState(() {
        _gruas = items;
        if (_gruaFiltroId != null &&
            !items.any((g) => _toInt(g['id']) == _gruaFiltroId)) {
          _gruaFiltroId = null;
        }
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

  Future<void> _cargarDelegaciones() async {
    try {
      final uri = _apiUri('/gruas/delegaciones', {'unidad_id': '2'});
      final res = await http.get(uri, headers: await _headers());

      if (res.statusCode != 200) {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }

      final decoded = _safeJsonMapFromResponse(res);
      final list = (decoded['data'] is List)
          ? (decoded['data'] as List)
          : <dynamic>[];

      final items = <Map<String, dynamic>>[];
      for (final e in list) {
        if (e is Map) items.add(Map<String, dynamic>.from(e));
      }

      if (!mounted) return;
      setState(() {
        _delegaciones = items;
        if (_delegacionFiltroId != null &&
            !items.any((d) => _toInt(d['id']) == _delegacionFiltroId)) {
          _delegacionFiltroId = null;
          _gruaFiltroId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _delegaciones = <Map<String, dynamic>>[];
      });
    }
  }

  // --- CAMBIO: decide week/day ---
  Future<void> _cargarResumenDetallado() async {
    setState(() {
      _cargandoChart = true;
      _errorChart = null;
    });

    try {
      final params = _baseFiltroParams(includeGrua: true);

      if (_modoDia) {
        final day = _fmtYmd(_selectedDay);
        params['day'] = day;
      } else {
        final from = _fmtYmd(_start);
        final to = _fmtYmd(_end);
        params['from'] = from;
        params['to'] = to;
      }

      final uri = _apiUri('/gruas/resumen-semanal-detallado', params);
      final res = await http.get(uri, headers: await _headers());

      if (res.statusCode != 200) {
        final head = res.body.trimLeft();
        if (head.startsWith('<!doctype html') || head.startsWith('<html')) {
          throw Exception(
            'Error ${res.statusCode}: HTML devuelto.\n'
            'Esto pasa cuando el token no llega, no tienes permiso (can:ver estadisticas), '
            'o el servidor devolvió página de error.',
          );
        }
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }

      final decoded = _safeJsonMapFromResponse(res);

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
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        final id = _toInt(m['id']);
        if (id > 0) byIdSemana[id] = m;
      }
    }

    final merged = <Map<String, dynamic>>[];
    for (final g in _gruas) {
      final id = _toInt(g['id']);
      final nombre = (g['nombre'] ?? '').toString();

      final sem = byIdSemana[id];
      final unidadIds = {
        _unidadFiltroId,
        ..._extractUnidadIds(g),
        if (sem != null) ..._extractUnidadIds(sem),
      }.toList()..sort();

      final count = sem != null ? _toInt(sem['servicios_count']) : 0;
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
        'servicios_semana': count,
        'fecha_ultimo_servicio': ultimo,
        'vehiculos': vehiculos,
        'unidad_ids': unidadIds,
      });
    }

    if (!mounted) return;
    setState(() => _gruasView = merged);
  }

  void _refresh() => _cargarTodo();

  void _prevWeek() {
    if (_modoDia) return;
    setState(() {
      _anchor = _anchor.subtract(const Duration(days: 7));
      _recalcWeek();
    });
    _cargarTodo();
  }

  void _nextWeek() {
    if (_modoDia) return;
    setState(() {
      _anchor = _anchor.add(const Duration(days: 7));
      _recalcWeek();
    });
    _cargarTodo();
  }

  Future<void> _pickWeekOrDay() async {
    final initial = _modoDia ? _selectedDay : _anchor;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: _modoDia ? 'Elige el día' : 'Elige un día de la semana',
    );

    if (picked == null) return;

    if (_modoDia) {
      setState(() => _selectedDay = picked);
    } else {
      setState(() {
        _anchor = picked;
        _recalcWeek();
      });
    }

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

  void _setUnidadFiltro(int unidadId) {
    if (_unidadFiltroId == unidadId) return;

    setState(() {
      _unidadFiltroId = unidadId;
      _delegacionFiltroId = null;
      _gruaFiltroId = null;
      _hiddenGruas.clear();
    });
    _cargarTodo();
  }

  void _setDelegacionFiltro(int? delegacionId) {
    if (_delegacionFiltroId == delegacionId) return;

    setState(() {
      _delegacionFiltroId = delegacionId;
      _gruaFiltroId = null;
      _hiddenGruas.clear();
    });
    _cargarTodo();
  }

  void _setGruaFiltro(int? gruaId) {
    if (_gruaFiltroId == gruaId) return;

    setState(() {
      _gruaFiltroId = gruaId;
      _hiddenGruas.clear();
    });
    _cargarTodo();
  }

  List<Map<String, dynamic>> _unitFilteredGruasView() {
    return _gruasView.where((g) {
      final ids = _extractUnidadIds(g);
      return ids.contains(_unidadFiltroId);
    }).toList();
  }

  List<Map<String, dynamic>> _filteredGruasView() {
    var list = _unitFilteredGruasView();

    if (_gruaFiltroId != null) {
      list = list.where((g) => _toInt(g['id']) == _gruaFiltroId).toList();
    }

    list = list.where((g) => !_hiddenGruas.contains(_toInt(g['id']))).toList();

    if (_hideZero) {
      list = list.where((g) => _toInt(g['servicios_semana']) > 0).toList();
    }

    list.sort(
      (a, b) => _toInt(
        b['servicios_semana'],
      ).compareTo(_toInt(a['servicios_semana'])),
    );
    return list;
  }

  // CAMBIO: ir a SHOW en lugar de EDIT
  Future<void> _irAVerVehiculo(Map<String, dynamic> v) async {
    final vehiculoId = _toInt(v['vehiculo_id']);
    final hechoId = _toInt(v['hecho_id']);

    if (vehiculoId <= 0) {
      _showInfo('No se encontró vehiculo_id para abrir el vehículo.');
      return;
    }

    if (hechoId <= 0) {
      _showInfo(
        'No viene hecho_id en el JSON.\n\n'
        'El backend debe regresar hecho_id dentro de cada item de "vehiculos".',
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const VehiculoShowScreen(),
        settings: RouteSettings(
          arguments: {'hechoId': hechoId, 'vehiculoId': vehiculoId},
        ),
      ),
    );
  }

  void _showInfo(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aviso'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _periodoShareLabel() {
    if (_modoDia) {
      return 'Día ${_fmtShort(_selectedDay)}';
    }

    return 'Semana ${_fmtShort(_start)} - ${_fmtShort(_end)}';
  }

  String _textoVehiculoParaShare(Map<String, dynamic> v, int index) {
    final placas = (v['placas'] ?? '').toString().trim();
    final marca = (v['marca'] ?? '').toString().trim();
    final linea = (v['linea'] ?? '').toString().trim();
    final modelo = (v['modelo'] ?? '').toString().trim();
    final color = (v['color'] ?? '').toString().trim();
    final tipo = (v['tipo_vehiculo'] ?? v['tipo'] ?? '').toString().trim();
    final aseguradora = (v['aseguradora'] ?? '').toString().trim();
    final tieneSeguro = _toInt(v['tiene_seguro']) == 1;
    final servicioId = _toInt(v['servicio_id']);
    final vehiculoId = _toInt(v['vehiculo_id']);
    final hechoId = _toInt(v['hecho_id']);
    final fecha = (v['fecha_servicio'] ?? '').toString().trim();

    final descripcion = [
      marca,
      linea,
      modelo,
    ].where((s) => s.trim().isNotEmpty).join(' ');

    final lineas = <String>[
      '$index.',
      'Placas: ${placas.isNotEmpty ? placas : 'Sin placas'}',
      if (descripcion.isNotEmpty) 'Vehículo: $descripcion',
      if (tipo.isNotEmpty) 'Tipo: $tipo',
      if (color.isNotEmpty) 'Color: $color',
      if (aseguradora.isNotEmpty) 'Aseguradora: $aseguradora',
      'Seguro: ${tieneSeguro ? 'Sí' : 'No'}',
      if (servicioId > 0) 'Servicio: #$servicioId',
      if (vehiculoId > 0) 'Vehículo ID: #$vehiculoId',
      if (hechoId > 0) 'Hecho: #$hechoId',
      if (fecha.isNotEmpty) 'Fecha: $fecha',
    ];

    return lineas.join('\n');
  }

  String _buildGruaShareText(Map<String, dynamic> g) {
    final nombre = (g['nombre'] ?? 'Sin nombre').toString().trim();
    final conteo = _toInt(g['servicios_semana']);
    final vehiculos = (g['vehiculos'] is List)
        ? (g['vehiculos'] as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
        : <Map<String, dynamic>>[];

    final lineas = <String>[
      'Grúa: $nombre',
      'Periodo: ${_periodoShareLabel()}',
      _modoDia
          ? 'Servicios del día: $conteo'
          : 'Servicios de la semana: $conteo',
    ];

    if (vehiculos.isEmpty) {
      lineas.add('');
      lineas.add('Sin vehículos/servicios registrados en este periodo.');
      return lineas.join('\n');
    }

    lineas.add('');
    lineas.add('Vehículos remolcados:');

    for (var i = 0; i < vehiculos.length; i++) {
      lineas.add('');
      lineas.add(_textoVehiculoParaShare(vehiculos[i], i + 1));
    }

    return lineas.join('\n');
  }

  Future<void> _compartirGruaEnWhatsapp(Map<String, dynamic> g) async {
    final texto = _buildGruaShareText(g);

    try {
      await GruasShareService.compartirTextoEnWhatsapp(texto: texto);
    } catch (e) {
      if (!mounted) return;
      _showInfo('No se pudo compartir la información de la grúa.\n\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rango = _rangoLabel();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Grúas'),
        backgroundColor: Colors.blue,
        actions: [
          Row(
            children: [
              const Text('Día', style: TextStyle(fontSize: 12)),
              Switch(
                value: _modoDia,
                onChanged: (v) {
                  setState(() => _modoDia = v);
                  _cargarTodo();
                },
              ),
            ],
          ),
          if (!_modoDia)
            IconButton(
              tooltip: 'Semana anterior',
              onPressed: _prevWeek,
              icon: const Icon(Icons.chevron_left),
            ),
          IconButton(
            tooltip: _modoDia ? 'Elegir día' : 'Elegir semana',
            onPressed: _pickWeekOrDay,
            icon: const Icon(Icons.date_range),
          ),
          if (!_modoDia)
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
            onPrev: _modoDia ? null : _prevWeek,
            onPick: _pickWeekOrDay,
            onNext: _modoDia ? null : _nextWeek,
            modoDia: _modoDia,
          ),
          const SizedBox(height: 12),
          _buildFiltersCard(),
          const SizedBox(height: 12),
          _buildChartCard(rango),
          const SizedBox(height: 12),
          Text(
            _modoDia
                ? 'Listado (día seleccionado)'
                : 'Listado (semana seleccionada)',
            style: const TextStyle(
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
    if (_cargandoLista || _cargandoChart) return const SizedBox.shrink();

    final list = _unitFilteredGruasView();
    list.sort(
      (a, b) => (a['nombre'] ?? '').toString().compareTo(
        (b['nombre'] ?? '').toString(),
      ),
    );
    final delegacionValue =
        _delegacionFiltroId != null &&
            _delegaciones.any((d) => _toInt(d['id']) == _delegacionFiltroId)
        ? _delegacionFiltroId
        : null;
    final gruaValue =
        _gruaFiltroId != null &&
            list.any((g) => _toInt(g['id']) == _gruaFiltroId)
        ? _gruaFiltroId
        : null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: .06),
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
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(
                value: 1,
                label: Text('Siniestros'),
                icon: Icon(Icons.car_crash),
              ),
              ButtonSegment<int>(
                value: 2,
                label: Text('Delegaciones'),
                icon: Icon(Icons.local_police),
              ),
            ],
            selected: {_unidadFiltroId},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              _setUnidadFiltro(selection.first);
            },
          ),
          if (_unidadFiltroId == 2) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: delegacionValue,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Delegación',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Todas las delegaciones'),
                ),
                ..._delegaciones.map((d) {
                  final id = _toInt(d['id']);
                  final nombre = _delegacionNombre(d);
                  return DropdownMenuItem<int?>(value: id, child: Text(nombre));
                }),
              ],
              onChanged: _setDelegacionFiltro,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              value: gruaValue,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Grúa',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Todas las grúas'),
                ),
                ...list.map((g) {
                  final id = _toInt(g['id']);
                  final nombre = (g['nombre'] ?? 'Sin nombre').toString();
                  return DropdownMenuItem<int?>(value: id, child: Text(nombre));
                }),
              ],
              onChanged: _setGruaFiltro,
            ),
          ],
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
            'Toca para ocultar/mostrar grúas de ${_unidadFiltroLabel()}:',
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
                selectedColor: Colors.blue.withValues(alpha: .15),
                checkmarkColor: Colors.blue,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String rango) {
    final titulo = _modoDia
        ? 'Servicios por grúa (${_unidadFiltroLabel()}, día)'
        : 'Servicios por grúa (${_unidadFiltroLabel()}, semana)';

    if (_cargandoChart) {
      return _ChartCardShell(
        title: titulo,
        subtitle: rango,
        child: const _ChartLoading(),
      );
    }

    if (_errorChart != null) {
      return _ChartCardShell(
        title: titulo,
        subtitle: rango,
        child: _ChartError(message: '$_errorChart'),
      );
    }

    final visible = _filteredGruasView();
    final total = visible.fold<int>(
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
      title: titulo,
      subtitle: rango,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BigNumberLine(
            label: _modoDia
                ? 'Total (visible) del día'
                : 'Total semanal (visible)',
            value: '$total',
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
                      getTitlesWidget: (v, meta) => Text(
                        v.toInt().toString(),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                        ),
                      ),
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
                'Sin servicios (o todas ocultas) en el periodo seleccionado.',
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
        final conteo = _toInt(g['servicios_semana']);

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
            subtitle: Text(
              _modoDia
                  ? 'Servicios (día): $conteo'
                  : 'Servicios (semana): $conteo',
            ),
            trailing: SizedBox(
              width: 96,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Compartir por WhatsApp',
                    onPressed: () => _compartirGruaEnWhatsapp(g),
                    icon: Image.asset(
                      'assets/icon/whatsapp_share.png',
                      width: 22,
                      height: 22,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ocultar esta grúa',
                    onPressed: () => _toggleHidden(gruaId),
                    icon: const Icon(Icons.visibility_off),
                  ),
                ],
              ),
            ),
            children: [
              if (vehiculos.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Text(
                    'Sin vehículos/servicios en este periodo.',
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
                      final vehiculoId = _toInt(v['vehiculo_id']);
                      final hechoId = _toInt(v['hecho_id']);
                      final fecha = (v['fecha_servicio'] ?? '').toString();

                      final title = [
                        if (placas.isNotEmpty) placas,
                        if (tipo.isNotEmpty) tipo,
                      ].join(' · ');

                      final desc = [
                        if (marca.isNotEmpty ||
                            linea.isNotEmpty ||
                            modelo.isNotEmpty)
                          [
                            marca,
                            linea,
                            modelo,
                          ].where((s) => s.isNotEmpty).join(' '),
                        if (color.isNotEmpty) color,
                        if (aseguradora.isNotEmpty) 'Aseg: $aseguradora',
                        'Seguro: ${tieneSeguro ? 'SÍ' : 'NO'}',
                        if (servicioId > 0) 'Servicio #$servicioId',
                        if (vehiculoId > 0) 'Vehículo #$vehiculoId',
                        if (hechoId > 0) 'Hecho #$hechoId',
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
                          // CAMBIO: ahora abre el SHOW
                          onTap: () => _irAVerVehiculo(v),
                          trailing: const Icon(Icons.chevron_right),
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

  String _unidadFiltroLabel() {
    if (_unidadFiltroId == 2) return 'Delegaciones';
    return 'Siniestros';
  }

  String _delegacionNombre(Map<String, dynamic> delegacion) {
    final nombreConClave = (delegacion['nombre_con_clave'] ?? '')
        .toString()
        .trim();
    if (nombreConClave.isNotEmpty) return nombreConClave;

    final nombre = (delegacion['nombre'] ?? '').toString().trim();
    final clave = (delegacion['clave'] ?? '').toString().trim();
    if (nombre.isEmpty) return 'Delegación';
    if (clave.isEmpty) return nombre;
    return '$nombre ($clave)';
  }

  List<int> _extractUnidadIds(Map<String, dynamic> raw) {
    final ids = <int>{};

    void add(dynamic value) {
      final id = _toInt(value);
      if (id > 0) ids.add(id);
    }

    void scan(dynamic value) {
      if (value == null) return;

      if (value is int || value is double || value is String) {
        add(value);
        return;
      }

      if (value is Map) {
        add(value['unidad_id']);
        add(value['unidad_org_id']);
        add(value['id']);
        scan(value['pivot']);
        scan(value['unidad']);
        scan(value['unidades']);
        return;
      }

      if (value is Iterable) {
        for (final item in value) {
          scan(item);
        }
      }
    }

    scan(raw['unidad_ids']);
    scan(raw['unidades_ids']);
    scan(raw['unidad_id']);
    scan(raw['unidad_org_id']);
    scan(raw['unidad_grua']);
    scan(raw['unidades_gruas']);
    scan(raw['unidadGrua']);
    scan(raw['unidadesGruas']);
    scan(raw['unidades']);
    scan(raw['unidad']);

    return ids.toList()..sort();
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
  final VoidCallback? onPrev;
  final Future<void> Function() onPick;
  final VoidCallback? onNext;
  final bool modoDia;

  const _WeekBanner({
    required this.rango,
    required this.onPrev,
    required this.onPick,
    required this.onNext,
    required this.modoDia,
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
                Text(
                  modoDia ? 'Día seleccionado' : 'Semana seleccionada',
                  style: const TextStyle(
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
            label: Text(modoDia ? 'Cambiar día' : 'Cambiar'),
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
            color: Colors.black.withValues(alpha: .06),
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
        color: Colors.red.withValues(alpha: .06),
        border: Border.all(color: Colors.red.withValues(alpha: .2)),
      ),
      child: Text(
        'No se pudo cargar.\n$message',
        style: const TextStyle(fontSize: 12.5),
      ),
    );
  }
}
