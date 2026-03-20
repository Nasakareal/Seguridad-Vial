import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../app/routes.dart';
import '../models/perito_home_models.dart';
import '../services/app_version_service.dart';
import '../services/auth_service.dart';
import '../services/location_flag_service.dart';
import '../services/perito_home_service.dart';
import '../services/push_service.dart';
import '../services/tracking_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/header_card.dart';
import '../widgets/offline_sync_status_card.dart';
import '../widgets/safe_osm_tile_layer.dart';
import 'login_screen.dart';

class HomePeritoScreen extends StatefulWidget {
  const HomePeritoScreen({super.key});

  @override
  State<HomePeritoScreen> createState() => _HomePeritoScreenState();
}

class _HomePeritoScreenState extends State<HomePeritoScreen>
    with WidgetsBindingObserver {
  bool _trackingOn = false;
  bool _busy = false;
  bool _bootstrapped = false;
  bool _loading = true;
  String? _error;

  PeritoHomeMapData? _mapData;
  final MapController _mapController = MapController();

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

      final allowed = await AuthService.isPerito();
      if (!mounted) return;
      if (!allowed) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (_) => false,
        );
        return;
      }

      await _loadMap();
      if (!mounted) return;
      await _syncTrackingFromCommanderFlag();
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
        PushService.registerDeviceToken(reason: 'home_perito_bootstrap');
      });
    } catch (_) {}
  }

  Future<void> _loadMap() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final mapData = await PeritoHomeService.fetchMapa();

      if (!mounted) return;
      setState(() {
        _mapData = mapData;
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final center = await _resolvePreferredCenter(mapData);
        if (!mounted) return;
        _mapController.move(center, mapData.zoom);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el mapa del perito: $e';
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

  Future<void> _refreshAll() async {
    await _loadMap();

    if (!mounted) return;

    try {
      await _syncTrackingFromCommanderFlag();
    } catch (_) {}

    try {
      Future.delayed(const Duration(milliseconds: 250), () {
        PushService.registerDeviceToken(reason: 'home_perito_refresh');
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await _syncTrackingFromCommanderFlag();
      if (!mounted) return;

      try {
        Future.delayed(const Duration(milliseconds: 300), () {
          PushService.registerDeviceToken(reason: 'home_perito_resumed');
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
      try {
        await AuthService.logout();
      } catch (_) {}
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

  Future<LatLng> _resolvePreferredCenter(PeritoHomeMapData mapData) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return LatLng(mapData.centerLat, mapData.centerLng);
      }

      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (current.latitude != 0 && current.longitude != 0) {
        return LatLng(current.latitude, current.longitude);
      }
    } catch (_) {}

    return LatLng(mapData.centerLat, mapData.centerLng);
  }

  String _fmtDateTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '—';

    try {
      final dt = DateTime.parse(value).toLocal();
      String two(int x) => x.toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return value;
    }
  }

  Color _colorFromHex(String raw, {double opacity = 1}) {
    var hex = raw.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final value = int.tryParse(hex, radix: 16) ?? 0xFFC62828;
    return Color(value).withValues(alpha: opacity);
  }

  void _showZoneSheet(PeritoRiskZone zone) {
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
                  zone.label,
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
                    _InfoChip(label: 'Score ${zone.score}'),
                    _InfoChip(label: '${zone.totalHechos} hechos'),
                    _InfoChip(label: zone.severity.toUpperCase()),
                  ],
                ),
                if ((zone.topTipoHecho ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Tipo dominante: ${zone.topTipoHecho}'),
                ],
                if ((zone.lastEventAt ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Último evento: ${_fmtDateTime(zone.lastEventAt)}'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWazeSheet(PeritoWazeAlert alert) {
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
                const SizedBox(height: 10),
                Text(alert.subtitle),
                if ((alert.city ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Ciudad: ${alert.city}'),
                ],
                if ((alert.publishedAt ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Publicado: ${_fmtDateTime(alert.publishedAt)}'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapData = _mapData;
    final mapHeight =
        MediaQuery.of(context).size.height -
        kToolbarHeight -
        MediaQuery.of(context).padding.top -
        170;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Home Perito'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
          ),
        ],
      ),
      drawer: AppDrawer(
        trackingOn: _trackingOn,
        onLogout: () => _logout(context),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              HeaderCard(trackingOn: _trackingOn),
              const SizedBox(height: 12),
              const OfflineSyncStatusCard(),
              const SizedBox(height: 12),
              if (_loading)
                SizedBox(
                  height: mapHeight,
                  child: const Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorCard(message: _error!, onRetry: _loadMap)
              else if (mapData != null)
                Container(
                  height: mapHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(
                          mapData.centerLat,
                          mapData.centerLng,
                        ),
                        initialZoom: mapData.zoom,
                      ),
                      children: [
                        buildSafeOpenStreetMapTileLayer(
                          userAgentPackageName: 'com.nasaka.seguridad_vial_app',
                          maxZoom: 19,
                        ),
                        CircleLayer(
                          circles: mapData.riskZones
                              .where((zone) => zone.severity == 'muy_alta')
                              .map(
                                (zone) => CircleMarker(
                                  point: LatLng(zone.centerLat, zone.centerLng),
                                  radius: zone.radiusMeters,
                                  useRadiusInMeter: true,
                                  borderStrokeWidth: 2,
                                  borderColor: _colorFromHex(zone.strokeColor),
                                  color: _colorFromHex(
                                    zone.fillColor,
                                    opacity: 0.28,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        MarkerLayer(
                          markers: [
                            ...mapData.riskZones
                                .where((zone) => zone.severity == 'muy_alta')
                                .map(
                                  (zone) => Marker(
                                    point: LatLng(
                                      zone.centerLat,
                                      zone.centerLng,
                                    ),
                                    width: 110,
                                    height: 34,
                                    child: GestureDetector(
                                      onTap: () => _showZoneSheet(zone),
                                      child: _MapBadge(
                                        label: 'Muy alta',
                                        background: _colorFromHex(
                                          zone.strokeColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ...mapData.wazeAlerts.map(
                              (alert) => Marker(
                                point: LatLng(alert.lat, alert.lng),
                                width: 44,
                                height: 44,
                                child: GestureDetector(
                                  onTap: () => _showWazeSheet(alert),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD600),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFD50000),
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Color(0xFFD50000),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else
                _ErrorCard(
                  message: 'No hubo respuesta util para dibujar el mapa.',
                  onRetry: _loadMap,
                ),
            ],
          ),
        ),
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
          color: background.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
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

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
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
