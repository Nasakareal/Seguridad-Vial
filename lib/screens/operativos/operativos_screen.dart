import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_drawer.dart';
import '../conduce_legalidad/conduce_legalidad_module.dart';
import '../login_screen.dart';

class OperativosScreen extends StatefulWidget {
  const OperativosScreen({super.key});

  @override
  State<OperativosScreen> createState() => _OperativosScreenState();
}

class _OperativosScreenState extends State<OperativosScreen> {
  late Future<_OperativosAccess> _accessFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _accessFuture = _loadAccess();
  }

  Future<_OperativosAccess> _loadAccess() async {
    try {
      await AuthService.refreshCurrentUserAccess();
    } catch (_) {}

    return _OperativosAccess(
      canSeeConduceLegalidad: await AuthService.canAccessConduceLegalidad(),
    );
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

  Future<void> _refresh() async {
    final future = _loadAccess();
    setState(() => _accessFuture = future);
    await future;
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.assignment_turned_in_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Operativos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selecciona el operativo que quieres consultar o alimentar.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .82),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moduleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }

  Widget _body(_OperativosAccess access) {
    final modules = <Widget>[
      if (access.canSeeConduceLegalidad)
        _moduleCard(
          icon: ConduceLegalidadModule.conduceLegalidad.icon,
          title: ConduceLegalidadModule.conduceLegalidad.title,
          subtitle: ConduceLegalidadModule.conduceLegalidad.listSubtitle,
          route: AppRoutes.conduceLegalidad,
        ),
      if (access.canSeeConduceLegalidad)
        _moduleCard(
          icon: ConduceLegalidadModule.alcoholimetria.icon,
          title: ConduceLegalidadModule.alcoholimetria.title,
          subtitle: ConduceLegalidadModule.alcoholimetria.listSubtitle,
          route: AppRoutes.alcoholimetria,
        ),
    ];

    if (modules.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 34),
        child: Text(
          'No tienes operativos disponibles con tus permisos actuales.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(children: modules);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Operativos'),
        actions: const [AccountMenuAction()],
      ),
      drawer: const AppDrawer(trackingOn: false),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_OperativosAccess>(
          future: _accessFuture,
          builder: (context, snapshot) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _header(),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _body(snapshot.data ?? const _OperativosAccess.empty()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OperativosAccess {
  final bool canSeeConduceLegalidad;

  const _OperativosAccess({required this.canSeeConduceLegalidad});

  const _OperativosAccess.empty() : canSeeConduceLegalidad = false;
}
