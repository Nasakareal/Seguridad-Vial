import 'package:flutter/material.dart';

import '../../models/guardianes_camino_dispositivo.dart';
import '../../services/auth_service.dart';
import '../../services/guardianes_camino_dispositivos_service.dart';
import '../../services/guardianes_camino_share_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/account_drawer.dart';
import '../login_screen.dart';
import 'widgets/dispositivo_photos.dart';

class DispositivoShowScreen extends StatefulWidget {
  final int dispositivoId;

  const DispositivoShowScreen({super.key, required this.dispositivoId});

  @override
  State<DispositivoShowScreen> createState() => _DispositivoShowScreenState();
}

class _DispositivoShowScreenState extends State<DispositivoShowScreen>
    with WidgetsBindingObserver {
  bool _trackingOn = false;
  bool _busy = false;
  bool _loading = true;
  bool _sharing = false;
  String? _error;
  GuardianesCaminoDispositivo? _dispositivo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
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

  Future<void> _bootstrap() async {
    final running = await TrackingService.isRunning();
    if (!mounted) return;
    setState(() => _trackingOn = running);
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dispositivo =
          await GuardianesCaminoDispositivosService.fetchDispositivo(
            dispositivoId: widget.dispositivoId,
          );
      if (!mounted) return;
      setState(() {
        _dispositivo = dispositivo;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar el dispositivo.\n$e';
      });
    }
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

  Future<void> _shareTarjeta() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final texto = await GuardianesCaminoDispositivosService.fetchWhatsappText(
        dispositivoId: widget.dispositivoId,
      );
      await GuardianesCaminoShareService.compartirTextoEnWhatsapp(texto: texto);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir la tarjeta.\n$e')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _dash(String value) => value.trim().isEmpty ? '-' : value.trim();

  @override
  Widget build(BuildContext context) {
    final item = _dispositivo;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: Text('Dispositivo #${widget.dispositivoId}'),
        actions: [
          IconButton(
            tooltip: 'Compartir tarjeta',
            onPressed: _sharing ? null : _shareTarjeta,
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          const AccountMenuAction(),
        ],
      ),
      drawer: AppDrawer(trackingOn: _trackingOn),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              else if (item != null) ...[
                _InfoCard(
                  title: item.catalogoNombre,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (item.pendienteRevision)
                            const _StatusTag(text: 'Pendiente de revisión'),
                          if (item.aprobado) const _StatusTag(text: 'Aprobado'),
                          if (item.rechazado)
                            const _StatusTag(text: 'Rechazado'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(label: 'Fecha', value: _dash(item.fecha)),
                      _InfoRow(label: 'Hora', value: _dash(item.hora)),
                      _InfoRow(
                        label: 'Ubicación',
                        value: item.ubicacionResumen,
                      ),
                      _InfoRow(
                        label: 'Destacamento',
                        value: _dash(item.destacamentoNombre),
                      ),
                      _InfoRow(
                        label: 'Capturó',
                        value: _dash(item.usuarioNombre),
                      ),
                      _InfoRow(
                        label: 'Responsable',
                        value: _dash(item.nombreResponsable),
                      ),
                      _InfoRow(
                        label: 'Cargo',
                        value: _dash(item.cargoResponsable),
                      ),
                      _InfoRow(
                        label: 'Estado de fuerza',
                        value: '${item.estadoFuerzaParticipante}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Resumen',
                  child: Text(
                    item.resumen,
                    style: TextStyle(color: Colors.grey.shade800, height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Fotos',
                  child: item.fotoUrls.isEmpty
                      ? const Text('Sin fotos registradas.')
                      : DispositivoPhotosStrip(urls: item.fotoUrls),
                ),
                if (item.observacionRevision.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoCard(
                    title: 'Observación de revisión',
                    child: Text(item.observacionRevision),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
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

class _StatusTag extends StatelessWidget {
  final String text;

  const _StatusTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
