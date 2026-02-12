import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../services/auth_service.dart';

class MapaPatrullasScreen extends StatefulWidget {
  const MapaPatrullasScreen({super.key});

  @override
  State<MapaPatrullasScreen> createState() => _MapaPatrullasScreenState();
}

class _MapaPatrullasScreenState extends State<MapaPatrullasScreen>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _mapKey = GlobalKey();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _loading = true;
  bool _saving = false;
  String? _error;

  DateTime? _lastFetchAt;

  List<_PatrullaLoc> _patrullas = const [];
  List<_PersonalItem> _personal = const [];

  Timer? _timer;

  static const Duration _refreshEvery = Duration(seconds: 10);
  static const LatLng _fallbackCenter = LatLng(19.70078, -101.18443);
  static const double _zoomDefault = 13.5;
  static const double _zoomFocus = 16.5;

  bool _isSuperadmin = false;
  bool _roleLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _bootstrap();

    _startTimer();

    _searchController.addListener(() {
      final v = _searchController.text.trim().toLowerCase();
      if (v == _searchQuery) return;
      if (!mounted) return;
      setState(() => _searchQuery = v);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(_refreshEvery, (_) {
      _fetchMapOnly();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _fetchMapOnly();
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
      if (!_roleLoaded) {
        _isSuperadmin = await _tryIsSuperadmin();
        _roleLoaded = true;
      }

      final mapData = await _MapaService.getPatrullas();
      final personalData = await _MapaService.getMiPersonal();

      if (!mounted) return;

      setState(() {
        _patrullas = mapData;
        _personal = _mergePersonalWithMap(personalData, mapData);
        _loading = false;
        _error = null;
        _lastFetchAt = DateTime.now();
      });

      if (mapData.isNotEmpty) {
        final first = mapData.first;
        try {
          _mapController.move(LatLng(first.lat, first.lng), _zoomDefault);
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchMapOnly() async {
    try {
      final mapData = await _MapaService.getPatrullas();
      if (!mounted) return;

      setState(() {
        _patrullas = mapData;
        _personal = _mergePersonalWithMap(_personal, mapData);
        _error = null;
        _lastFetchAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _refreshAll() async => _bootstrap();
  Future<void> _onPullToRefresh() async => _refreshAll();

  List<_PersonalItem> _mergePersonalWithMap(
    List<_PersonalItem> personal,
    List<_PatrullaLoc> map,
  ) {
    final mapByUser = <int, _PatrullaLoc>{};
    for (final p in map) {
      mapByUser[p.userId] = p;
    }

    return personal.map((u) {
      final loc = mapByUser[u.userId];
      return u.copyWith(
        lastCapturedAtStr: loc?.capturedAtStr,
        lastLat: loc?.lat,
        lastLng: loc?.lng,
        isStale: loc?.isStale ?? true,
        patrullaNumero: loc?.patrullaNumero,
      );
    }).toList();
  }

  Future<bool> _tryIsSuperadmin() async {
    try {
      final role = await AuthService.getRole();
      return role != null && role.trim().toLowerCase() == 'superadmin';
    } catch (_) {
      return false;
    }
  }

  Future<void> _setUbicacionUsuario({
    required int userId,
    required bool enabled,
  }) async {
    if (_saving) return;

    if (mounted) setState(() => _saving = true);

    final idx = _personal.indexWhere((x) => x.userId == userId);
    final prev = idx >= 0 ? _personal[idx] : null;

    if (idx >= 0 && mounted) {
      final updated = List<_PersonalItem>.from(_personal);
      updated[idx] = updated[idx].copyWith(compartirUbicacion: enabled);
      setState(() => _personal = updated);
    }

    try {
      await _MapaService.toggleUbicacionUsuario(
        userId: userId,
        enabled: enabled,
      );

      await _fetchMapOnly();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'Ubicación activada' : 'Ubicación desactivada',
          ),
        ),
      );
    } catch (e) {
      if (idx >= 0 && prev != null && mounted) {
        final rollback = List<_PersonalItem>.from(_personal);
        rollback[idx] = prev;
        setState(() => _personal = rollback);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setUbicacionTodos({required bool enabled}) async {
    if (_saving) return;

    if (mounted) setState(() => _saving = true);

    final prev = _personal;

    if (mounted) {
      setState(() {
        _personal = _personal
            .map((e) => e.copyWith(compartirUbicacion: enabled))
            .toList();
      });
    }

    try {
      await _MapaService.toggleUbicacionTodos(enabled: enabled);
      await _fetchMapOnly();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Ubicación activada para tu personal'
                : 'Ubicación desactivada para tu personal',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _personal = prev);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo aplicar a todos: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  Future<void> _centerAndGoTopByCoords(double lat, double lng) async {
    try {
      _mapController.move(LatLng(lat, lng), _zoomFocus);
    } catch (_) {}
    await _scrollToMap();
  }

  Future<void> _centerAndGoTop(_PersonalItem p) async {
    if (p.lastLat == null || p.lastLng == null) return;
    await _centerAndGoTopByCoords(p.lastLat!, p.lastLng!);
  }

  Widget _markerWidget({
    required String label,
    required bool isStale,
    required Color accent,
  }) {
    return SizedBox(
      width: 62,
      height: 62,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label.isEmpty ? '-' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(.12),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withOpacity(.55), width: 2),
            ),
            alignment: Alignment.center,
            child: Opacity(
              opacity: isStale ? 0.55 : 1.0,
              child: Image.asset(
                'assets/images/car.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Mapa de Patrullas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _saving ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _TopStatusBar(
              loading: _loading,
              saving: _saving,
              error: _error,
              lastFetchAt: _lastFetchAt,
              total: _personal.length,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onPullToRefresh,
                child: _buildBody(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading && _personal.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.6));
    }

    if (_error != null && _personal.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [_ErrorCard(message: _error!, onRetry: _refreshAll)],
      );
    }

    final center = _patrullas.isNotEmpty
        ? LatLng(_patrullas.first.lat, _patrullas.first.lng)
        : _fallbackCenter;

    final markers = <Marker>[];

    if (_isSuperadmin) {
      for (final loc in _patrullas) {
        if (loc.lat == 0.0 && loc.lng == 0.0) continue;

        final isStale = loc.isStale;
        final color = isStale ? Colors.grey : Colors.blue;

        markers.add(
          Marker(
            width: 62,
            height: 62,
            point: LatLng(loc.lat, loc.lng),
            child: GestureDetector(
              onTap: () async {
                final match = _personal
                    .where((x) => x.userId == loc.userId)
                    .toList();
                if (match.isNotEmpty) {
                  _showPatrullaSheet(match.first);
                } else {
                  _showQuickLocSheet(loc);
                }
              },
              child: _markerWidget(
                label: (loc.patrullaNumero ?? '').toString(),
                isStale: isStale,
                accent: color,
              ),
            ),
          ),
        );
      }
    } else {
      final mapVisible = _personal.where((p) {
        if (!p.compartirUbicacion) return false;
        if (p.lastLat == null || p.lastLng == null) return false;
        return p.isStale == false;
      }).toList();

      for (final p in mapVisible) {
        const color = Colors.blue;

        markers.add(
          Marker(
            width: 62,
            height: 62,
            point: LatLng(p.lastLat!, p.lastLng!),
            child: GestureDetector(
              onTap: () => _showPatrullaSheet(p),
              child: _markerWidget(
                label: (p.patrullaNumero ?? '').toString(),
                isStale: p.isStale,
                accent: color,
              ),
            ),
          ),
        );
      }
    }

    final activos = _personal.where((e) => e.compartirUbicacion).length;

    final filteredPersonal = _searchQuery.isEmpty
        ? _personal
        : _personal
              .where((p) => p.name.toLowerCase().contains(_searchQuery))
              .toList();

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Container(
          key: _mapKey,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          height: 380,
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
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'seguridad_vial_app',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Personal (${_personal.length}) · Activos: $activos',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  if (_saving)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _setUbicacionTodos(enabled: true),
                      icon: const Icon(Icons.location_on),
                      label: const Text('Activar todos'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _saving
                          ? null
                          : () => _setUbicacionTodos(enabled: false),
                      icon: const Icon(Icons.location_off),
                      label: const Text('Desactivar todos'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Refrescar',
                    onPressed: _saving ? null : _refreshAll,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (_isSuperadmin) ...[
                const SizedBox(height: 10),
                Text(
                  'Modo Superadmin: viendo ubicaciones del endpoint /mapa/patrullas',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre (ej. saenz)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        FocusScope.of(context).unfocus();
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
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          child: Row(
            children: [
              Text(
                'Listado',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${filteredPersonal.length})',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (filteredPersonal.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Text(
              _personal.isEmpty
                  ? 'Sin personal para mostrar.'
                  : 'Sin resultados para esa búsqueda.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ...filteredPersonal.map(
          (p) => _PatrullaTile(
            item: p,
            onTap: () async => _centerAndGoTop(p),
            onMore: () => _showPatrullaSheet(p),
            onToggle: _saving
                ? null
                : (v) => _setUbicacionUsuario(userId: p.userId, enabled: v),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  void _showQuickLocSheet(_PatrullaLoc loc) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        final isStale = loc.isStale;
        final badgeColor = isStale ? Colors.grey : Colors.green;
        final statusText = isStale ? 'Sin señal reciente' : 'En línea';

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
                      color: Colors.blue.withOpacity(.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.local_police, color: Colors.blue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: badgeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoRow(label: 'Patrulla', value: loc.patrullaNumero ?? 'N/A'),
              _InfoRow(label: 'User ID', value: loc.userId.toString()),
              _InfoRow(label: 'Última', value: loc.capturedAtStr ?? 'N/A'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _centerAndGoTopByCoords(loc.lat, loc.lng);
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text('Centrar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _refreshAll();
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

  void _showPatrullaSheet(_PersonalItem p) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        final isStale = p.isStale;
        final badgeColor = !p.compartirUbicacion
            ? Colors.red
            : (isStale ? Colors.grey : Colors.green);

        final statusText = !p.compartirUbicacion
            ? 'Ubicación desactivada'
            : (isStale ? 'Sin señal reciente' : 'En línea');

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
                      color: Colors.blue.withOpacity(.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.local_police, color: Colors.blue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: badgeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoRow(label: 'Patrulla', value: p.patrullaNumero ?? 'N/A'),
              _InfoRow(label: 'User ID', value: p.userId.toString()),
              _InfoRow(label: 'Última', value: p.lastCapturedAtStr ?? 'N/A'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        if (p.lastLat != null && p.lastLng != null) {
                          await _centerAndGoTop(p);
                        }
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text('Centrar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _refreshAll();
                            },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refrescar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _saving
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await _setUbicacionUsuario(
                            userId: p.userId,
                            enabled: !p.compartirUbicacion,
                          );
                        },
                  icon: Icon(
                    p.compartirUbicacion
                        ? Icons.location_off
                        : Icons.location_on,
                  ),
                  label: Text(
                    p.compartirUbicacion
                        ? 'Desactivar ubicación'
                        : 'Activar ubicación',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapaService {
  static const String baseUrl = 'https://seguridadvial-mich.com/api';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<_PatrullaLoc>> getPatrullas() async {
    final uri = Uri.parse('$baseUrl/mapa/patrullas');
    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List) {
      throw Exception('Respuesta inválida: se esperaba una lista.');
    }

    return decoded
        .map((e) => _PatrullaLoc.fromJson(e as Map<String, dynamic>))
        .toList()
        .cast<_PatrullaLoc>();
  }

  static Future<List<_PersonalItem>> getMiPersonal() async {
    final uri = Uri.parse('$baseUrl/mi-personal');
    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    final list = (decoded is Map && decoded['data'] is List)
        ? (decoded['data'] as List)
        : (decoded is List ? decoded : <dynamic>[]);

    final out = <_PersonalItem>[];
    for (final e in list) {
      if (e is Map<String, dynamic>) out.add(_PersonalItem.fromJson(e));
    }
    return out;
  }

  static Future<void> toggleUbicacionUsuario({
    required int userId,
    required bool enabled,
  }) async {
    final uri = Uri.parse('$baseUrl/mi-personal/$userId/ubicacion');
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({'enabled': enabled}),
    );

    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }
  }

  static Future<void> toggleUbicacionTodos({required bool enabled}) async {
    final uri = Uri.parse('$baseUrl/mi-personal/ubicacion/todos');
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({'enabled': enabled}),
    );

    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }
  }
}

class _PatrullaLoc {
  final int userId;
  final String name;
  final double lat;
  final double lng;
  final String? capturedAtStr;
  final String? patrullaNumero;

  _PatrullaLoc({
    required this.userId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.capturedAtStr,
    required this.patrullaNumero,
  });

  factory _PatrullaLoc.fromJson(Map<String, dynamic> j) {
    return _PatrullaLoc(
      userId: (j['user_id'] ?? 0) is int
          ? (j['user_id'] ?? 0) as int
          : int.tryParse('${j['user_id']}') ?? 0,
      name: (j['name'] ?? '') as String,
      lat: (j['lat'] is num)
          ? (j['lat'] as num).toDouble()
          : double.tryParse('${j['lat']}') ?? 0.0,
      lng: (j['lng'] is num)
          ? (j['lng'] as num).toDouble()
          : double.tryParse('${j['lng']}') ?? 0.0,
      capturedAtStr: j['captured_at'] as String?,
      patrullaNumero: j['patrulla_numero']?.toString(),
    );
  }

  bool get isStale {
    if (capturedAtStr == null || capturedAtStr!.trim().isEmpty) return true;
    final dt = DateTime.tryParse(capturedAtStr!.replaceFirst(' ', 'T'));
    if (dt == null) return true;
    return DateTime.now().difference(dt).inMinutes >= 3;
  }
}

class _PersonalItem {
  final int userId;
  final String name;
  final String email;
  final int? patrullaId;
  final bool compartirUbicacion;

  final String? lastCapturedAtStr;
  final double? lastLat;
  final double? lastLng;
  final bool isStale;

  final String? patrullaNumero;

  _PersonalItem({
    required this.userId,
    required this.name,
    required this.email,
    required this.patrullaId,
    required this.compartirUbicacion,
    required this.lastCapturedAtStr,
    required this.lastLat,
    required this.lastLng,
    required this.isStale,
    required this.patrullaNumero,
  });

  factory _PersonalItem.fromJson(Map<String, dynamic> j) {
    final rawId = j['id'] ?? j['user_id'] ?? 0;
    final id = rawId is int ? rawId : int.tryParse('$rawId') ?? 0;

    final cu = j['compartir_ubicacion'];
    final enabled =
        (cu == true) ||
        (cu is num && cu == 1) ||
        ('$cu'.trim().toLowerCase() == '1') ||
        ('$cu'.trim().toLowerCase() == 'true');

    final patrulla = j['patrulla_id'];
    final patrullaId = patrulla == null
        ? null
        : (patrulla is int ? patrulla : int.tryParse('$patrulla'));

    return _PersonalItem(
      userId: id,
      name: (j['name'] ?? '') as String,
      email: (j['email'] ?? '') as String,
      patrullaId: patrullaId,
      compartirUbicacion: enabled,
      lastCapturedAtStr: null,
      lastLat: null,
      lastLng: null,
      isStale: true,
      patrullaNumero: null,
    );
  }

  _PersonalItem copyWith({
    bool? compartirUbicacion,
    String? lastCapturedAtStr,
    double? lastLat,
    double? lastLng,
    bool? isStale,
    String? patrullaNumero,
  }) {
    return _PersonalItem(
      userId: userId,
      name: name,
      email: email,
      patrullaId: patrullaId,
      compartirUbicacion: compartirUbicacion ?? this.compartirUbicacion,
      lastCapturedAtStr: lastCapturedAtStr ?? this.lastCapturedAtStr,
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
      isStale: isStale ?? this.isStale,
      patrullaNumero: patrullaNumero ?? this.patrullaNumero,
    );
  }
}

class _TopStatusBar extends StatelessWidget {
  final bool loading;
  final bool saving;
  final String? error;
  final DateTime? lastFetchAt;
  final int total;

  const _TopStatusBar({
    required this.loading,
    required this.saving,
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
    } else if (saving) {
      subtitle = 'Guardando cambios...';
    } else if (error != null) {
      subtitle = 'Error: $error';
    } else if (lastFetchAt != null) {
      subtitle = 'Actualizado: ${_formatTime(lastFetchAt!)} · Personal: $total';
    } else {
      subtitle = 'Personal: $total';
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
              color: Colors.blue.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.map, color: Colors.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ubicación de patrullas',
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

class _PatrullaTile extends StatelessWidget {
  final _PersonalItem item;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final ValueChanged<bool>? onToggle;

  const _PatrullaTile({
    required this.item,
    required this.onTap,
    required this.onMore,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = item.compartirUbicacion;

    final dotColor = !enabled
        ? Colors.red
        : (item.isStale ? Colors.grey : Colors.green);

    final subtitle = !enabled
        ? 'Ubicación desactivada'
        : (item.lastCapturedAtStr ?? 'Sin fecha');

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
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
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            enabled ? Icons.location_on : Icons.location_off,
            color: enabled ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          item.name,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: enabled, onChanged: onToggle),
            IconButton(
              tooltip: 'Detalles',
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz),
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
