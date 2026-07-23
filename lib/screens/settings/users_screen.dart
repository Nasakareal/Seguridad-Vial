import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/users_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/permission_guard.dart';
import '../login_screen.dart';

class SettingsUsersScreen extends StatefulWidget {
  const SettingsUsersScreen({super.key});

  @override
  State<SettingsUsersScreen> createState() => _SettingsUsersScreenState();
}

class _SettingsUsersScreenState extends State<SettingsUsersScreen> {
  final _qCtrl = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _canCreate = false;
  bool _canEdit = false;
  String? _error;
  int? _unidadFilterId;
  UsersMeta _meta = const UsersMeta.empty();
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

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
      final meta = await UsersService.meta();
      final isSuperadmin = await AuthService.isSuperadmin();
      final canCreate = isSuperadmin || await AuthService.can('crear usuarios');
      final canEdit = isSuperadmin || await AuthService.can('editar usuarios');
      final page = await UsersService.index(
        q: _qCtrl.text,
        unidadId: _unidadFilterId,
        perPage: 80,
      );
      if (!mounted) return;
      setState(() {
        _meta = meta;
        _canCreate = canCreate;
        _canEdit = canEdit;
        _items = page.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'No se pudieron cargar los usuarios.\n${UsersService.cleanExceptionMessage(e)}';
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

  Future<void> _goCreate() async {
    final changed = await Navigator.pushNamed(context, AppRoutes.usersCreate);
    if (changed == true && mounted) {
      await _load();
    }
  }

  Future<void> _goShow(Map<String, dynamic> item) async {
    final id = _int(item['id']);
    if (id <= 0) return;

    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.usersShow,
      arguments: {'user_id': id},
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  Future<void> _goEdit(Map<String, dynamic> item) async {
    final id = _int(item['id']);
    if (id <= 0) return;

    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.usersEdit,
      arguments: {'user_id': id},
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  String _text(dynamic value, [String fallback = '-']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _nestedName(dynamic raw, [String fallback = '-']) {
    if (raw is Map) {
      return _text(
        raw['nombre'] ?? raw['name'] ?? raw['numero_economico'],
        fallback,
      );
    }
    return fallback;
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permission: 'ver usuarios',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.blue,
          title: const Text('Usuarios'),
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
        floatingActionButton: _canCreate
            ? FloatingActionButton.extended(
                onPressed: _goCreate,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Nuevo'),
              )
            : null,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _qCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(),
                    decoration: InputDecoration(
                      hintText: 'Buscar usuario',
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
                ),
                if (_meta.unidades.length > 1) ...[
                  const SizedBox(height: 12),
                  _unidadDropdown(),
                ],
                const SizedBox(height: 14),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _MessageCard(
                    icon: Icons.error_outline,
                    title: 'Sin conexion con usuarios',
                    message: _error!,
                    color: Colors.red,
                  )
                else if (_items.isEmpty)
                  const _MessageCard(
                    icon: Icons.people_outline,
                    title: 'Sin usuarios',
                    message: 'No hay usuarios para mostrar con este filtro.',
                    color: Colors.blue,
                  )
                else
                  ..._items.map((item) {
                    final role = item['role'];
                    final unidad = item['unidad'];
                    final estado = _text(item['estado'], 'Sin estado');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: .12),
                          child: Text(
                            _initials(_text(item['name'], 'U')),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        title: Text(
                          _text(item['name'], 'Usuario'),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${_text(item['email'])}\n${UsersService.roleScopedLabel(role)} · ${_nestedName(unidad, 'Sin unidad')} · $estado',
                          ),
                        ),
                        isThreeLine: true,
                        onTap: () => _goShow(item),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'show') {
                              _goShow(item);
                            }
                            if (value == 'edit') {
                              _goEdit(item);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'show',
                              child: Text('Ver'),
                            ),
                            if (_canEdit)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _unidadDropdown() {
    final ids = _meta.unidades.map((item) => item.id).toSet();
    final safeValue = ids.contains(_unidadFilterId) ? _unidadFilterId : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonFormField<int?>(
        value: safeValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Unidad',
          prefixIcon: const Icon(Icons.apartment),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('Todas las unidades'),
          ),
          ..._meta.unidades.map(
            (unidad) => DropdownMenuItem<int?>(
              value: unidad.id,
              child: Text(unidad.nombre, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (value) async {
          setState(() => _unidadFilterId = value);
          await _load();
        },
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final MaterialColor color;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String raw) {
  final parts = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) return 'U';
  if (parts.length == 1) {
    final text = parts.first;
    return text.substring(0, text.length >= 2 ? 2 : 1).toUpperCase();
  }

  return (parts.first[0] + parts.last[0]).toUpperCase();
}
