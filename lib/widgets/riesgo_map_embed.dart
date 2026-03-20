import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/riesgo_service.dart';
import '../models/riesgo_cell.dart';
import 'safe_osm_tile_layer.dart';

class RiesgoMapEmbed extends StatefulWidget {
  final int precision;
  final int ventanaMin;
  final int wazeHoras;
  final int top;
  final double minScore;

  const RiesgoMapEmbed({
    super.key,
    required this.precision,
    required this.ventanaMin,
    required this.wazeHoras,
    required this.top,
    required this.minScore,
  });

  @override
  State<RiesgoMapEmbed> createState() => _RiesgoMapEmbedState();
}

class _RiesgoMapEmbedState extends State<RiesgoMapEmbed> {
  final _mapController = MapController();

  bool _loading = true;
  String? _error;
  DateTime? _lastUpdated;

  List<RiesgoCell> _cells = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _radiusMeters(double score) {
    final double s = score < 0 ? 0.0 : score;
    final double r = 120.0 + (s * 35.0);
    if (r > 650.0) return 650.0;
    return r;
  }

  Color _riskColor(double score) {
    if (score >= 20) return const Color(0xFF7F0000);
    if (score >= 10) return const Color(0xFFB30000);
    if (score >= 6) return const Color(0xFFE34A33);
    if (score >= 3) return const Color(0xFFFC8D59);
    return const Color(0xFFFDD0A2);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await RiesgoService.fetchRiesgoCells(
        precision: widget.precision,
        ventanaMin: widget.ventanaMin,
        wazeHoras: widget.wazeHoras,
        top: widget.top,
        minScore: widget.minScore,
      );

      if (!mounted) return;

      setState(() {
        _cells = res;
        _lastUpdated = DateTime.now();
      });

      if (_cells.isEmpty) {
        _mapController.move(const LatLng(19.703, -101.186), 12);
      } else {
        final best = _cells.first;
        _mapController.move(LatLng(best.lat, best.lng), 13);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo cargar zonas de riesgo.');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _fmtTime(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final overlay = Positioned(
      left: 12,
      right: 12,
      top: 12,
      child: Row(
        children: [
          Expanded(
            child: _TopStatus(
              loading: _loading,
              error: _error,
              count: _cells.length,
              lastUpdated: _lastUpdated,
              fmtTime: _fmtTime,
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _loading ? null : _load,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Icon(Icons.refresh, size: 20),
              ),
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(19.703, -101.186),
              initialZoom: 12,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              buildSafeOpenStreetMapTileLayer(
                userAgentPackageName: 'com.nasaka.seguridad_vial_app',
                maxZoom: 19,
              ),
              CircleLayer(
                circles: _cells.map((c) {
                  final color = _riskColor(c.score);
                  return CircleMarker(
                    point: LatLng(c.lat, c.lng),
                    radius: _radiusMeters(c.score),
                    useRadiusInMeter: true,
                    color: color.withOpacity(0.35),
                    borderStrokeWidth: 2,
                    borderColor: color.withOpacity(0.85),
                  );
                }).toList(),
              ),
              MarkerLayer(
                markers: _cells.take(18).map((c) {
                  return Marker(
                    point: LatLng(c.lat, c.lng),
                    width: 140,
                    height: 36,
                    child: _RiskChip(score: c.score),
                  );
                }).toList(),
              ),
            ],
          ),
          overlay,
          if (_loading)
            const Positioned(
              bottom: 14,
              left: 14,
              child: _BottomPill(text: 'Cargando zonas de riesgo…'),
            ),
          if (!_loading && _cells.isEmpty && _error == null)
            const Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: _BottomPill(
                text: 'Sin zonas de riesgo alto en este momento.',
              ),
            ),
          if (_error != null)
            const Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: _BottomPill(text: 'Error al cargar (revisa red / token).'),
            ),
        ],
      ),
    );
  }
}

class _TopStatus extends StatelessWidget {
  final bool loading;
  final String? error;
  final int count;
  final DateTime? lastUpdated;
  final String Function(DateTime) fmtTime;

  const _TopStatus({
    required this.loading,
    required this.error,
    required this.count,
    required this.lastUpdated,
    required this.fmtTime,
  });

  @override
  Widget build(BuildContext context) {
    final text = loading
        ? 'Cargando…'
        : (error != null ? 'Sin conexión' : 'Zonas de riesgo alto: $count');

    final sub = (lastUpdated == null)
        ? '—'
        : 'Actualizado ${fmtTime(lastUpdated!)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.08),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskChip extends StatelessWidget {
  final double score;
  const _RiskChip({required this.score});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'Riesgo ${score.toStringAsFixed(1)}',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
        ),
      ),
    );
  }
}

class _BottomPill extends StatelessWidget {
  final String text;
  const _BottomPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}
