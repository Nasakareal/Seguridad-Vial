import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../models/conduce_legalidad.dart';
import '../../services/auth_service.dart';
import '../../services/conduce_legalidad_service.dart';
import '../../services/conduce_legalidad_share_service.dart';
import '../../widgets/app_drawer.dart';
import 'conduce_legalidad_operativo_form_screen.dart';

class ConduceLegalidadScreen extends StatefulWidget {
  const ConduceLegalidadScreen({super.key});

  @override
  State<ConduceLegalidadScreen> createState() => _ConduceLegalidadScreenState();
}

class _ConduceLegalidadScreenState extends State<ConduceLegalidadScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _canCreateLocal = false;
  int? _deletingOperativoId;
  int? _sharingOperativoId;
  String? _error;
  ConduceLegalidadMeta? _meta;
  List<ConduceLegalidadOperativo> _operativos = const [];

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
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final canCreate = await AuthService.canCreateConduceLegalidad();
      final meta = await ConduceLegalidadService.fetchMeta();
      final operativos = await ConduceLegalidadService.fetchOperativos(
        incluirCerrados: meta.abilities.canManageOperativos,
      );
      if (!mounted) return;
      setState(() {
        _canCreateLocal = canCreate;
        _meta = meta;
        _operativos = operativos;
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

  Future<void> _openCreate() async {
    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.conduceLegalidadCreate,
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  Future<void> _shareTotals(ConduceLegalidadOperativo operativo) async {
    if (_sharingOperativoId != null) return;

    setState(() => _sharingOperativoId = operativo.id);
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
        setState(() => _sharingOperativoId = null);
      }
    }
  }

  Future<void> _openEdit(ConduceLegalidadOperativo operativo) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ConduceLegalidadOperativoFormScreen(initialOperativo: operativo),
      ),
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  Future<void> _openShow(int id) async {
    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.conduceLegalidadShow,
      arguments: id,
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  Future<void> _confirmDeleteOperativo(
    ConduceLegalidadOperativo operativo,
  ) async {
    if (_deletingOperativoId != null) return;

    final punto = operativo.lugar?.trim().isNotEmpty == true
        ? operativo.lugar!
        : operativo.nombre;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar operativo'),
          content: Text(
            'Se eliminara "$punto" junto con sus capturas, vehiculos, personas y fotos.',
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

    setState(() => _deletingOperativoId = operativo.id);
    try {
      await ConduceLegalidadService.destroyOperativo(operativo.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operativo eliminado correctamente.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    } finally {
      if (mounted) {
        setState(() => _deletingOperativoId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final canCreate =
        _canCreateLocal || (meta?.abilities.canCreateOperativo ?? false);

    return Scaffold(
      drawer: const AppDrawer(trackingOn: false),
      appBar: AppBar(
        title: const Text('Conduce legalidad'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: const Text('Activar operativo'),
            )
          : null,
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(meta)),
    );
  }

  Widget _buildBody(ConduceLegalidadMeta? meta) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusPanel(
            icon: Icons.error_outline,
            title: 'No se pudo cargar',
            message: _error!,
            action: OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
      children: [
        _Header(meta: meta),
        const SizedBox(height: 14),
        if ((meta?.fundamentosCorralon.length ?? 0) == 0)
          const _StatusPanel(
            icon: Icons.gavel_outlined,
            title: 'Catalogo legal sin registros',
            message:
                'No se recibieron fundamentos activos con retiro de vehiculo. Revisa el catalogo del sistema antes de operar corralon.',
          ),
        if ((meta?.fundamentosCorralon.length ?? 0) == 0)
          const SizedBox(height: 14),
        if (_operativos.isEmpty)
          const _StatusPanel(
            icon: Icons.fact_check_outlined,
            title: 'Sin operativos activos',
            message:
                'Cuando RT o mando habilitado active un punto, aparecera aqui para alimentar capturas.',
          )
        else
          ..._operativos.map(
            (operativo) => _OperativoCard(
              operativo: operativo,
              canViewAll: meta?.abilities.canViewAllCapturas ?? false,
              deleting: _deletingOperativoId == operativo.id,
              sharing: _sharingOperativoId == operativo.id,
              onTap: () => _openShow(operativo.id),
              onShareTotals: () => _shareTotals(operativo),
              onEdit: () => _openEdit(operativo),
              onDelete: () => _confirmDeleteOperativo(operativo),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final ConduceLegalidadMeta? meta;

  const _Header({required this.meta});

  @override
  Widget build(BuildContext context) {
    final abilities =
        meta?.abilities ?? const ConduceLegalidadAbilities.empty();
    final fundamentos = meta?.fundamentosCorralon.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operativo conduce con legalidad',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            abilities.canViewAllCapturas
                ? 'Vista total de capturas del operativo.'
                : 'Solo veras las capturas que alimentes.',
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                text: abilities.canCreateOperativo ? 'Puede activar' : 'Apoyo',
              ),
              _Chip(
                text: abilities.scope == 'all' ? 'Vista total' : 'Vista propia',
              ),
              _Chip(text: '$fundamentos fundamentos'),
            ],
          ),
        ],
      ),
    );
  }
}

class _OperativoCard extends StatelessWidget {
  final ConduceLegalidadOperativo operativo;
  final bool canViewAll;
  final bool deleting;
  final bool sharing;
  final VoidCallback onTap;
  final VoidCallback onShareTotals;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OperativoCard({
    required this.operativo,
    required this.canViewAll,
    required this.deleting,
    required this.sharing,
    required this.onTap,
    required this.onShareTotals,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final counts = canViewAll
        ? '${operativo.totalCapturas} capturas'
        : '${operativo.misCapturas} mias';
    final hasAdminActions = operativo.canEdit || operativo.canDelete;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
          foregroundColor: const Color(0xFF2563EB),
          child: const Icon(Icons.fact_check_outlined),
        ),
        title: Text(
          operativo.lugar?.isNotEmpty == true
              ? operativo.lugar!
              : operativo.nombre,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            [
                  operativo.fecha,
                  operativo.municipio,
                  operativo.colonia,
                  counts,
                  operativo.estado.toUpperCase(),
                ]
                .whereType<String>()
                .where((v) => v.trim().isNotEmpty)
                .join('  |  '),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (deleting || sharing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              if (canViewAll)
                IconButton(
                  tooltip: 'Compartir totales',
                  onPressed: onShareTotals,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.share_outlined),
                ),
              if (hasAdminActions)
                PopupMenuButton<String>(
                  tooltip: 'Opciones',
                  onSelected: (value) {
                    if (value == 'editar') {
                      onEdit();
                    } else if (value == 'eliminar') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    if (operativo.canEdit)
                      const PopupMenuItem<String>(
                        value: 'editar',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                        ),
                      ),
                    if (operativo.canDelete)
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
                ),
            ],
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
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

class _StatusPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2563EB), size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(color: Colors.grey.shade700)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}
