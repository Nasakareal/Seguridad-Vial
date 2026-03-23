import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../app/routes.dart';
import '../models/agente_upec_home_models.dart';
import '../services/agente_upec_home_service.dart';
import '../services/app_version_service.dart';
import '../services/auth_service.dart';
import '../services/home_resolver_service.dart';
import '../services/location_flag_service.dart';
import '../services/push_service.dart';
import '../services/tracking_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/offline_sync_status_card.dart';
import '../widgets/safe_osm_tile_layer.dart';
import 'login_screen.dart';

class HomeAgenteUpecScreen extends StatefulWidget {
  const HomeAgenteUpecScreen({super.key});

  @override
  State<HomeAgenteUpecScreen> createState() => _HomeAgenteUpecScreenState();
}

class _HomeAgenteUpecScreenState extends State<HomeAgenteUpecScreen>
    with WidgetsBindingObserver {
  bool _trackingOn = false;
  bool _busy = false;
  bool _bootstrapped = false;
  bool _loading = true;
  String? _error;
  String? _locationStatus;

  final MapController _mapController = MapController();

  AgenteUpecHomeMapData? _mapData;
  Position? _currentPosition;

  static const String _tipo = 'TODOS';
  final int _radiusKm = AgenteUpecHomeService.defaultRadiusKm;

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

      final allowed = await HomeResolverService.isAgenteUpecHomeAvailable();
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
        PushService.registerDeviceToken(reason: 'home_agente_upec_bootstrap');
      });
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    final position = await _resolveCurrentPosition();
    await _loadMap(position: position);
    if (!mounted) return;
    await _syncTrackingFromCommanderFlag();
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

  Future<void> _loadMap({Position? position}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final mapData = await AgenteUpecHomeService.fetchMapa(
        lat: position?.latitude,
        lng: position?.longitude,
        radiusKm: _radiusKm,
        tipo: _tipo,
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
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
        _error = 'No se pudo cargar el home UPEC: $e';
        _loading = false;
      });
    }
  }

  Future<Position?> _resolveCurrentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          setState(() {
            _locationStatus =
                'GPS apagado. Mostrando incidencias sin centrar en tu ubicación.';
          });
        }
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationStatus =
                'Sin permiso de ubicación. Se muestran incidencias generales.';
          });
        }
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _locationStatus =
              'Mostrando incidencias cerca de tu posición actual.';
        });
      }

      return position;
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationStatus =
              'No se pudo leer tu ubicación. Se muestran incidencias disponibles.';
        });
      }
      return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAll();

      try {
        Future.delayed(const Duration(milliseconds: 300), () {
          PushService.registerDeviceToken(reason: 'home_agente_upec_resumed');
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

  String _fmtDistance(double? meters) {
    if (meters == null) return 'Sin distancia';
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  void _showAlertSheet(AgenteUpecAlert alert) {
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
                    _MetricPill(
                      label: alert.isCierre ? 'Cierre' : 'Choque',
                      value: _fmtDistance(alert.distanceMeters),
                    ),
                    _MetricPill(
                      label: 'Publicado',
                      value: _fmtDateTime(alert.publishedAt),
                    ),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Home Agente UPEC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Incidencias cercanas primero',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _locationStatus ??
                'Buscando ubicación para traer solo lo más cercano.',
            style: const TextStyle(
              color: Colors.white,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapData = _mapData;
    final alerts = mapData?.alerts ?? const <AgenteUpecAlert>[];
    final mapHeight = (MediaQuery.sizeOf(context).height * 0.48)
        .clamp(420.0, 560.0)
        .toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Home UPEC'),
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
              _buildHeader(),
              const SizedBox(height: 12),
              const OfflineSyncStatusCard(),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorCard(message: _error!, onRetry: _refreshAll)
              else if (mapData != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _MetricPill(
                        label: 'Cerca de ti',
                        value: '${alerts.length} alertas',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricPill(
                        label: 'Choques',
                        value: '${mapData.choques}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricPill(
                        label: 'Cierres',
                        value: '${mapData.cierres}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                        if (_currentPosition != null)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: LatLng(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                ),
                                radius: _radiusKm * 1000,
                                useRadiusInMeter: true,
                                borderColor: const Color(0xFF2563EB),
                                borderStrokeWidth: 2,
                                color: const Color(
                                  0xFF2563EB,
                                ).withValues(alpha: .10),
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            if (_currentPosition != null)
                              Marker(
                                point: LatLng(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                ),
                                width: 42,
                                height: 42,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person_pin_circle,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ...alerts.map((alert) {
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
                                      border: Border.all(
                                        color: borderColor,
                                        width: 3,
                                      ),
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
                ),
                const SizedBox(height: 14),
                const Text(
                  'Incidencias más cercanas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                if (alerts.isEmpty)
                  const _EmptyNearbyCard()
                else
                  ...alerts.take(8).map((alert) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NearbyAlertCard(
                        alert: alert,
                        distanceLabel: _fmtDistance(alert.distanceMeters),
                        publishedLabel: _fmtDateTime(alert.publishedAt),
                        onTap: () => _showAlertSheet(alert),
                      ),
                    );
                  }),
              ] else
                _ErrorCard(
                  message: 'No hubo respuesta útil para dibujar el mapa.',
                  onRetry: _refreshAll,
                ),
            ],
          ),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyAlertCard extends StatelessWidget {
  final AgenteUpecAlert alert;
  final String distanceLabel;
  final String publishedLabel;
  final VoidCallback onTap;

  const _NearbyAlertCard({
    required this.alert,
    required this.distanceLabel,
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
                        _MiniTag(text: distanceLabel),
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

class _EmptyNearbyCard extends StatelessWidget {
  const _EmptyNearbyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Text(
        'No hay incidencias cercanas dentro del radio actual.',
        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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
