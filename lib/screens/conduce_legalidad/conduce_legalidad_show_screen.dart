import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/routes.dart';
import '../../models/conduce_legalidad.dart';
import '../../services/conduce_legalidad_service.dart';
import '../../services/conduce_legalidad_share_service.dart';
import '../../widgets/safe_network_image.dart';

class ConduceLegalidadShowScreen extends StatefulWidget {
  final int operativoId;

  const ConduceLegalidadShowScreen({super.key, required this.operativoId});

  @override
  State<ConduceLegalidadShowScreen> createState() =>
      _ConduceLegalidadShowScreenState();
}

class _ConduceLegalidadShowScreenState extends State<ConduceLegalidadShowScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _updatingEstado = false;
  bool _sharingTotals = false;
  int? _deletingCapturaId;
  int? _sharingCapturaId;
  int? _downloadingIphCapturaId;
  String? _error;
  ConduceLegalidadOperativo? _operativo;
  ConduceLegalidadMeta? _meta;

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ConduceLegalidadShareService.onAppResumed();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final meta = await ConduceLegalidadService.fetchMeta();
      final operativo = await ConduceLegalidadService.fetchOperativo(
        widget.operativoId,
      );
      if (!mounted) return;
      setState(() {
        _meta = meta;
        _operativo = operativo;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _shareTotals() async {
    final operativo = _operativo;
    if (operativo == null || _sharingTotals) return;

    setState(() => _sharingTotals = true);
    try {
      await ConduceLegalidadShareService.compartirTotalesOperativo(
        operativoId: operativo.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo compartir: $e')));
    } finally {
      if (mounted) {
        setState(() => _sharingTotals = false);
      }
    }
  }

  Future<void> _shareCaptura(ConduceLegalidadCaptura captura) async {
    if (_sharingCapturaId != null) return;

    setState(() => _sharingCapturaId = captura.id);
    try {
      await ConduceLegalidadShareService.compartirCaptura(
        operativoId: widget.operativoId,
        capturaId: captura.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo compartir: $e')));
    } finally {
      if (mounted) {
        setState(() => _sharingCapturaId = null);
      }
    }
  }

  Future<void> _addCaptura() async {
    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.conduceLegalidadCaptura,
      arguments: widget.operativoId,
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  Future<void> _editCaptura(ConduceLegalidadCaptura captura) async {
    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.conduceLegalidadCaptura,
      arguments: {'operativoId': widget.operativoId, 'captura': captura},
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  Future<void> _openBoleta(ConduceLegalidadCaptura captura) async {
    final operativo = _operativo;
    await Navigator.pushNamed(
      context,
      AppRoutes.conduceLegalidadBoleta,
      arguments: {
        'operativoId': widget.operativoId,
        'capturaId': captura.id,
        if (operativo != null) 'operativo': operativo,
        'captura': captura,
      },
    );
  }

  Future<void> _downloadIph(ConduceLegalidadCaptura captura) async {
    if (_downloadingIphCapturaId != null) return;

    setState(() => _downloadingIphCapturaId = captura.id);
    try {
      final bytes = await ConduceLegalidadService.downloadIphPuestaDisposicion(
        operativoId: widget.operativoId,
        capturaId: captura.id,
      );

      final fileName = _safeDocxFileName(
        'iph_puesta_disposicion_cl_${widget.operativoId}_${captura.id}.docx',
      );
      final baseName = p.basenameWithoutExtension(fileName);
      String? savedPath;

      try {
        savedPath = await FileSaver.instance.saveFile(
          name: baseName,
          bytes: bytes,
          ext: 'docx',
          mimeType: MimeType.microsoftWord,
        );
      } catch (_) {
        savedPath = null;
      }

      final file = await _writeTemporaryDocx(bytes: bytes, fileName: fileName);
      if (!mounted) return;

      final savedMessage = (savedPath ?? '').trim().isNotEmpty
          ? 'IPH guardado. Ruta: $savedPath'
          : 'IPH descargado.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(savedMessage)));

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        await Share.shareXFiles([
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          ),
        ], text: 'Informe Policial Homologado $fileName');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar el IPH: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _downloadingIphCapturaId = null);
      }
    }
  }

  Future<File> _writeTemporaryDocx({
    required List<int> bytes,
    required String fileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final uniqueName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(fileName)}';
    final file = File(p.join(dir.path, uniqueName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _safeDocxFileName(String value) {
    var clean = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (clean.isEmpty) clean = 'iph_puesta_disposicion.docx';
    if (!clean.toLowerCase().endsWith('.docx')) clean = '$clean.docx';
    return clean;
  }

  Future<void> _confirmDeleteCaptura(ConduceLegalidadCaptura captura) async {
    if (_deletingCapturaId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar captura'),
          content: const Text(
            'Se eliminara la narrativa, vehiculos, personas y fotos de esta captura.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _deletingCapturaId = captura.id);
    try {
      await ConduceLegalidadService.destroyCaptura(
        operativoId: widget.operativoId,
        capturaId: captura.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captura eliminada correctamente.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    } finally {
      if (mounted) {
        setState(() => _deletingCapturaId = null);
      }
    }
  }

  Future<void> _confirmCloseOperativo() async {
    final operativo = _operativo;
    if (operativo == null || operativo.estado != 'activo' || _updatingEstado) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Inactivar operativo'),
          content: const Text(
            'Al cerrarlo ya no se podran agregar capturas a este punto.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Inactivar'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _closeOperativo();
    }
  }

  Future<void> _closeOperativo() async {
    final operativo = _operativo;
    if (operativo == null) return;

    setState(() => _updatingEstado = true);
    try {
      await ConduceLegalidadService.updateOperativo(operativo.id, {
        'estado': 'cerrado',
        'hora_cierre': _timeNow(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operativo inactivado correctamente.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo cerrar: $e')));
    } finally {
      if (mounted) {
        setState(() => _updatingEstado = false);
      }
    }
  }

  String _timeNow() {
    final now = TimeOfDay.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final operativo = _operativo;
    final canFeed =
        (_meta?.abilities.canFeed ?? false) && operativo?.estado == 'activo';
    final canClose =
        (_meta?.abilities.canManageOperativos ?? false) &&
        operativo?.estado == 'activo';
    final canShareTotals =
        (_meta?.abilities.canViewAllCapturas ?? false) && operativo != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operativo'),
        actions: [
          if (canShareTotals)
            IconButton(
              tooltip: 'Compartir totales',
              onPressed: _sharingTotals ? null : _shareTotals,
              icon: _sharingTotals
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
            ),
          if (canClose)
            PopupMenuButton<String>(
              enabled: !_loading && !_updatingEstado,
              onSelected: (value) {
                if (value == 'cerrar') {
                  _confirmCloseOperativo();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'cerrar',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.lock_outline),
                    title: Text('Inactivar operativo'),
                  ),
                ),
              ],
            ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: (_loading || _updatingEstado) ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: canFeed
          ? FloatingActionButton.extended(
              onPressed: _addCaptura,
              icon: const Icon(Icons.add),
              label: const Text('Agregar captura'),
            )
          : null,
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(operativo)),
    );
  }

  Widget _buildBody(ConduceLegalidadOperativo? operativo) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Panel(
            icon: Icons.error_outline,
            title: 'No se pudo cargar',
            action: OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
            child: Text(_error!),
          ),
        ],
      );
    }

    if (operativo == null) {
      return const Center(child: Text('Operativo no disponible.'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
      children: [
        _OperativoHeader(operativo: operativo, meta: _meta),
        const SizedBox(height: 14),
        if ((operativo.objetivo ?? '').trim().isNotEmpty)
          _Panel(
            icon: Icons.flag_outlined,
            title: 'Objetivo',
            child: Text(operativo.objetivo!),
          ),
        if ((operativo.objetivo ?? '').trim().isNotEmpty)
          const SizedBox(height: 14),
        if (operativo.capturas.isEmpty)
          const _Panel(
            icon: Icons.inbox_outlined,
            title: 'Sin capturas visibles',
            child: Text(
              'Agrega una narrativa, vehiculos o personas para alimentar este punto.',
            ),
          )
        else
          ...operativo.capturas.map(
            (captura) => _CapturaCard(
              captura: captura,
              deleting: _deletingCapturaId == captura.id,
              sharing: _sharingCapturaId == captura.id,
              downloadingIph: _downloadingIphCapturaId == captura.id,
              onTicket: () => _openBoleta(captura),
              onShare: () => _shareCaptura(captura),
              onDownloadIph: () => _downloadIph(captura),
              onEdit: () => _editCaptura(captura),
              onDelete: () => _confirmDeleteCaptura(captura),
            ),
          ),
      ],
    );
  }
}

class _OperativoHeader extends StatelessWidget {
  final ConduceLegalidadOperativo operativo;
  final ConduceLegalidadMeta? meta;

  const _OperativoHeader({required this.operativo, required this.meta});

  @override
  Widget build(BuildContext context) {
    final canViewAll = meta?.abilities.canViewAllCapturas ?? false;
    final count = canViewAll
        ? '${operativo.totalCapturas} capturas'
        : '${operativo.misCapturas} mias';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            operativo.lugar?.trim().isNotEmpty == true
                ? operativo.lugar!
                : operativo.nombre,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [
              operativo.fecha,
              operativo.horaInicio,
              operativo.municipio,
            ].whereType<String>().where((v) => v.trim().isNotEmpty).join(' | '),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderChip(text: operativo.estado.toUpperCase()),
              _HeaderChip(text: count),
              _HeaderChip(text: canViewAll ? 'Vista total' : 'Vista propia'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapturaCard extends StatelessWidget {
  final ConduceLegalidadCaptura captura;
  final bool deleting;
  final bool sharing;
  final bool downloadingIph;
  final VoidCallback onTicket;
  final VoidCallback onShare;
  final VoidCallback onDownloadIph;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CapturaCard({
    required this.captura,
    required this.deleting,
    required this.sharing,
    required this.downloadingIph,
    required this.onTicket,
    required this.onShare,
    required this.onDownloadIph,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final creator = captura.creador?.nombre ?? 'Usuario';
    final vehicleCount = captura.vehiculos.length;
    final peopleCount = captura.personas.length;
    final photoCount = captura.fotos.length;
    final timestamp = [
      captura.fecha,
      captura.hora,
    ].whereType<String>().where((v) => v.trim().isNotEmpty).join(' ');
    final busy = deleting || sharing || downloadingIph;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  creator,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                IconButton(
                  tooltip: 'Boleta',
                  onPressed: onTicket,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.receipt_long_outlined),
                ),
                IconButton(
                  tooltip: 'Compartir WhatsApp',
                  onPressed: onShare,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.share_outlined),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones',
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'iph',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.description_outlined),
                        title: Text('Descargar IPH'),
                      ),
                    ),
                    if (captura.canEdit)
                      const PopupMenuItem<String>(
                        value: 'editar',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                        ),
                      ),
                    if (captura.canDelete)
                      const PopupMenuItem<String>(
                        value: 'eliminar',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          title: Text('Eliminar'),
                        ),
                      ),
                  ],
                  onSelected: (value) {
                    if (value == 'iph') {
                      onDownloadIph();
                    } else if (value == 'editar') {
                      onEdit();
                    } else if (value == 'eliminar') {
                      onDelete();
                    }
                  },
                ),
              ],
            ],
          ),
          if (timestamp.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              timestamp,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
          if ((captura.lugar ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(captura.lugar!, style: TextStyle(color: Colors.grey.shade700)),
          ],
          if ((captura.narrativa ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(captura.narrativa!),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallPill(
                icon: Icons.directions_car,
                text: '$vehicleCount vehiculos',
              ),
              _SmallPill(
                icon: Icons.groups_outlined,
                text: '$peopleCount personas',
              ),
              _SmallPill(icon: Icons.photo_library, text: '$photoCount fotos'),
            ],
          ),
          if (captura.fotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            _FotosGrid(fotos: captura.fotos),
          ],
          if (captura.vehiculos.isNotEmpty) ...[
            const Divider(height: 22),
            ...captura.vehiculos.map(_VehicleLine.new),
          ],
          if (captura.personas.isNotEmpty) ...[
            const Divider(height: 22),
            ...captura.personas.map(_PersonLine.new),
          ],
        ],
      ),
    );
  }
}

class _FotosGrid extends StatelessWidget {
  final List<ConduceLegalidadFoto> fotos;

  const _FotosGrid({required this.fotos});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: fotos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) {
        final url = fotos[index].previewUrl ?? '';
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: Colors.grey.shade100,
            child: SafeNetworkImage(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Icon(Icons.broken_image_outlined));
              },
            ),
          ),
        );
      },
    );
  }
}

class _VehicleLine extends StatelessWidget {
  final ConduceLegalidadVehiculo vehiculo;

  const _VehicleLine(this.vehiculo);

  @override
  Widget build(BuildContext context) {
    final title = [
      vehiculo.marca,
      vehiculo.linea,
      vehiculo.modelo,
    ].whereType<String>().where((v) => v.trim().isNotEmpty).join(' ');
    final placas = vehiculo.placas?.trim().isNotEmpty == true
        ? vehiculo.placas!
        : 'Sin placas';
    final fundamento =
        vehiculo.fundamentoLegal ??
        vehiculo.infraccion?.fundamentoLegal ??
        vehiculo.infraccion?.display ??
        '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.directions_car, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.trim().isEmpty ? 'Vehiculo' : title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(placas, style: TextStyle(color: Colors.grey.shade700)),
                if (fundamento.trim().isNotEmpty)
                  Text(
                    fundamento,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF92400E)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonLine extends StatelessWidget {
  final ConduceLegalidadPersona persona;

  const _PersonLine(this.persona);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.badge_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  persona.nombre?.trim().isNotEmpty == true
                      ? persona.nombre!
                      : 'Persona',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if ((persona.numeroLicencia ?? '').trim().isNotEmpty)
                  Text(
                    'Licencia ${persona.numeroLicencia}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                if (persona.infraccion != null)
                  Text(
                    '${persona.infraccion!.display} (${persona.infraccion!.sancionResumen})',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF92400E)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String text;

  const _HeaderChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? action;

  const _Panel({
    required this.icon,
    required this.title,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    );
  }
}
