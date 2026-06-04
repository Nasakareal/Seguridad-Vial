import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/administrative_access_service.dart';
import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../login_screen.dart';

class SettingsHomeScreen extends StatefulWidget {
  const SettingsHomeScreen({super.key});

  @override
  State<SettingsHomeScreen> createState() => _SettingsHomeScreenState();
}

class _SettingsHomeScreenState extends State<SettingsHomeScreen> {
  late Future<_SettingsAccess> _accessFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _accessFuture = _loadAccess();
  }

  Future<_SettingsAccess> _loadAccess() async {
    try {
      await AuthService.refreshCurrentUserAccess();
    } catch (_) {}

    final access = await AdministrativeAccessService.loadAccess();

    return _SettingsAccess(
      canSeeUsers: access.canSeeUsers,
      canSeePersonal: access.canSeePersonal,
      canSeeSiniestrosStats: access.canSeeSiniestrosStats,
      canSeeActividadesStats: access.canSeeActividadesStats,
      canSeeDelegacionesStats: access.canSeeDelegacionesStats,
      canSeeVialidadesStats: access.canSeeVialidadesStats,
    );
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

  void _goTo(String route) {
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Configuración'),
        actions: [const AccountMenuAction()],
      ),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: FutureBuilder<_SettingsAccess>(
          future: _accessFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final access = snapshot.data!;
            final tiles = <Widget>[
              if (access.canSeeUsers)
                _SettingsTile(
                  icon: Icons.people_outline,
                  title: 'Usuarios',
                  subtitle: 'Usuarios del sistema, roles y asignaciones',
                  onTap: () => _goTo(AppRoutes.users),
                ),
              if (access.canSeePersonal)
                _SettingsTile(
                  icon: Icons.badge_outlined,
                  title: 'Personal',
                  subtitle: 'Expedientes e incidencias del personal',
                  onTap: () => _goTo(AppRoutes.settingsPersonal),
                ),
              if (access.canSeeSiniestrosStats)
                _SettingsTile(
                  icon: Icons.car_crash_outlined,
                  title: 'Estadísticas de siniestros',
                  subtitle: 'Indicadores globales, series y hechos filtrados',
                  onTap: () => _goTo(AppRoutes.estadisticasGlobales),
                ),
              if (access.canSeeActividadesStats)
                _SettingsTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Estadísticas de actividades',
                  subtitle: 'Indicadores, capturas y filtros operativos',
                  onTap: () => _goTo(AppRoutes.estadisticasActividades),
                ),
              if (access.canSeeDelegacionesStats)
                _SettingsTile(
                  icon: Icons.fact_check_outlined,
                  title: 'Estadísticas de delegaciones',
                  subtitle: 'Conteos, alertas y regionales del corte',
                  onTap: () => _goTo(AppRoutes.delegacionesExcelRevision),
                ),
              if (access.canSeeVialidadesStats)
                _SettingsTile(
                  icon: Icons.traffic_outlined,
                  title: 'Estadísticas de vialidades',
                  subtitle: 'Resumen diario de Vialidades Urbanas',
                  onTap: () => _goTo(AppRoutes.estadisticasVialidades),
                ),
            ];

            if (tiles.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No tienes configuraciones disponibles.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuraciones',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Administración del sistema',
                        style: TextStyle(
                          color: Color(0xFFDCE3F0),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...tiles,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsAccess {
  final bool canSeeUsers;
  final bool canSeePersonal;
  final bool canSeeSiniestrosStats;
  final bool canSeeActividadesStats;
  final bool canSeeDelegacionesStats;
  final bool canSeeVialidadesStats;

  const _SettingsAccess({
    required this.canSeeUsers,
    required this.canSeePersonal,
    required this.canSeeSiniestrosStats,
    required this.canSeeActividadesStats,
    required this.canSeeDelegacionesStats,
    required this.canSeeVialidadesStats,
  });
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withValues(alpha: .12),
          child: Icon(icon, color: Colors.blue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
