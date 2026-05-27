import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../models/red_apoyo.dart';
import '../../services/auth_service.dart';
import '../../services/directorio_red_apoyo_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/permission_guard.dart';
import '../login_screen.dart';

class DirectorioRedApoyoScreen extends StatefulWidget {
  const DirectorioRedApoyoScreen({super.key});

  @override
  State<DirectorioRedApoyoScreen> createState() =>
      _DirectorioRedApoyoScreenState();
}

class _DirectorioRedApoyoScreenState extends State<DirectorioRedApoyoScreen> {
  final _qCtrl = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _error;
  int? _regionId;
  int? _delegacionId;
  String _nivelGobierno = '';
  String _tipoApoyo = '';
  DirectorioRedApoyoMeta _meta = const DirectorioRedApoyoMeta.empty();
  DirectorioRedApoyoPage? _page;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final meta = await DirectorioRedApoyoService.meta();
      final page = await DirectorioRedApoyoService.index(
        q: _qCtrl.text,
        regionId: _regionId,
        delegacionId: _delegacionId,
        nivelGobierno: _nivelGobierno,
        tipoApoyo: _tipoApoyo,
      );

      if (!mounted) return;
      setState(() {
        _meta = meta;
        _page = page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'No se pudo cargar la red de apoyo.\n${DirectorioRedApoyoService.cleanExceptionMessage(e)}';
      });
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

  Future<void> _openContact(RedApoyoContact item) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.directorioRedApoyoShow,
      arguments: {'red_apoyo_id': item.id},
    );
  }

  Future<void> _launchPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) {
      _showMessage('El contacto no tiene telefono.');
      return;
    }

    final opened = await launchUrl(Uri.parse('tel:$digits'));
    if (!opened) {
      _showMessage('No se pudo abrir el telefono.');
    }
  }

  Future<void> _launchWhatsApp(String url) async {
    if (url.trim().isEmpty) {
      _showMessage('El contacto no tiene WhatsApp disponible.');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showMessage('Link de WhatsApp invalido.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showMessage('No se pudo abrir WhatsApp.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _clearFilters() {
    setState(() {
      _qCtrl.clear();
      _regionId = null;
      _delegacionId = null;
      _nivelGobierno = '';
      _tipoApoyo = '';
    });
    _load().catchError((_) {});
  }

  List<_DelegacionOption> _delegacionOptions() {
    final options = <_DelegacionOption>[];
    for (final region in _meta.regiones) {
      for (final hija in region.hijas) {
        options.add(
          _DelegacionOption(
            id: hija.id,
            label: '${hija.nombre} (${region.nombre})',
          ),
        );
      }
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permission: 'ver directorio red apoyo',
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.blue,
          title: const Text('Red de apoyo'),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
            const AccountMenuAction(),
          ],
        ),
        endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _HeaderCard(total: _page?.count ?? 0),
                const SizedBox(height: 14),
                _filtersCard(),
                const SizedBox(height: 14),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 42),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _MessageCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'Sin conexion con red de apoyo',
                    message: _error!,
                    color: Colors.red,
                    actionLabel: 'Reintentar',
                    onAction: _load,
                  )
                else if ((_page?.items ?? const <RedApoyoContact>[]).isEmpty)
                  _MessageCard(
                    icon: Icons.support_agent_outlined,
                    title: 'Sin contactos',
                    message: 'No hay contactos disponibles con estos filtros.',
                    color: Colors.blue,
                    actionLabel: 'Limpiar filtros',
                    onAction: _clearFilters,
                  )
                else
                  ...(_page?.groupedByRegion ?? const <RedApoyoRegionGroup>[])
                      .map(_regionSection),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filtersCard() {
    final regionIds = _meta.regiones.map((item) => item.id).toSet();
    final safeRegionId = regionIds.contains(_regionId) ? _regionId : null;
    final delegaciones = _delegacionOptions();
    final delegacionIds = delegaciones.map((item) => item.id).toSet();
    final safeDelegacionId = delegacionIds.contains(_delegacionId)
        ? _delegacionId
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          TextField(
            controller: _qCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Buscar institucion, encargado o telefono',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Buscar',
                onPressed: _load,
                icon: const Icon(Icons.arrow_forward),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: safeRegionId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Region operativa',
              prefixIcon: const Icon(Icons.account_tree_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Todas las regiones'),
              ),
              ..._meta.regiones.map(
                (region) => DropdownMenuItem<int?>(
                  value: region.id,
                  child: Text(region.nombre, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _regionId = value;
                if (value != null) _delegacionId = null;
              });
              _load().catchError((_) {});
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: safeDelegacionId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Delegacion estatal',
              prefixIcon: const Icon(Icons.location_city_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Todas las delegaciones'),
              ),
              ...delegaciones.map(
                (item) => DropdownMenuItem<int?>(
                  value: item.id,
                  child: Text(item.label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _delegacionId = value;
                if (value != null) _regionId = null;
              });
              _load().catchError((_) {});
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _meta.nivelesGobierno.containsKey(_nivelGobierno)
                      ? _nivelGobierno
                      : '',
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Nivel',
                    prefixIcon: const Icon(Icons.public_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Todos'),
                    ),
                    ..._meta.nivelesGobierno.entries.map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _nivelGobierno = value ?? '');
                    _load().catchError((_) {});
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _meta.tiposApoyo.containsKey(_tipoApoyo)
                      ? _tipoApoyo
                      : '',
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Tipo',
                    prefixIcon: const Icon(Icons.handshake_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Todos'),
                    ),
                    ..._meta.tiposApoyo.entries.map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _tipoApoyo = value ?? '');
                    _load().catchError((_) {});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Limpiar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _regionSection(RedApoyoRegionGroup group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.region,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _CountPill(count: group.items.length),
            ],
          ),
          const SizedBox(height: 10),
          ...group.items.map(_contactCard),
        ],
      ),
    );
  }

  Widget _contactCard(RedApoyoContact item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openContact(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.handshake_outlined,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.institucion,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          [item.contacto, item.cargo]
                              .where((value) => value.trim().isNotEmpty)
                              .join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Acciones',
                    onSelected: (value) {
                      if (value == 'whatsapp') {
                        _launchWhatsApp(item.whatsapp.url);
                      }
                      if (value == 'call') {
                        _launchPhone(item.telefono);
                      }
                      if (value == 'detail') {
                        _openContact(item);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'detail',
                        child: Text('Ver detalle'),
                      ),
                      if (item.whatsapp.url.isNotEmpty)
                        const PopupMenuItem(
                          value: 'whatsapp',
                          child: Text('WhatsApp'),
                        ),
                      if (item.telefono.isNotEmpty)
                        const PopupMenuItem(
                          value: 'call',
                          child: Text('Llamar'),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.category_outlined,
                    label: item.tipoApoyoLabel,
                  ),
                  _InfoChip(
                    icon: Icons.public_outlined,
                    label: item.nivelLabel,
                  ),
                  _InfoChip(
                    icon: Icons.place_outlined,
                    label: item.municipio.isEmpty
                        ? item.territorioLabel
                        : item.municipio,
                  ),
                ],
              ),
              if (item.hasPhone) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: item.telefono.isEmpty
                            ? null
                            : () => _launchPhone(item.telefono),
                        icon: const Icon(Icons.call),
                        label: Text(
                          item.telefono.isEmpty
                              ? 'Sin telefono'
                              : item.telefono,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      tooltip: 'WhatsApp',
                      onPressed: item.whatsapp.url.isEmpty
                          ? null
                          : () => _launchWhatsApp(item.whatsapp.url),
                      icon: const Icon(Icons.chat_outlined),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int total;

  const _HeaderCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.support_agent_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Directorio red de apoyo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  total == 1
                      ? '1 contacto disponible'
                      : '$total contactos disponibles',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .82),
                    fontWeight: FontWeight.w700,
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final text = label.trim().isEmpty ? '-' : label.trim();
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 48,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.blue.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;

  const _CountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: Colors.blue.shade800,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final MaterialColor color;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color.shade700, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _DelegacionOption {
  final int id;
  final String label;

  const _DelegacionOption({required this.id, required this.label});
}
