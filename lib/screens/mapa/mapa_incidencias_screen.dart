import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../services/auth_service.dart';

class MapaIncidenciasScreen extends StatefulWidget {
  const MapaIncidenciasScreen({super.key});

  @override
  State<MapaIncidenciasScreen> createState() => _MapaIncidenciasScreenState();
}

class _MapaIncidenciasScreenState extends State<MapaIncidenciasScreen>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _mapKey = GlobalKey();

  bool _loading = true;
  String? _error;
  DateTime? _lastFetchAt;

  List<_IncCluster> _clusters = const [];

  DateTime? _desde;
  DateTime? _hasta;
  final TextEditingController _tipoController = TextEditingController();

  int _precision = 3;

  Timer? _timer;
  static const Duration _refreshEvery = Duration(seconds: 20);

  static const LatLng _fallbackCenter = LatLng(19.70078, -101.18443);
  static const double _zoomDefault = 12.8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    _scrollController.dispose();
    _tipoController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(_refreshEvery, (_) => _fetchData());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _fetchData();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopTimer();
    }
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _fetchData();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _fetchData() async {
    try {
      final rows = await _MapaIncidenciasService.getClusters(
        desde: _desde,
        hasta: _hasta,
        tipoHecho: _tipoController.text.trim().isEmpty
            ? null
            : _tipoController.text.trim(),
        precision: _precision,
      );

      if (!mounted) return;

      setState(() {
        _clusters = rows;
        _error = null;
        _lastFetchAt = DateTime.now();
      });

      if (rows.isNotEmpty) {
        final c = rows.first;
        try {
          _mapController.move(LatLng(c.lat, c.lng), _zoomDefault);
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _onPullToRefresh() async => _fetchData();

  Future<void> _pickDate({required bool isDesde}) async {
    final now = DateTime.now();
    final initial = (isDesde ? _desde : _hasta) ?? now;
    final first = DateTime(2020, 1, 1);
    final last = DateTime(now.year + 1, 12, 31);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (isDesde) {
        _desde = DateTime(picked.year, picked.month, picked.day);
        if (_hasta != null && _hasta!.isBefore(_desde!)) {
          _hasta = _desde;
        }
      } else {
        _hasta = DateTime(picked.year, picked.month, picked.day);
        if (_desde != null && _desde!.isAfter(_hasta!)) {
          _desde = _hasta;
        }
      }
    });

    await _fetchData();
  }

  void _clearFilters() {
    setState(() {
      _desde = null;
      _hasta = null;
      _tipoController.clear();
      _precision = 3;
    });
    _fetchData();
  }

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _scrollToMap() async {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;

    await Future.delayed(const Duration(milliseconds: 10));
    if (!mounted) return;
    if (!_scrollController.hasClients) return;

    try {
      final mapCtx = _mapKey.currentContext;
      if (mapCtx == null) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
        return;
      }

      final mapBox = mapCtx.findRenderObject() as RenderBox?;
      final scrollCtx = _scrollController.position.context.storageContext;
      final scrollBox = scrollCtx.findRenderObject() as RenderBox?;
      if (mapBox == null || scrollBox == null) return;

      final mapOffsetGlobal = mapBox.localToGlobal(Offset.zero);
      final scrollOffsetGlobal = scrollBox.localToGlobal(Offset.zero);
      final delta = mapOffsetGlobal.dy - scrollOffsetGlobal.dy;
      final target = (_scrollController.offset + delta) - 8;

      final clamped = target.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );

      await _scrollController.animateTo(
        clamped.toDouble(),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {}
  }

  void _showClusterSheet(_IncCluster c) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.warning_amber,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Incidencias agrupadas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Total: ${c.total}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoRow(label: 'Lat', value: c.lat.toStringAsFixed(6)),
              _InfoRow(label: 'Lng', value: c.lng.toStringAsFixed(6)),
              _InfoRow(label: 'Desde', value: c.fechaMin ?? '—'),
              _InfoRow(label: 'Hasta', value: c.fechaMax ?? '—'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          _mapController.move(LatLng(c.lat, c.lng), 16.0);
                        } catch (_) {}
                        await _scrollToMap();
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text('Centrar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _fetchData();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refrescar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _markerWidget(int total) {
    final t = total.toString();
    final size = total >= 100 ? 48.0 : (total >= 20 ? 44.0 : 40.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(.20),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.orange.withOpacity(.65), width: 2),
      ),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.72),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          t,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _clusters.isNotEmpty
        ? LatLng(_clusters.first.lat, _clusters.first.lng)
        : _fallbackCenter;

    final markers = _clusters.map((c) {
      return Marker(
        width: 60,
        height: 60,
        point: LatLng(c.lat, c.lng),
        child: GestureDetector(
          onTap: () => _showClusterSheet(c),
          child: _markerWidget(c.total),
        ),
      );
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Mapa de Incidencias'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onPullToRefresh,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _TopStatusBar(
                loading: _loading,
                error: _error,
                lastFetchAt: _lastFetchAt,
                total: _clusters.length,
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtros',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _FilterTile(
                            title: 'Desde',
                            value: _fmt(_desde),
                            icon: Icons.date_range,
                            onTap: () => _pickDate(isDesde: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _FilterTile(
                            title: 'Hasta',
                            value: _fmt(_hasta),
                            icon: Icons.event,
                            onTap: () => _pickDate(isDesde: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _tipoController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'tipo_hecho (opcional)',
                        prefixIcon: const Icon(Icons.filter_alt),
                        suffixIcon: _tipoController.text.trim().isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _tipoController.clear();
                                  FocusScope.of(context).unfocus();
                                  _fetchData();
                                },
                                icon: const Icon(Icons.close),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _fetchData(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'Precisión',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            children: [2, 3, 4, 5].map((p) {
                              final selected = _precision == p;
                              return ChoiceChip(
                                label: Text('$p'),
                                selected: selected,
                                onSelected: (_) async {
                                  setState(() => _precision = p);
                                  await _fetchData();
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _fetchData,
                            icon: const Icon(Icons.search),
                            label: const Text('Aplicar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Limpiar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                key: _mapKey,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                height: 420,
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
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _zoomDefault,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'seguridad_vial_app',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
              if (_error != null && !_loading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _ErrorCard(message: _error!, onRetry: _fetchData),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Mostrando ${_clusters.length} puntos agrupados (máx 3000).',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapaIncidenciasService {
  static const String baseUrl = 'https://seguridadvial-mich.com/api';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<_IncCluster>> getClusters({
    DateTime? desde,
    DateTime? hasta,
    String? tipoHecho,
    required int precision,
  }) async {
    final qp = <String, String>{
      'precision': precision.toString(),
      if (desde != null)
        'desde':
            '${desde.year.toString().padLeft(4, '0')}-${desde.month.toString().padLeft(2, '0')}-${desde.day.toString().padLeft(2, '0')}',
      if (hasta != null)
        'hasta':
            '${hasta.year.toString().padLeft(4, '0')}-${hasta.month.toString().padLeft(2, '0')}-${hasta.day.toString().padLeft(2, '0')}',
      if (tipoHecho != null && tipoHecho.trim().isNotEmpty)
        'tipo_hecho': tipoHecho.trim(),
    };

    final uri = Uri.parse(
      '$baseUrl/mapa-incidencias/data',
    ).replace(queryParameters: qp);

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final list = (decoded is Map && decoded['data'] is List)
        ? (decoded['data'] as List)
        : (decoded is List ? decoded : <dynamic>[]);

    final out = <_IncCluster>[];
    for (final e in list) {
      if (e is Map<String, dynamic>) {
        out.add(_IncCluster.fromJson(e));
      } else if (e is Map) {
        out.add(_IncCluster.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }
}

class _IncCluster {
  final double lat;
  final double lng;
  final int total;
  final String? fechaMin;
  final String? fechaMax;

  _IncCluster({
    required this.lat,
    required this.lng,
    required this.total,
    required this.fechaMin,
    required this.fechaMax,
  });

  factory _IncCluster.fromJson(Map<String, dynamic> j) {
    double toD(dynamic v) =>
        (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0.0);
    int toI(dynamic v) => (v is int) ? v : (int.tryParse('$v') ?? 0);

    return _IncCluster(
      lat: toD(j['lat']),
      lng: toD(j['lng']),
      total: toI(j['total']),
      fechaMin: j['fecha_min']?.toString(),
      fechaMax: j['fecha_max']?.toString(),
    );
  }
}

class _TopStatusBar extends StatelessWidget {
  final bool loading;
  final String? error;
  final DateTime? lastFetchAt;
  final int total;

  const _TopStatusBar({
    required this.loading,
    required this.error,
    required this.lastFetchAt,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white;
    final border = Colors.grey.shade200;

    String subtitle;
    if (loading && lastFetchAt == null) {
      subtitle = 'Cargando...';
    } else if (error != null) {
      subtitle = 'Error: $error';
    } else if (lastFetchAt != null) {
      subtitle = 'Actualizado: ${_formatTime(lastFetchAt!)} · Puntos: $total';
    } else {
      subtitle = 'Puntos: $total';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.warning_amber, color: Colors.orange),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Incidencias (agrupadas)',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}

class _FilterTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _FilterTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.red.withOpacity(.06),
        border: Border.all(color: Colors.red.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No se pudo cargar',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      ),
    );
  }
}
