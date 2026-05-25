import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/routes.dart';
import '../models/delegaciones_home_models.dart';
import '../services/app_version_service.dart';
import '../services/auth_service.dart';
import '../services/delegaciones_home_service.dart';
import '../services/home_resolver_service.dart';
import '../services/push_service.dart';
import '../widgets/account_drawer.dart';
import '../widgets/app_drawer.dart';
import '../widgets/offline_sync_status_card.dart';
import '../widgets/safe_osm_tile_layer.dart';
import 'home/controllers/home_tracking_controller.dart';
import 'login_screen.dart';

class HomeDelegacionesScreen extends StatefulWidget {
  const HomeDelegacionesScreen({super.key});

  @override
  State<HomeDelegacionesScreen> createState() => _HomeDelegacionesScreenState();
}

class _HomeDelegacionesScreenState extends State<HomeDelegacionesScreen>
    with WidgetsBindingObserver {
  final HomeTrackingController _trackingCtrl = HomeTrackingController();
  final MapController _mapController = MapController();

  bool _busy = false;
  bool _bootstrapped = false;
  bool _loading = true;
  bool _fromCache = false;
  bool _signalsEnabled = true;
  DateTime? _lastUpdated;

  DelegacionesHomeMapData _mapData = DelegacionesHomeMapData.empty();

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

      final allowed =
          await HomeResolverService.isDelegacionesPoliciaHomeAvailable();
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

      try {
        await _trackingCtrl.syncFromCommanderFlag(context);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trackingCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        PushService.registerDeviceToken(reason: 'home_delegaciones_resumed');
      } catch (_) {}

      try {
        _trackingCtrl.syncFromCommanderFlag(context);
      } catch (_) {}
    }
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
        PushService.registerDeviceToken(reason: 'home_delegaciones_bootstrap');
      });
    } catch (_) {}
  }

  Future<void> _loadMap() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final cached = await DelegacionesHomeService.readCachedMapa();
    if (mounted && cached != null) {
      setState(() {
        _mapData = cached;
        _fromCache = true;
        _lastUpdated = DateTime.now();
      });
      _moveMap(cached);
    }

    try {
      final mapData = await DelegacionesHomeService.fetchMapa();
      if (!mounted) return;

      setState(() {
        _mapData = mapData;
        _fromCache = mapData.fallbackOnly;
        _lastUpdated = DateTime.now();
        _loading = false;
      });
      _moveMap(mapData);
    } catch (_) {
      if (!mounted) return;

      final fallback = cached ?? DelegacionesHomeMapData.empty();
      setState(() {
        _mapData = fallback;
        _fromCache = true;
        _lastUpdated = cached == null ? null : DateTime.now();
        _loading = false;
      });
      _moveMap(fallback);
    }
  }

  void _moveMap(DelegacionesHomeMapData mapData) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(
          LatLng(mapData.centerLat, mapData.centerLng),
          mapData.zoom.clamp(11.5, 14.0).toDouble(),
        );
      } catch (_) {}
    });
  }

  Future<void> _logout(BuildContext context) async {
    if (_busy) return;
    _busy = true;

    try {
      try {
        await _trackingCtrl.stop();
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

  List<DelegacionesRiskZone> get _visibleRiskZones {
    final zones =
        _mapData.riskZones.where((zone) => zone.hasValidLocation).toList()
          ..sort((a, b) => _zoneWeight(b).compareTo(_zoneWeight(a)));
    return zones.take(36).toList();
  }

  List<DelegacionesWazeAlert> get _visibleWazeAlerts {
    final alerts =
        _mapData.wazeAlerts.where((alert) => alert.hasValidLocation).toList()
          ..sort((a, b) {
            final ad = a.publishedDate;
            final bd = b.publishedDate;
            if (ad == null && bd == null) return 0;
            if (ad == null) return 1;
            if (bd == null) return -1;
            return bd.compareTo(ad);
          });
    return alerts.take(80).toList();
  }

  double _zoneWeight(DelegacionesRiskZone zone) {
    return zone.score + (zone.totalHechos * 2.0) + (zone.wazeTotal * 4.0);
  }

  double _riskRadius(DelegacionesRiskZone zone) {
    final byScore = 8 + (zone.score.clamp(0, 100) * .10);
    final byTotal = zone.totalHechos.clamp(0, 12) * .65;
    return (byScore + byTotal).clamp(8.0, 20.0).toDouble();
  }

  Color _colorFromHex(String raw, {double opacity = 1}) {
    var hex = raw.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final value = int.tryParse(hex, radix: 16) ?? 0xFFE11D48;
    return Color(value).withValues(alpha: opacity);
  }

  Future<void> _openGoogleMaps({
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$lat,$lng',
      'travelmode': 'driving',
    });

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir Google Maps.')),
    );
  }

  String _fmtDateTime(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'Sin hora';

    try {
      final dt = DateTime.parse(value).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return value;
    }
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return 'Sin cache';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }

  void _showRiskZoneSheet(DelegacionesRiskZone zone) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _MapPointSheet(
          title: zone.label,
          subtitle: '${zone.totalHechos} hechos registrados',
          icon: Icons.radar_rounded,
          accent: _colorFromHex(zone.strokeColor),
          rows: [
            _SheetRow(label: 'Riesgo', value: zone.score.toStringAsFixed(1)),
            _SheetRow(label: 'Waze cerca', value: '${zone.wazeTotal}'),
            _SheetRow(
              label: 'Ultimo evento',
              value: _fmtDateTime(zone.lastEventAt),
            ),
            _SheetRow(
              label: 'Coordenadas',
              value:
                  '${zone.centerLat.toStringAsFixed(6)}, ${zone.centerLng.toStringAsFixed(6)}',
            ),
          ],
          onOpenMaps: () =>
              _openGoogleMaps(lat: zone.centerLat, lng: zone.centerLng),
        );
      },
    );
  }

  void _showWazeSheet(DelegacionesWazeAlert alert) {
    final accent = alert.isClosure
        ? const Color(0xFFFF6F00)
        : (alert.isJam ? const Color(0xFF2563EB) : const Color(0xFFE11D48));

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _MapPointSheet(
          title: alert.title,
          subtitle: alert.subtitle,
          icon: alert.isClosure
              ? Icons.block_rounded
              : (alert.isJam
                    ? Icons.traffic_rounded
                    : Icons.warning_amber_rounded),
          accent: accent,
          rows: [
            _SheetRow(
              label: 'Tipo',
              value: alert.isClosure
                  ? 'Cierre'
                  : (alert.isJam ? 'Trafico' : 'Choque / alerta'),
            ),
            _SheetRow(label: 'Calle', value: alert.street ?? 'Sin calle'),
            _SheetRow(label: 'Ciudad', value: alert.city ?? 'Sin ciudad'),
            _SheetRow(
              label: 'Publicado',
              value: _fmtDateTime(alert.publishedAt),
            ),
            _SheetRow(
              label: 'Coordenadas',
              value:
                  '${alert.lat.toStringAsFixed(6)}, ${alert.lng.toStringAsFixed(6)}',
            ),
          ],
          onOpenMaps: () => _openGoogleMaps(lat: alert.lat, lng: alert.lng),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(_mapData.centerLat, _mapData.centerLng);
    final riskZones = _visibleRiskZones;
    final wazeAlerts = _visibleWazeAlerts;
    final showSignals = _signalsEnabled;

    return ValueListenableBuilder<bool>(
      valueListenable: _trackingCtrl.trackingOn,
      builder: (context, trackingOn, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFE8EDF3),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.blue,
            title: const Text('Home Delegaciones'),
            actions: const [AccountMenuAction()],
          ),
          drawer: AppDrawer(trackingOn: trackingOn),
          endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: _mapData.zoom.clamp(11.5, 14.0).toDouble(),
                      minZoom: 10,
                      maxZoom: 18,
                      backgroundColor: const Color(0xFFE8EDF3),
                      interactionOptions: const InteractionOptions(
                        flags:
                            InteractiveFlag.drag |
                            InteractiveFlag.pinchZoom |
                            InteractiveFlag.doubleTapZoom,
                      ),
                    ),
                    children: [
                      _OfflineMoreliaRoadLayer(),
                      buildSafeOpenStreetMapTileLayer(
                        userAgentPackageName: 'com.nasaka.seguridad_vial_app',
                        maxZoom: 19,
                      ),
                      if (showSignals && riskZones.isNotEmpty)
                        CircleLayer(
                          circles: riskZones.map((zone) {
                            final color = _colorFromHex(zone.strokeColor);
                            return CircleMarker(
                              point: LatLng(zone.centerLat, zone.centerLng),
                              radius: _riskRadius(zone),
                              useRadiusInMeter: false,
                              color: color.withValues(alpha: .22),
                              borderStrokeWidth: 1.4,
                              borderColor: color.withValues(alpha: .72),
                            );
                          }).toList(),
                        ),
                      if (showSignals && riskZones.isNotEmpty)
                        MarkerLayer(
                          markers: riskZones.map((zone) {
                            return Marker(
                              point: LatLng(zone.centerLat, zone.centerLng),
                              width: 48,
                              height: 48,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _showRiskZoneSheet(zone),
                                child: const SizedBox.expand(),
                              ),
                            );
                          }).toList(),
                        ),
                      if (showSignals && wazeAlerts.isNotEmpty)
                        MarkerLayer(
                          markers: wazeAlerts.map((alert) {
                            return Marker(
                              point: LatLng(alert.lat, alert.lng),
                              width: 32,
                              height: 32,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _showWazeSheet(alert),
                                child: _WazePin(alert: alert),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _MapStatusPanel(
                    loading: _loading,
                    fromCache: _fromCache,
                    mapData: _mapData,
                    visibleRiskZones: riskZones.length,
                    visibleWazeAlerts: wazeAlerts.length,
                    signalsEnabled: _signalsEnabled,
                    lastUpdated: _fmtTime(_lastUpdated),
                    onToggleSignals: () {
                      setState(() => _signalsEnabled = !_signalsEnabled);
                    },
                  ),
                ),
                const Positioned(
                  top: 84,
                  left: 12,
                  right: 12,
                  child: OfflineSyncStatusCard(),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 14,
                  child: _MapLegendPanel(mapData: _mapData),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OfflineMoreliaRoadLayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PolylineLayer(
          polylines: _majorRoads
              .map(
                (road) => Polyline(
                  points: road,
                  strokeWidth: 5,
                  color: const Color(0xFF94A3B8).withValues(alpha: .74),
                  borderStrokeWidth: 4,
                  borderColor: Colors.white.withValues(alpha: .62),
                ),
              )
              .toList(),
        ),
        const MarkerLayer(
          markers: [
            Marker(
              point: LatLng(19.7025, -101.1948),
              width: 118,
              height: 26,
              child: _RoadLabel(text: 'Centro'),
            ),
            Marker(
              point: LatLng(19.6904, -101.2006),
              width: 130,
              height: 26,
              child: _RoadLabel(text: 'Camelinas'),
            ),
            Marker(
              point: LatLng(19.7224, -101.1972),
              width: 138,
              height: 26,
              child: _RoadLabel(text: 'Periferico'),
            ),
          ],
        ),
      ],
    );
  }

  static const List<List<LatLng>> _majorRoads = [
    [
      LatLng(19.7015, -101.2390),
      LatLng(19.7016, -101.2210),
      LatLng(19.7020, -101.1995),
      LatLng(19.7030, -101.1770),
      LatLng(19.7040, -101.1515),
    ],
    [
      LatLng(19.6820, -101.2280),
      LatLng(19.6868, -101.2115),
      LatLng(19.6905, -101.1990),
      LatLng(19.6942, -101.1820),
      LatLng(19.6980, -101.1660),
    ],
    [
      LatLng(19.7350, -101.2220),
      LatLng(19.7255, -101.2070),
      LatLng(19.7200, -101.1910),
      LatLng(19.7160, -101.1715),
      LatLng(19.7100, -101.1510),
    ],
    [
      LatLng(19.7260, -101.2360),
      LatLng(19.7150, -101.2190),
      LatLng(19.7050, -101.2050),
      LatLng(19.6930, -101.1900),
      LatLng(19.6810, -101.1730),
    ],
    [
      LatLng(19.6720, -101.2210),
      LatLng(19.6860, -101.2150),
      LatLng(19.7030, -101.2090),
      LatLng(19.7210, -101.2020),
      LatLng(19.7370, -101.1960),
    ],
  ];
}

class _RoadLabel extends StatelessWidget {
  final String text;

  const _RoadLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .86),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _WazePin extends StatelessWidget {
  final DelegacionesWazeAlert alert;

  const _WazePin({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = alert.isClosure
        ? const Color(0xFFFF6F00)
        : (alert.isJam ? const Color(0xFF2563EB) : const Color(0xFFE11D48));
    final icon = alert.isClosure
        ? Icons.block_rounded
        : (alert.isJam ? Icons.traffic_rounded : Icons.warning_amber_rounded);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.4),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 3),
            color: Colors.black.withValues(alpha: .18),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _MapStatusPanel extends StatelessWidget {
  final bool loading;
  final bool fromCache;
  final DelegacionesHomeMapData mapData;
  final int visibleRiskZones;
  final int visibleWazeAlerts;
  final bool signalsEnabled;
  final String lastUpdated;
  final VoidCallback onToggleSignals;

  const _MapStatusPanel({
    required this.loading,
    required this.fromCache,
    required this.mapData,
    required this.visibleRiskZones,
    required this.visibleWazeAlerts,
    required this.signalsEnabled,
    required this.lastUpdated,
    required this.onToggleSignals,
  });

  @override
  Widget build(BuildContext context) {
    final totalSignals = mapData.riskZonesCount + mapData.wazeAlertsCount;
    final subtitle = !signalsEnabled
        ? 'Incidencias ocultas; mapa libre'
        : totalSignals == 0
        ? 'Calles visibles; sin senales recientes'
        : '$visibleRiskZones zonas suaves - $visibleWazeAlerts Waze - $lastUpdated';

    return _OverlayPanel(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.map_rounded, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fromCache ? 'Mapa con cache local' : 'Mapa de ciudad',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 38,
            height: 38,
            child: IconButton(
              tooltip: signalsEnabled
                  ? 'Ocultar incidencias'
                  : 'Mostrar incidencias',
              onPressed: onToggleSignals,
              style: IconButton.styleFrom(
                backgroundColor: signalsEnabled
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: Icon(
                signalsEnabled
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: const Color(0xFF2563EB),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetRow {
  final String label;
  final String value;

  const _SheetRow({required this.label, required this.value});
}

class _MapPointSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<_SheetRow> rows;
  final Future<void> Function() onOpenMaps;

  const _MapPointSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.rows,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(
                        row.label,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value.trim().isEmpty ? 'Sin dato' : row.value,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onOpenMaps();
                },
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('Ir en Google Maps'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLegendPanel extends StatelessWidget {
  final DelegacionesHomeMapData mapData;

  const _MapLegendPanel({required this.mapData});

  @override
  Widget build(BuildContext context) {
    final text = mapData.wazeAlertsCount == 0
        ? 'Waze mayor a 30 min no se pinta. Los tiles del mapa se reutilizan desde cache.'
        : '${mapData.choques} choques - ${mapData.cierres} cierres - ${mapData.trafico} trafico';

    return _OverlayPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LegendItem(color: Color(0xFFE11D48), label: 'Riesgo'),
              _LegendItem(color: Color(0xFFE11D48), label: 'Choque'),
              _LegendItem(color: Color(0xFFFF6F00), label: 'Cierre'),
              _LegendItem(color: Color(0xFF2563EB), label: 'Trafico'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayPanel extends StatelessWidget {
  final Widget child;

  const _OverlayPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: .14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
