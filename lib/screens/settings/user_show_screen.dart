import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/users_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/superadmin_guard.dart';
import '../login_screen.dart';

class UserShowScreen extends StatefulWidget {
  const UserShowScreen({super.key});

  @override
  State<UserShowScreen> createState() => _UserShowScreenState();
}

class _UserShowScreenState extends State<UserShowScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _user;

  int? _idFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final raw = args['user_id'] ?? args['id'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '');
    }
    if (args is int) return args;
    return int.tryParse(args?.toString() ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_user == null && _loading) {
      _load();
    }
  }

  Future<void> _load() async {
    final id = _idFromArgs();
    if (id == null || id <= 0) {
      setState(() {
        _loading = false;
        _error = 'Falta user_id.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await UsersService.show(id);
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'No se pudo cargar el usuario.\n${UsersService.cleanExceptionMessage(e)}';
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

  Future<void> _edit() async {
    final user = _user;
    final id = _int(user?['id']);
    if (id <= 0) return;

    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.usersEdit,
      arguments: {'user_id': id},
    );

    if (changed == true && mounted) {
      await _load();
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
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

  String _extraUnidades(dynamic raw) {
    if (raw is! List || raw.isEmpty) return 'Sin unidades extra';

    final names = raw
        .whereType<Map>()
        .map((item) => _nestedName(item, ''))
        .where((name) => name.isNotEmpty)
        .toList();

    return names.isEmpty ? 'Sin unidades extra' : names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final name = _text(user?['name'], 'Usuario');

    return SuperadminGuard(
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.blue,
          title: const Text('Detalle de usuario'),
          actions: [
            IconButton(
              tooltip: 'Editar',
              onPressed: user == null ? null : _edit,
              icon: const Icon(Icons.edit),
            ),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _card(
                    title: 'Error',
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  )
                else if (user == null)
                  const Center(child: Text('Sin datos.'))
                else ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white.withValues(alpha: .14),
                          child: Text(
                            _initials(name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _text(user['email']),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .8),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _card(
                    title: 'Datos principales',
                    child: Column(
                      children: [
                        _row('Nombre', name),
                        _row('Correo', _text(user['email'])),
                        _row('Telefono', _text(user['telefono'])),
                        _row('Area', _text(user['area'])),
                        _row('Estado', _text(user['estado'])),
                        _row('Rol', UsersService.roleScopedLabel(user['role'])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _card(
                    title: 'Asignacion',
                    child: Column(
                      children: [
                        _row(
                          'Unidad',
                          _nestedName(user['unidad'], 'Sin unidad'),
                        ),
                        _row('Turno', _nestedName(user['turno'])),
                        _row('Patrulla', _nestedName(user['patrulla'])),
                        _row('Delegacion', _nestedName(user['delegacion'])),
                        _row('Destacamento', _nestedName(user['destacamento'])),
                        _row(
                          'Unidades extra',
                          _extraUnidades(user['unidades']),
                        ),
                        _row(
                          'Ubicacion',
                          user['compartir_ubicacion'] == true
                              ? 'Compartida'
                              : 'No compartida',
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
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
