import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../models/vialidades_urbanas_dispositivo.dart';
import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/vialidades_urbanas_detalles_service.dart';
import '../../services/vialidades_urbanas_service.dart';
import '../../services/vialidades_urbanas_share_service.dart';
import '../../widgets/app_drawer.dart';
import '../login_screen.dart';

class VialidadesUrbanasDispositivoShowScreen extends StatefulWidget {
  final int dispositivoId;

  const VialidadesUrbanasDispositivoShowScreen({
    super.key,
    required this.dispositivoId,
  });

  @override
  State<VialidadesUrbanasDispositivoShowScreen> createState() =>
      _VialidadesUrbanasDispositivoShowScreenState();
}

class _VialidadesUrbanasDispositivoShowScreenState
    extends State<VialidadesUrbanasDispositivoShowScreen>
    with WidgetsBindingObserver {
  bool _trackingOn = false;
  bool _busy = false;
  bool _loading = true;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;

  String? _error;
  VialidadesUrbanasDispositivo? _dispositivo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrap();
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
      final canSee = await AuthService.isVialidadesUrbanasUser(refresh: true);

      if (!canSee) {
        throw Exception('No tienes acceso a este dispositivo.');
      }

      final dispositivo =
          await VialidadesUrbanasDetallesService.fetchDispositivo(
            dispositivoId: widget.dispositivoId,
          );

      final hasFullOperationalAccess =
          await AuthService.hasFullOperationalAccess();
      final canCreate =
          hasFullOperationalAccess ||
          await AuthService.can('crear operativos vialidades');
      final canEdit =
          hasFullOperationalAccess ||
          await AuthService.can('editar operativos vialidades');
      final canDelete =
          hasFullOperationalAccess ||
          await AuthService.can('eliminar operativos vialidades');

      if (!mounted) return;
      setState(() {
        _dispositivo = dispositivo;
        _canCreate = canCreate;
        _canEdit = canEdit;
        _canDelete = canDelete;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
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

  String _shortHour(String raw) {
    final value = raw.trim();
    if (value.length >= 5) return value.substring(0, 5);
    return value;
  }

  Future<void> _shareTarjeta() async {
    try {
      final texto = await VialidadesUrbanasDetallesService.fetchWhatsappText(
        dispositivoId: widget.dispositivoId,
      );
      await VialidadesUrbanasShareService.compartirTextoEnWhatsapp(
        texto: texto,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir la tarjeta.\n$e')),
      );
    }
  }

  Future<void> _goCreate() async {
    final created = await Navigator.pushNamed(
      context,
      AppRoutes.vialidadesUrbanasDispositivoCreate,
      arguments: <String, dynamic>{'dispositivoId': widget.dispositivoId},
    );

    if (created == true && mounted) {
      await _load();
    }
  }

  Future<void> _goEdit() async {
    final updated = await Navigator.pushNamed(
      context,
      AppRoutes.vialidadesUrbanasDispositivoEdit,
      arguments: <String, dynamic>{'dispositivoId': widget.dispositivoId},
    );

    if (updated == true && mounted) {
      await _load();
    }
  }

  Future<void> _deleteDetalle(
    VialidadesUrbanasDispositivoDetalle detalle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar detalle'),
          content: const Text('¿Deseas eliminar este detalle?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await VialidadesUrbanasDetallesService.deleteDetalle(
        dispositivoId: widget.dispositivoId,
        detalleId: detalle.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detalle eliminado correctamente.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar.\n$e')));
    }
  }

  void _showPhoto(String url) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFE2E8F0),
                  alignment: Alignment.center,
                  height: 220,
                  child: const Icon(Icons.image_not_supported, size: 42),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dispositivo = _dispositivo;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: Text('Detalles #${widget.dispositivoId}'),
        actions: [
          IconButton(
            tooltip: 'Compartir tarjeta',
            onPressed: _shareTarjeta,
            icon: const Icon(Icons.share),
          ),
          IconButton(
            tooltip: 'Recargar',
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
              else if (dispositivo != null) ...[
                _InfoCard(
                  title: dispositivo.asunto.isEmpty
                      ? 'SIN ASUNTO'
                      : dispositivo.asunto,
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Fecha',
                        value: dispositivo.fecha.isEmpty
                            ? '—'
                            : dispositivo.fecha,
                      ),
                      _InfoRow(
                        label: 'Hora',
                        value: dispositivo.hora.isEmpty
                            ? '—'
                            : _shortHour(dispositivo.hora),
                      ),
                      _InfoRow(
                        label: 'Lugar',
                        value: dispositivo.lugar.isEmpty
                            ? 'SIN LUGAR'
                            : dispositivo.lugar,
                      ),
                      _InfoRow(
                        label: 'Municipio',
                        value: dispositivo.municipio.isEmpty
                            ? 'SIN MUNICIPIO'
                            : dispositivo.municipio,
                      ),
                      _InfoRow(
                        label: 'Catalogo',
                        value: dispositivo.catalogoNombre,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_canCreate)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _goCreate,
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar detalle'),
                        ),
                      ),
                    if (_canCreate && _canEdit) const SizedBox(width: 10),
                    if (_canEdit)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _goEdit,
                          icon: const Icon(Icons.edit),
                          label: const Text('Editar'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Detalles realizados',
                  child: dispositivo.detalles.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text('No hay detalles registrados.'),
                          ),
                        )
                      : Column(
                          children: dispositivo.detalles.map((detalle) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _DetalleCard(
                                detalle: detalle,
                                canDelete: _canDelete,
                                onDelete: () => _deleteDetalle(detalle),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Fotos',
                  child: dispositivo.fotos.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(child: Text('Sin fotos')),
                        )
                      : GridView.builder(
                          itemCount: dispositivo.fotos.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.1,
                              ),
                          itemBuilder: (context, index) {
                            final foto = dispositivo.fotos[index];
                            final url = VialidadesUrbanasService.toPublicUrl(
                              foto.ruta,
                            );

                            return GestureDetector(
                              onTap: () => _showPhoto(url),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      url,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFFE2E8F0),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (foto.portada)
                                    Positioned(
                                      left: 8,
                                      top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Text(
                                          'Portada',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'INFORMA EL AGENTE',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .78),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dispositivo.creadorNombre.isEmpty
                            ? 'SIN USUARIO REGISTRADO'
                            : dispositivo.creadorNombre,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetalleCard extends StatelessWidget {
  final VialidadesUrbanasDispositivoDetalle detalle;
  final bool canDelete;
  final VoidCallback onDelete;

  const _DetalleCard({
    required this.detalle,
    required this.canDelete,
    required this.onDelete,
  });

  String _shortHour(String raw) {
    final value = raw.trim();
    if (value.length >= 5) return value.substring(0, 5);
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
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
                  '${detalle.orden}. ${detalle.titulo.isEmpty ? 'DETALLE' : detalle.titulo}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (canDelete)
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Eliminar detalle',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniTag(text: detalle.tipo),
              if (detalle.ubicacion.isNotEmpty)
                _MiniTag(text: detalle.ubicacion),
              if (detalle.hora.isNotEmpty)
                _MiniTag(text: _shortHour(detalle.hora)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detalle.contenido.isEmpty ? 'Sin contenido.' : detalle.contenido,
            style: TextStyle(color: Colors.grey.shade800, height: 1.35),
          ),
        ],
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
        color: const Color(0xFFE2E8F0),
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
