import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../models/actividad.dart';
import '../../services/actividad_share_service.dart';
import '../../services/actividades_service.dart';
import '../../services/auth_service.dart';
import '../../services/motociclista_report_service.dart';
import '../../widgets/safe_network_image.dart';

class MotociclistaReportsScreen extends StatefulWidget {
  const MotociclistaReportsScreen({super.key});

  @override
  State<MotociclistaReportsScreen> createState() =>
      _MotociclistaReportsScreenState();
}

class _MotociclistaReportsScreenState extends State<MotociclistaReportsScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;
  int? _sharingId;
  List<Actividad> _items = const <Actividad>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await ActividadShareService.onAppResumed();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await MotociclistaReportService.fetchRecentReports();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        _loading = false;
      });
    }
  }

  Future<void> _open(Actividad item) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.actividadesShow,
      arguments: {'actividad_id': item.id},
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _share(Actividad item) async {
    if (_sharingId != null) return;

    setState(() => _sharingId = item.id);
    try {
      final name = await AuthService.getUserName(refreshIfMissing: false);
      final email = await AuthService.getUserEmail();
      final fallback = (name ?? '').trim().isNotEmpty
          ? name!.trim()
          : (email ?? '').trim();
      final text = MotociclistaReportService.buildShareTextFromActividad(
        item,
        informaFallback: fallback,
      );
      await ActividadShareService.compartirTextoConFotos(
        texto: text,
        fotos: item.allPhotoPaths,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir el reporte.\n$e')),
      );
    } finally {
      if (mounted) setState(() => _sharingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Reportes enviados'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _load, child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _error;
    if (error != null && _items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MessageCard(
            icon: Icons.cloud_off_outlined,
            title: 'No se pudo cargar',
            message: error,
            action: OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _MessageCard(
            icon: Icons.inbox_outlined,
            title: 'Sin reportes',
            message: 'No hay reportes enviados en los últimos 30 días.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _ReportTile(
          actividad: item,
          sharing: _sharingId == item.id,
          onTap: () => _open(item),
          onShare: () => _share(item),
        );
      },
    );
  }
}

class _ReportTile extends StatelessWidget {
  final Actividad actividad;
  final bool sharing;
  final VoidCallback onTap;
  final VoidCallback onShare;

  const _ReportTile({
    required this.actividad,
    required this.sharing,
    required this.onTap,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final categoria = actividad.categoria?.nombre.trim() ?? '';
    final subcategoria = actividad.subcategoria?.nombre.trim() ?? '';
    final title = subcategoria.isNotEmpty
        ? subcategoria
        : categoria.isNotEmpty
        ? categoria
        : 'Reporte';
    final fecha = _displayDate(actividad.fecha);
    final hora = _displayHour(actividad.hora);
    final lugar = _displayPlace(actividad);
    final photos = actividad.previewPhotoPaths;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Thumb(path: photos.isEmpty ? null : photos.first),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$fecha · $hora',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(lugar, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(
                      '${actividad.personasParticipantes} elementos · ${actividad.allPhotoPaths.length} fotos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Compartir',
                    onPressed: sharing ? null : onShare,
                    icon: sharing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share_outlined),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _displayDate(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Sin fecha';
    final date = DateTime.tryParse(text);
    if (date == null) return text;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  static String _displayHour(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? 'Sin hora' : text;
  }

  static String _displayPlace(Actividad actividad) {
    final lugar = (actividad.lugar ?? '').trim();
    if (lugar.isNotEmpty) return lugar;

    final coords = (actividad.coordenadasTexto ?? '').trim();
    if (coords.isNotEmpty) return coords;

    return 'Lugar no especificado';
  }
}

class _Thumb extends StatelessWidget {
  final String? path;

  const _Thumb({required this.path});

  @override
  Widget build(BuildContext context) {
    final raw = (path ?? '').trim();
    if (raw.isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.description_outlined, size: 30),
      );
    }

    final url = ActividadesService.toPublicUrl(raw);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SafeNetworkImage(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 72,
          height: 72,
          color: const Color(0xFFEFF6FF),
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 42, color: Colors.blue.shade700),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
