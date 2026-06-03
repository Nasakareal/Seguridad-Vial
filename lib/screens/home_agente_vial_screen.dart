import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app/routes.dart';
import '../models/agente_vial_home_models.dart';
import '../services/agente_vial_home_service.dart';
import '../services/app_version_service.dart';
import '../services/auth_service.dart';
import '../services/home_resolver_service.dart';
import '../services/location_flag_service.dart';
import '../services/push_service.dart';
import '../services/tracking_service.dart';
import '../widgets/account_drawer.dart';
import '../widgets/app_drawer.dart';
import '../widgets/offline_sync_status_card.dart';
import '../widgets/safe_osm_tile_layer.dart';
import 'login_screen.dart';

class HomeAgenteVialScreen extends StatefulWidget {
  const HomeAgenteVialScreen({super.key});

  @override
  State<HomeAgenteVialScreen> createState() => _HomeAgenteVialScreenState();
}

class _HomeAgenteVialScreenState extends State<HomeAgenteVialScreen>
    with WidgetsBindingObserver {
  bool _trackingOn = false;
  bool _busy = false;
  bool _bootstrapped = false;
  bool _loading = true;
  String? _error;

  int _selectedHour = DateTime.now().hour;
  int _wazeHours = AgenteVialHomeService.defaultWazeHours;
  int _historyDays = AgenteVialHomeService.defaultHistoryDays;
  String _tipo = 'TODOS';

  final MapController _mapController = MapController();
  AgenteVialHomeMapData? _mapData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await AppVersionService.enforceUpdateIfNeeded(context);
      } catch (_) {}

      if (!mounted) return;
      await _bootstrapOnce();
      if (!mounted) return;

      final allowed = await HomeResolverService.isAgenteVialHomeAvailable();
      if (!mounted) return;
      if (!allowed) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (_) => false,
        );
        return;
      }

      await _refreshAll();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bootstrapOnce() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    try {
      await PushService.ensurePermissions();
    } catch (_) {}

    try {
      PushService.listenTokenRefresh();
    } catch (_) {}

    try {
      Future.delayed(const Duration(seconds: 1), () {
        PushService.registerDeviceToken(reason: 'home_agente_vial_bootstrap');
      });
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    await _loadMap();
    if (!mounted) return;
    await _syncTrackingFromCommanderFlag();
  }

  Future<void> _loadMap() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final mapData = await AgenteVialHomeService.fetchMapa(
        hour: _selectedHour,
        wazeHours: _wazeHours,
        historyDays: _historyDays,
        tipo: _tipo,
      );

      if (!mounted) return;
      setState(() {
        _mapData = mapData;
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(
          LatLng(mapData.centerLat, mapData.centerLng),
          mapData.zoom,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el home de Agente Vial: $e';
        _loading = false;
      });
    }
  }

  Future<void> _syncTrackingFromCommanderFlag() async {
    try {
      final enabledByCommander = await LocationFlagService.isEnabledForMe();
      if (!mounted) return;

      var running = await TrackingService.isRunning();
      if (!mounted) return;

      if (!running) {
        bool started = false;
        try {
          started = await TrackingService.startWithDisclosure(context);
        } catch (_) {
          started = false;
        }
        if (!mounted) return;
        running = started;
      }

      if (!mounted) return;
      setState(() => _trackingOn = enabledByCommander && running);
    } catch (_) {
      if (!mounted) return;
      setState(() => _trackingOn = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAll();

      try {
        Future.delayed(const Duration(milliseconds: 300), () {
          PushService.registerDeviceToken(reason: 'home_agente_vial_resumed');
        });
      } catch (_) {}
    }
  }

  Future<void> _logout(BuildContext context) async {
    if (_busy) return;
    _busy = true;

    try {
      try {
        await TrackingService.stop();
      } catch (_) {}
      await AuthService.logout();
    } finally {
      _busy = false;
    }

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String _fmtDateTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '—';

    try {
      final dt = DateTime.parse(value).toLocal();
      String two(int x) => x.toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return value;
    }
  }

  Color _colorFromHex(String raw, {double opacity = 1}) {
    var hex = raw.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final value = int.tryParse(hex, radix: 16) ?? 0xFF2563EB;
    return Color(value).withValues(alpha: opacity);
  }

  void _showAlertSheet(AgenteVialAlert alert) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniTag(text: alert.isCierre ? 'Cierre' : 'Choque'),
                    _MiniTag(text: _fmtDateTime(alert.publishedAt)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(alert.subtitle),
                if ((alert.city ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Ciudad: ${alert.city}'),
                ],
                const SizedBox(height: 8),
                Text(
                  'Coordenadas: ${alert.lat.toStringAsFixed(6)}, ${alert.lng.toStringAsFixed(6)}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRiskSheet(AgenteVialRiskCell cell) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cell.nivelLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniTag(text: '${cell.crashProbabilityPct}% choque'),
                    _MiniTag(text: 'Score ${cell.score.toStringAsFixed(1)}'),
                    _MiniTag(text: '${cell.historicTotal} hist. hora'),
                    if (cell.recentWazeTotal > 0)
                      _MiniTag(text: '${cell.recentWazeTotal} Waze'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  cell.accion,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if ((cell.lastEventAt ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Última señal: ${_fmtDateTime(cell.lastEventAt)}'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChaosSheet(AgenteVialChaosCell cell) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cell.nivelLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniTag(text: '${cell.total} alertas'),
                    _MiniTag(text: '${cell.choques} choques'),
                    _MiniTag(text: '${cell.cierres} cierres'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  cell.accion,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if ((cell.lastWazeAt ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Última alerta: ${_fmtDateTime(cell.lastWazeAt)}'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(AgenteVialHomeMapData? mapData) {
    final label = mapData?.targetHourLabel ?? '$_selectedHourLabel:00';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withValues(alpha: .12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.traffic_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Home Agente Vial',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Morelia · hora objetivo $label · mapa operativo',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _selectedHourLabel => _selectedHour.toString().padLeft(2, '0');

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedHour,
                  decoration: const InputDecoration(
                    labelText: 'Hora',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (var hour = 0; hour < 24; hour++)
                      DropdownMenuItem<int>(
                        value: hour,
                        child: Text('${hour.toString().padLeft(2, '0')}:00'),
                      ),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _selectedHour = value);
                          _loadMap();
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _wazeHours,
                  decoration: const InputDecoration(
                    labelText: 'Waze',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 h')),
                    DropdownMenuItem(value: 3, child: Text('3 h')),
                    DropdownMenuItem(value: 6, child: Text('6 h')),
                    DropdownMenuItem(value: 12, child: Text('12 h')),
                    DropdownMenuItem(value: 24, child: Text('24 h')),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _wazeHours = value);
                          _loadMap();
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'Todos',
                selected: _tipo == 'TODOS',
                onTap: () => _setTipo('TODOS'),
              ),
              _FilterChip(
                label: 'Choques',
                selected: _tipo == 'CHOQUES',
                onTap: () => _setTipo('CHOQUES'),
              ),
              _FilterChip(
                label: 'Cierres',
                selected: _tipo == 'CIERRES',
                onTap: () => _setTipo('CIERRES'),
              ),
              _FilterChip(
                label: '90 días',
                selected: _historyDays == 90,
                onTap: () => _setHistoryDays(90),
              ),
              _FilterChip(
                label: '180 días',
                selected: _historyDays == 180,
                onTap: () => _setHistoryDays(180),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setTipo(String value) {
    if (_loading || _tipo == value) return;
    setState(() => _tipo = value);
    _loadMap();
  }

  void _setHistoryDays(int value) {
    if (_loading || _historyDays == value) return;
    setState(() => _historyDays = value);
    _loadMap();
  }

  Widget _buildMap(AgenteVialHomeMapData mapData, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(mapData.centerLat, mapData.centerLng),
            initialZoom: mapData.zoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            buildSafeOpenStreetMapTileLayer(
              userAgentPackageName: 'com.nasaka.seguridad_vial_app',
              maxZoom: 19,
            ),
            CircleLayer(
              circles: [
                ...mapData.riskCells.map((cell) {
                  final color = _colorFromHex(cell.color);
                  return CircleMarker(
                    point: LatLng(cell.lat, cell.lng),
                    radius: cell.radiusMeters,
                    useRadiusInMeter: true,
                    color: color.withValues(alpha: .20),
                    borderStrokeWidth: 2,
                    borderColor: color.withValues(alpha: .72),
                  );
                }),
                ...mapData.chaosCells.map((cell) {
                  final color = _colorFromHex(cell.color);
                  return CircleMarker(
                    point: LatLng(cell.lat, cell.lng),
                    radius: cell.radiusMeters,
                    useRadiusInMeter: true,
                    color: color.withValues(alpha: .30),
                    borderStrokeWidth: 2,
                    borderColor: color.withValues(alpha: .92),
                  );
                }),
              ],
            ),
            MarkerLayer(
              markers: [
                ...mapData.riskCells
                    .take(12)
                    .map(
                      (cell) => Marker(
                        point: LatLng(cell.lat, cell.lng),
                        width: 110,
                        height: 38,
                        child: GestureDetector(
                          onTap: () => _showRiskSheet(cell),
                          child: _MapBadge(
                            label: '${cell.crashProbabilityPct}% choque',
                            background: _colorFromHex(cell.color),
                          ),
                        ),
                      ),
                    ),
                ...mapData.chaosCells
                    .take(10)
                    .map(
                      (cell) => Marker(
                        point: LatLng(cell.lat, cell.lng),
                        width: 108,
                        height: 34,
                        child: GestureDetector(
                          onTap: () => _showChaosSheet(cell),
                          child: _MapBadge(
                            label: 'Caos ${cell.total}',
                            background: _colorFromHex(cell.color),
                          ),
                        ),
                      ),
                    ),
                ...mapData.alerts.map((alert) {
                  final markerColor = alert.isCierre
                      ? const Color(0xFFFF6F00)
                      : const Color(0xFFFFD600);
                  final borderColor = alert.isCierre
                      ? const Color(0xFFBF360C)
                      : const Color(0xFFD50000);

                  return Marker(
                    point: LatLng(alert.lat, alert.lng),
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _showAlertSheet(alert),
                      child: Container(
                        decoration: BoxDecoration(
                          color: markerColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 3),
                        ),
                        child: Icon(
                          alert.isCierre
                              ? Icons.block_rounded
                              : Icons.warning_amber_rounded,
                          color: borderColor,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(AgenteVialHomeMapData mapData) {
    return Row(
      children: [
        Expanded(
          child: _MetricPill(
            label: 'Waze Morelia',
            value: '${mapData.wazeAlertsCount}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricPill(label: 'Choques', value: '${mapData.choques}'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricPill(
            label: 'Riesgo max.',
            value: '${(mapData.topCrashProbability * 100).round()}%',
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyStrip(AgenteVialHomeMapData mapData) {
    final maxTotal = mapData.hourly.fold<int>(
      1,
      (max, item) => item.total > max ? item.total : max,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Histórico por hora en Morelia',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: mapData.hourly.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = mapData.hourly[index];
                final selected = item.hour == _selectedHour;
                final ratio = item.total / maxTotal;
                return GestureDetector(
                  onTap: _loading
                      ? null
                      : () {
                          setState(() => _selectedHour = item.hour);
                          _loadMap();
                        },
                  child: SizedBox(
                    width: 42,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 18,
                              height: 12 + (52 * ratio),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.hour.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: selected
                                ? const Color(0xFF2563EB)
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityList(AgenteVialHomeMapData mapData) {
    final cells = mapData.riskCells.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Zonas prioritarias',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        if (cells.isEmpty)
          const _EmptyCard(
            text: 'Sin zonas de riesgo para esta hora. Prueba otra hora.',
          )
        else
          ...cells.map(
            (cell) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RiskPriorityCard(
                cell: cell,
                color: _colorFromHex(cell.color),
                lastLabel: _fmtDateTime(cell.lastEventAt),
                onTap: () => _showRiskSheet(cell),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAlertList(AgenteVialHomeMapData mapData) {
    final alerts = mapData.alerts.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alertas Waze activas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        if (alerts.isEmpty)
          const _EmptyCard(
            text: 'No hay choques o cierres recientes en Morelia.',
          )
        else
          ...alerts.map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AlertCard(
                alert: alert,
                publishedLabel: _fmtDateTime(alert.publishedAt),
                onTap: () => _showAlertSheet(alert),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapData = _mapData;
    final mapHeight = (MediaQuery.sizeOf(context).height * 0.50)
        .clamp(420.0, 590.0)
        .toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Home Agente Vial'),
        actions: [
          IconButton(
            tooltip: 'Centrar Morelia',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: mapData == null
                ? null
                : () => _mapController.move(
                    LatLng(mapData.centerLat, mapData.centerLng),
                    mapData.zoom,
                  ),
          ),
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
          ),
          const AccountMenuAction(),
        ],
      ),
      drawer: AppDrawer(trackingOn: _trackingOn),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildHeader(mapData),
              const SizedBox(height: 12),
              const OfflineSyncStatusCard(),
              const SizedBox(height: 12),
              _buildFilters(),
              const SizedBox(height: 12),
              if (_loading)
                SizedBox(
                  height: mapHeight,
                  child: const Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorCard(message: _error!, onRetry: _loadMap)
              else if (mapData != null) ...[
                _buildMetrics(mapData),
                const SizedBox(height: 12),
                _buildMap(mapData, mapHeight),
                const SizedBox(height: 14),
                _buildHourlyStrip(mapData),
                const SizedBox(height: 16),
                _buildPriorityList(mapData),
                const SizedBox(height: 8),
                _buildAlertList(mapData),
              ] else
                _ErrorCard(
                  message: 'No hubo respuesta útil para dibujar el mapa.',
                  onRetry: _loadMap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF2563EB).withValues(alpha: .16),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
        fontWeight: FontWeight.w900,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? const Color(0xFF2563EB) : Colors.grey.shade300,
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapBadge extends StatelessWidget {
  final String label;
  final Color background;

  const _MapBadge({required this.label, required this.background});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _RiskPriorityCard extends StatelessWidget {
  final AgenteVialRiskCell cell;
  final Color color;
  final String lastLabel;
  final VoidCallback onTap;

  const _RiskPriorityCard({
    required this.cell,
    required this.color,
    required this.lastLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.route_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cell.crashProbabilityPct}% probabilidad de choque',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cell.accion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniTag(text: cell.nivelLabel),
                        _MiniTag(text: '${cell.historicTotal} hist.'),
                        if (cell.recentWazeTotal > 0)
                          _MiniTag(text: '${cell.recentWazeTotal} Waze'),
                        _MiniTag(text: lastLabel),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AgenteVialAlert alert;
  final String publishedLabel;
  final VoidCallback onTap;

  const _AlertCard({
    required this.alert,
    required this.publishedLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = alert.isCierre
        ? const Color(0xFFFF6F00)
        : const Color(0xFFD50000);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  alert.isCierre
                      ? Icons.block_rounded
                      : Icons.warning_amber_rounded,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniTag(text: alert.isCierre ? 'Cierre' : 'Choque'),
                        _MiniTag(text: publishedLabel),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;

  const _MiniTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
