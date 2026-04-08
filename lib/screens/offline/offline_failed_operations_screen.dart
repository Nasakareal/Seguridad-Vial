import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_service.dart';

class OfflineFailedOperationsScreen extends StatefulWidget {
  const OfflineFailedOperationsScreen({super.key});

  @override
  State<OfflineFailedOperationsScreen> createState() =>
      _OfflineFailedOperationsScreenState();
}

class _OfflineFailedOperationsScreenState
    extends State<OfflineFailedOperationsScreen> {
  bool _loading = true;
  bool _retrying = false;
  final Set<String> _deletingIds = <String>{};
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  int _pendingItems = 0;
  int _failedItems = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ownerKey = await AuthService.getSessionOwnerKey();
      final snapshot = await OfflineSyncService.loadQueueSnapshot();
      final items = snapshot.where((op) {
        final state = (op['state'] ?? '').toString();
        if (state != 'failed' && state != 'pending') return false;
        if ((ownerKey ?? '').trim().isEmpty) return true;
        return (op['owner_key'] ?? '').toString() == ownerKey;
      }).toList();

      items.sort((a, b) {
        final aDate = DateTime.tryParse((a['created_at'] ?? '').toString());
        final bDate = DateTime.tryParse((b['created_at'] ?? '').toString());
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      if (!mounted) return;
      final pending = items
          .where((op) => (op['state'] ?? '').toString() == 'pending')
          .length;
      final failed = items
          .where((op) => (op['state'] ?? '').toString() == 'failed')
          .length;
      setState(() {
        _items = items;
        _pendingItems = pending;
        _failedItems = failed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la bandeja offline: $e';
        _pendingItems = 0;
        _failedItems = 0;
        _loading = false;
      });
    }
  }

  Future<void> _retryAll() async {
    if (_retrying) return;

    setState(() => _retrying = true);
    try {
      await OfflineSyncService.flushPending(force: true, announceSkipped: true);
      await _load();
    } finally {
      if (mounted) {
        setState(() => _retrying = false);
      }
    }
  }

  Future<void> _openCorrection(Map<String, dynamic> op) async {
    final destination = _destinationFor(op);
    if (destination == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este registro todavía no tiene una corrección directa desde esta bandeja.',
          ),
        ),
      );
      return;
    }

    await Navigator.pushNamed(
      context,
      destination.route,
      arguments: destination.arguments,
    );

    await _load();
  }

  Future<void> _deleteOperation(Map<String, dynamic> op) async {
    final operationId = (op['id'] ?? '').toString().trim();
    if (operationId.isEmpty || _deletingIds.contains(operationId)) return;

    final ownerKey = await AuthService.getSessionOwnerKey();
    if ((ownerKey ?? '').trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo identificar la sesión actual.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Borrar registro offline'),
          content: Text(
            '¿Seguro que quieres borrar "${_titleFor(op)}"? '
            'También se eliminarán sus dependencias offline si existen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Borrar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _deletingIds.add(operationId));

    try {
      await OfflineSyncService.discardOperation(
        ownerKey: ownerKey!.trim(),
        operationId: operationId,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro offline eliminado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo borrar: $e')));
    } finally {
      if (mounted) {
        setState(() => _deletingIds.remove(operationId));
      }
    }
  }

  _OfflineDestination? _destinationFor(Map<String, dynamic> op) {
    final label = (op['label'] ?? '').toString().trim().toLowerCase();
    final method = (op['method'] ?? '').toString().trim().toUpperCase();
    final url = (op['url'] ?? '').toString().trim().toLowerCase();
    final fields = _mapFrom(op['fields']);

    if (method != 'POST') return null;

    if (label == 'hecho' &&
        url.endsWith('/hechos') &&
        (fields['_method'] ?? '').toString().trim().toUpperCase() != 'PUT') {
      return _OfflineDestination(
        route: AppRoutes.accidentesCreate,
        arguments: {'offlineDraft': op},
      );
    }

    if (label == 'actividad' &&
        url.endsWith('/actividades') &&
        (fields['_method'] ?? '').toString().trim().toUpperCase() != 'PUT') {
      return _OfflineDestination(
        route: AppRoutes.actividadesCreate,
        arguments: {'offlineDraft': op},
      );
    }

    if (label == 'vehículo' && url.endsWith('/vehiculos')) {
      return _OfflineDestination(
        route: AppRoutes.vehiculosCreate,
        arguments: {
          'offlineDraft': op,
          if (_hechoIdFromOperation(op) > 0)
            'hechoId': _hechoIdFromOperation(op),
          if (_hechoClientUuidFromOperation(op).isNotEmpty)
            'hechoClientUuid': _hechoClientUuidFromOperation(op),
        },
      );
    }

    if (label == 'lesionado' && url.endsWith('/lesionados')) {
      return _OfflineDestination(
        route: AppRoutes.lesionadoCreate,
        arguments: {
          'offlineDraft': op,
          if (_hechoIdFromOperation(op) > 0)
            'hechoId': _hechoIdFromOperation(op),
          if (_hechoClientUuidFromOperation(op).isNotEmpty)
            'hechoClientUuid': _hechoClientUuidFromOperation(op),
        },
      );
    }

    return null;
  }

  int _hechoIdFromOperation(Map<String, dynamic> op) {
    final body = _mapFrom(op['body']);
    return int.tryParse((body['hecho_id'] ?? '0').toString()) ?? 0;
  }

  String _hechoClientUuidFromOperation(Map<String, dynamic> op) {
    final body = _mapFrom(op['body']);
    return (body['hecho_client_uuid'] ?? '').toString().trim();
  }

  Map<String, dynamic> _mapFrom(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  String _titleFor(Map<String, dynamic> op) {
    final label = (op['label'] ?? 'Registro').toString().trim();
    final body = _mapFrom(op['body']);
    final fields = _mapFrom(op['fields']);

    if (label == 'Hecho') {
      final folio = (fields['folio_c5i'] ?? '').toString().trim();
      final fecha = (fields['fecha'] ?? '').toString().trim();
      if (folio.isNotEmpty && fecha.isNotEmpty) {
        return 'Hecho $folio · $fecha';
      }
      if (folio.isNotEmpty) return 'Hecho $folio';
    }

    if (label == 'Vehículo') {
      final marca = (body['marca'] ?? '').toString().trim();
      final linea = (body['linea'] ?? '').toString().trim();
      final placas = (body['placas'] ?? '').toString().trim();
      final parts = <String>[
        marca,
        linea,
        placas,
      ].where((item) => item.isNotEmpty).toList();
      if (parts.isNotEmpty) return parts.join(' · ');
    }

    if (label == 'Lesionado') {
      final nombre = (body['nombre'] ?? '').toString().trim();
      final tipo = (body['tipo_lesion'] ?? '').toString().trim();
      if (nombre.isNotEmpty && tipo.isNotEmpty) {
        return '$nombre · $tipo';
      }
      if (nombre.isNotEmpty) return nombre;
    }

    if (label == 'Actividad') {
      final isUpdate =
          (fields['_method'] ?? '').toString().trim().toUpperCase() == 'PUT';
      final categoriaId = (fields['actividad_categoria_id'] ?? '')
          .toString()
          .trim();
      final subcategoriaId = (fields['actividad_subcategoria_id'] ?? '')
          .toString()
          .trim();
      final motivo = (fields['motivo'] ?? '').toString().trim();
      final lugar = (fields['lugar'] ?? '').toString().trim();
      final fecha = (fields['fecha'] ?? '').toString().trim();
      final actividadId = _actividadIdFromOperation(op);

      final parts = <String>[
        if (actividadId > 0) '#$actividadId',
        if (motivo.isNotEmpty) motivo,
        if (lugar.isNotEmpty) lugar,
        if (fecha.isNotEmpty) fecha,
        if (subcategoriaId.isNotEmpty) 'Subcat. $subcategoriaId',
        if (categoriaId.isNotEmpty) 'Cat. $categoriaId',
      ];

      if (parts.isNotEmpty) {
        final prefix = isUpdate ? 'Actividad editada' : 'Actividad';
        return '$prefix ${parts.join(' · ')}';
      }

      return isUpdate ? 'Actividad editada' : 'Actividad';
    }

    return label;
  }

  String _subtitleFor(Map<String, dynamic> op) {
    final label = (op['label'] ?? '').toString().trim();
    final body = _mapFrom(op['body']);
    final fields = _mapFrom(op['fields']);
    final dependsOn = (op['depends_on_operation_id'] ?? '').toString().trim();

    if (label == 'Hecho') {
      final perito = (fields['perito'] ?? '').toString().trim();
      final situacion = (fields['situacion'] ?? '').toString().trim();
      final calle = (fields['calle'] ?? '').toString().trim();
      final parts = <String>[
        perito,
        situacion,
        calle,
      ].where((item) => item.isNotEmpty).toList();
      return parts.join(' · ');
    }

    if (label == 'Vehículo') {
      final hechoId = (body['hecho_id'] ?? '').toString().trim();
      final hechoClient = (body['hecho_client_uuid'] ?? '').toString().trim();
      if (hechoId.isNotEmpty) {
        return 'Hecho #$hechoId';
      }
      if (hechoClient.isNotEmpty) {
        return 'Hecho offline ${_shortId(hechoClient)}';
      }
    }

    if (label == 'Lesionado') {
      final hechoId = (body['hecho_id'] ?? '').toString().trim();
      final hechoClient = (body['hecho_client_uuid'] ?? '').toString().trim();
      if (hechoId.isNotEmpty) {
        return 'Hecho #$hechoId';
      }
      if (hechoClient.isNotEmpty) {
        return 'Hecho offline ${_shortId(hechoClient)}';
      }
    }

    if (label == 'Actividad') {
      final lugar = (fields['lugar'] ?? '').toString().trim();
      final municipio = (fields['municipio'] ?? '').toString().trim();
      final fecha = (fields['fecha'] ?? '').toString().trim();
      final hora = (fields['hora'] ?? '').toString().trim();
      final fotos = _countFilesForField(op, 'fotos[]');
      final parts = <String>[
        lugar,
        municipio,
        fecha,
        hora,
        if (fotos > 0) '$fotos foto(s)',
      ].where((item) => item.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        return parts.join(' · ');
      }
    }

    if (dependsOn.isNotEmpty) {
      return 'Depende de ${_shortId(dependsOn)}';
    }

    return (op['url'] ?? '').toString();
  }

  String _shortId(String value) {
    final clean = value.trim();
    if (clean.length <= 10) return clean;
    return clean.substring(clean.length - 10);
  }

  int _actividadIdFromOperation(Map<String, dynamic> op) {
    final url = (op['url'] ?? '').toString().trim();
    final match = RegExp(r'/actividades/(\d+)$').firstMatch(url);
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  int _countFilesForField(Map<String, dynamic> op, String fieldName) {
    final files = op['files'];
    if (files is! List) return 0;

    var total = 0;
    for (final item in files.whereType<Map>()) {
      if ((item['field'] ?? '').toString().trim() == fieldName) {
        total += 1;
      }
    }
    return total;
  }

  String _formatDate(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return 'Sin fecha';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  bool _isFailed(Map<String, dynamic> op) {
    return (op['state'] ?? '').toString() == 'failed';
  }

  String _actionLabelFor(Map<String, dynamic> op) {
    return _isFailed(op) ? 'Corregir' : 'Abrir';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Bandeja offline'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (_failedItems > 0 ? Colors.orange : Colors.teal)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_failedItems > 0 ? Colors.orange : Colors.teal)
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aquí aparecen los registros guardados sin conexión y los que requieren revisión.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pendientes: $_pendingItems · Con error: $_failedItems',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Puedes reintentar todos o abrir cada borrador para continuar la captura o corregirlo con sus datos precargados.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _retrying ? null : _retryAll,
                      icon: _retrying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(
                        _retrying ? 'Reintentando...' : 'Reintentar todo',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _StateCard(
                  icon: Icons.error_outline,
                  message: _error!,
                  actionLabel: 'Reintentar',
                  onAction: _load,
                )
              else if (_items.isEmpty)
                const _StateCard(
                  icon: Icons.cloud_done_outlined,
                  message:
                      'No hay registros offline para este usuario en este momento.',
                )
              else
                ..._items.map((op) {
                  final canCorrect = _destinationFor(op) != null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OperationCard(
                      operationId: (op['id'] ?? '').toString().trim(),
                      title: _titleFor(op),
                      subtitle: _subtitleFor(op),
                      isFailed: _isFailed(op),
                      isDeleting: _deletingIds.contains(
                        (op['id'] ?? '').toString().trim(),
                      ),
                      createdAt: _formatDate(
                        (op['created_at'] ?? '').toString(),
                      ),
                      detail:
                          (op['last_error'] ??
                                  (_isFailed(op)
                                      ? 'Sin detalle'
                                      : 'Pendiente de sincronizar cuando haya conexión.'))
                              .toString()
                              .trim(),
                      actionLabel: canCorrect ? _actionLabelFor(op) : null,
                      onAction: canCorrect ? () => _openCorrection(op) : null,
                      onDelete: () => _deleteOperation(op),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationCard extends StatelessWidget {
  final String operationId;
  final String title;
  final String subtitle;
  final bool isFailed;
  final bool isDeleting;
  final String createdAt;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDelete;

  const _OperationCard({
    required this.operationId,
    required this.title,
    required this.subtitle,
    required this.isFailed,
    required this.isDeleting,
    required this.createdAt,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
    required this.onDelete,
  });

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isFailed ? Colors.orange : Colors.teal).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isFailed ? 'Error' : 'En cola',
                  style: TextStyle(
                    color: isFailed
                        ? const Color(0xFF9A3412)
                        : const Color(0xFF0F766E),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Guardado: $createdAt',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isFailed
                  ? const Color(0xFFFFF7ED)
                  : const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFailed
                    ? const Color(0xFFFED7AA)
                    : const Color(0xFF99F6E4),
              ),
            ),
            child: Text(
              detail,
              style: TextStyle(
                color: isFailed
                    ? const Color(0xFF9A3412)
                    : const Color(0xFF115E59),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if ((actionLabel != null && onAction != null) ||
              onDelete != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (actionLabel != null && onAction != null)
                    FilledButton.icon(
                      onPressed: isDeleting ? null : onAction,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(actionLabel!),
                    ),
                  if (onDelete != null)
                    OutlinedButton.icon(
                      onPressed: isDeleting ? null : onDelete,
                      icon: isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                      label: Text(isDeleting ? 'Borrando...' : 'Borrar'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _StateCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                onAction?.call();
              },
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfflineDestination {
  final String route;
  final Map<String, dynamic> arguments;

  const _OfflineDestination({required this.route, required this.arguments});
}
