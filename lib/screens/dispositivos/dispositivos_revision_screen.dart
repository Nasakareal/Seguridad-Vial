import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../models/guardianes_camino_dispositivo.dart';
import '../../services/app_version_service.dart';
import '../../services/auth_service.dart';
import '../../services/guardianes_camino_dispositivos_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/app_drawer.dart';
import '../login_screen.dart';
import 'widgets/dispositivo_photos.dart';

class DispositivosRevisionScreen extends StatefulWidget {
  const DispositivosRevisionScreen({super.key});

  @override
  State<DispositivosRevisionScreen> createState() =>
      _DispositivosRevisionScreenState();
}

class _DispositivosRevisionScreenState extends State<DispositivosRevisionScreen>
    with WidgetsBindingObserver {
  bool _trackingOn = false;
  bool _bootstrapped = false;
  bool _busy = false;
  bool _loading = true;
  bool _canReview = false;
  String? _error;
  final Set<int> _actingIds = <int>{};
  List<GuardianesCaminoDispositivo> _items =
      const <GuardianesCaminoDispositivo>[];

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
      await _bootstrapTrackingStatusOnly();
      if (!mounted) return;
      await _load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final running = await TrackingService.isRunning();
      if (!mounted) return;
      setState(() => _trackingOn = running);
    }
  }

  Future<void> _bootstrapTrackingStatusOnly() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final running = await TrackingService.isRunning();
    if (!mounted) return;
    setState(() => _trackingOn = running);
  }

  Future<void> _logout(BuildContext context) async {
    if (_busy) return;
    _busy = true;

    try {
      await TrackingService.stop();
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

  Future<bool> _hasReviewRole() async {
    if (await AuthService.isSuperadmin()) return true;
    return await AuthService.hasRoleName('RT') ||
        await AuthService.hasRoleName('Encargado de Destacamento');
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final hasUnitAccess = await AuthService.isCarreterasUser(refresh: true);
      final hasFullOperationalAccess =
          await AuthService.hasFullOperationalAccess();
      final hasReviewRole = await _hasReviewRole();
      final hasEditPermission =
          hasFullOperationalAccess ||
          await AuthService.can('editar operativos carreteras');

      if (!hasUnitAccess || !hasReviewRole || !hasEditPermission) {
        if (!mounted) return;
        setState(() {
          _items = const <GuardianesCaminoDispositivo>[];
          _canReview = false;
          _loading = false;
          _error =
              'Solo RT o Encargado de Destacamento pueden revisar estos dispositivos.';
        });
        return;
      }

      final result =
          await GuardianesCaminoDispositivosService.fetchPendientesRevision();

      if (!mounted) return;
      setState(() {
        _items = result.items;
        _canReview = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const <GuardianesCaminoDispositivo>[];
        _canReview = false;
        _loading = false;
        _error = 'No se pudieron cargar los pendientes.\n$e';
      });
    }
  }

  Future<void> _aprobar(GuardianesCaminoDispositivo item) async {
    await _runAction(item, () {
      return GuardianesCaminoDispositivosService.aprobarRevision(
        dispositivoId: item.id,
      );
    }, 'Dispositivo aprobado.');
  }

  Future<void> _rechazar(GuardianesCaminoDispositivo item) async {
    final controller = TextEditingController();

    final observacion = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rechazar dispositivo'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Rechazar'),
            ),
          ],
        );
      },
    );

    if (observacion == null) return;
    if (observacion.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el motivo del rechazo.')),
      );
      return;
    }

    await _runAction(item, () {
      return GuardianesCaminoDispositivosService.rechazarRevision(
        dispositivoId: item.id,
        observacion: observacion,
      );
    }, 'Dispositivo rechazado.');
  }

  Future<void> _runAction(
    GuardianesCaminoDispositivo item,
    Future<GuardianesCaminoDispositivo> Function() action,
    String successMessage,
  ) async {
    if (_actingIds.contains(item.id)) return;

    setState(() => _actingIds.add(item.id));

    try {
      await action();
      if (!mounted) return;
      setState(() {
        _items = _items.where((current) => current.id != item.id).toList();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo completar: $e')));
    } finally {
      if (mounted) {
        setState(() => _actingIds.remove(item.id));
      }
    }
  }

  void _showDetalle(GuardianesCaminoDispositivo item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            shrinkWrap: true,
            children: [
              Text(
                item.catalogoNombre,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Capturó', value: _dash(item.usuarioNombre)),
              _InfoRow(label: 'Fecha', value: _dash(item.fecha)),
              _InfoRow(label: 'Hora', value: _dash(item.hora)),
              _InfoRow(label: 'Ubicación', value: item.ubicacionResumen),
              _InfoRow(
                label: 'Destacamento',
                value: _dash(item.destacamentoNombre),
              ),
              _InfoRow(
                label: 'Responsable',
                value: _dash(item.nombreResponsable),
              ),
              _InfoRow(
                label: 'Estado de fuerza',
                value: '${item.estadoFuerzaParticipante}',
              ),
              _InfoRow(label: 'Fotos', value: '${item.fotosCount}'),
              DispositivoPhotosStrip(urls: item.fotoUrls),
              const SizedBox(height: 12),
              const Text(
                'Resumen',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(item.resumen),
            ],
          ),
        );
      },
    );
  }

  String _dash(String value) => value.trim().isEmpty ? '-' : value.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Revisión Carreteras'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: AppDrawer(
        trackingOn: _trackingOn,
        onLogout: () => _logout(context),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _Header(total: _items.length),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Center(
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              else if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text('No hay pendientes de revisión.')),
                )
              else
                ..._items.map((item) {
                  final acting = _actingIds.contains(item.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RevisionCard(
                      item: item,
                      acting: acting,
                      enabled: _canReview,
                      onTap: () => _showDetalle(item),
                      onApprove: () => _aprobar(item),
                      onReject: () => _rechazar(item),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      floatingActionButton: _canReview
          ? FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.dispositivos),
              icon: const Icon(Icons.list_alt),
              label: const Text('Listado'),
            )
          : null,
    );
  }
}

class _Header extends StatelessWidget {
  final int total;

  const _Header({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.fact_check_outlined, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pendientes de revisión',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total registros esperando RT o Encargado',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisionCard extends StatelessWidget {
  final GuardianesCaminoDispositivo item;
  final bool acting;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RevisionCard({
    required this.item,
    required this.acting,
    required this.enabled,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.catalogoNombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  _StatusTag(text: 'Pendiente'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.ubicacionResumen,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.resumen,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
              DispositivoPhotoPreview(urls: item.fotoUrls),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniTag(text: item.fecha.isEmpty ? 'Sin fecha' : item.fecha),
                  if (item.hora.isNotEmpty) _MiniTag(text: item.hora),
                  if (item.usuarioNombre.isNotEmpty)
                    _MiniTag(text: item.usuarioNombre),
                  if (item.destacamentoNombre.isNotEmpty)
                    _MiniTag(text: item.destacamentoNombre),
                  _MiniTag(text: '${item.fotosCount} fotos'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: acting || !enabled ? null : onReject,
                      icon: const Icon(Icons.close),
                      label: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: acting || !enabled ? null : onApprove,
                      icon: acting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Aprobar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String text;

  const _StatusTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.w900,
          fontSize: 12,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
