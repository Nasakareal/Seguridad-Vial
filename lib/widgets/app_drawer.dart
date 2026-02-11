import 'package:flutter/material.dart';

import '../main.dart' show AppRoutes;
import '../services/auth_service.dart';

class AppDrawer extends StatelessWidget {
  final bool trackingOn;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.trackingOn,
    required this.onLogout,
  });

  static const String permBusqueda = 'ver busqueda';
  static const String permEstadisticas = 'ver estadisticas';
  static const String permDictamenes = 'ver dictamenes';
  static const String permHechos = 'ver hechos';
  static const String permActividades = 'ver actividades';
  static const String permGruas = 'ver gruas';
  static const String permMapa = 'ver mapa';
  static const String permSustento = 'ver sustento legal';

  Future<void> _nav(
    BuildContext context,
    String route, {
    String? requiredPerm,
  }) async {
    // Cierra el drawer
    Navigator.pop(context);

    // Si requiere permiso, valida
    if (requiredPerm != null && requiredPerm.trim().isNotEmpty) {
      final ok = await AuthService.can(requiredPerm);
      if (!ok) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tienes permiso para acceder.')),
        );
        return;
      }
    }

    // Evita apilar mil pantallas si ya estás en la ruta
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;

    // Para Home conviene "volver" limpio
    if (route == AppRoutes.home) {
      Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
      return;
    }

    Navigator.pushNamed(context, route);
  }

  bool _allowed(Set<String> perms, String? requiredPerm) {
    if (requiredPerm == null || requiredPerm.trim().isEmpty) return true;
    return perms.contains(requiredPerm.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = trackingOn ? Colors.green : Colors.transparent;

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 46, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield, color: Colors.white, size: 44),
                const SizedBox(height: 10),
                const Text(
                  'Seguridad Vial',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),

                // ✅ No mostrar "Ubicación NO ACTIVA"
                if (trackingOn)
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ubicación ACTIVA',
                        style: TextStyle(color: Colors.white.withOpacity(.9)),
                      ),
                    ],
                  ),

                const SizedBox(height: 10),
                Text(
                  'El control de ubicación lo realiza el mapa.',
                  style: TextStyle(color: Colors.white.withOpacity(.85)),
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<String>>(
              future: AuthService.getPermissions(),
              builder: (context, snap) {
                final perms = (snap.data ?? <String>[])
                    .map((e) => e.trim().toLowerCase())
                    .toSet();

                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ✅ HOME (siempre visible)
                    _DrawerItem(
                      icon: Icons.home,
                      label: 'Inicio',
                      onTap: () => _nav(context, AppRoutes.home),
                    ),

                    const Divider(height: 24),

                    // ✅ BÚSQUEDA
                    if (_allowed(perms, permBusqueda))
                      _DrawerItem(
                        icon: Icons.search,
                        label: 'Búsqueda',
                        onTap: () => _nav(
                          context,
                          AppRoutes.hechosBuscar,
                          requiredPerm: permBusqueda,
                        ),
                      ),

                    // ✅ ESTADÍSTICAS
                    if (_allowed(perms, permEstadisticas))
                      _DrawerItem(
                        icon: Icons.insights,
                        label: 'Estadísticas',
                        onTap: () => _nav(
                          context,
                          AppRoutes.estadisticasGlobales,
                          requiredPerm: permEstadisticas,
                        ),
                      ),

                    // ✅ DICTÁMENES
                    if (_allowed(perms, permDictamenes))
                      _DrawerItem(
                        icon: Icons.description,
                        label: 'Dictámenes',
                        onTap: () => _nav(
                          context,
                          AppRoutes.dictamenes,
                          requiredPerm: permDictamenes,
                        ),
                      ),

                    const Divider(height: 24),

                    // ✅ HECHOS / ACCIDENTES
                    if (_allowed(perms, permHechos))
                      _DrawerItem(
                        icon: Icons.directions_car,
                        label: 'Hechos / Accidentes',
                        onTap: () => _nav(
                          context,
                          AppRoutes.accidentes,
                          requiredPerm: permHechos,
                        ),
                      ),

                    // ✅ ACTIVIDADES
                    if (_allowed(perms, permActividades))
                      _DrawerItem(
                        icon: Icons.photo_library,
                        label: 'Actividades',
                        onTap: () => _nav(
                          context,
                          AppRoutes.actividades,
                          requiredPerm: permActividades,
                        ),
                      ),

                    // ✅ GRÚAS
                    if (_allowed(perms, permGruas))
                      _DrawerItem(
                        icon: Icons.local_shipping,
                        label: 'Grúas',
                        onTap: () => _nav(
                          context,
                          AppRoutes.gruas,
                          requiredPerm: permGruas,
                        ),
                      ),

                    const Divider(height: 24),

                    // ✅ MAPA
                    if (_allowed(perms, permMapa))
                      _DrawerItem(
                        icon: Icons.map,
                        label: 'Mapa de Patrullas',
                        onTap: () => _nav(
                          context,
                          AppRoutes.mapa,
                          requiredPerm: permMapa,
                        ),
                      ),

                    // ✅ SUSTENTO LEGAL
                    if (_allowed(perms, permSustento))
                      _DrawerItem(
                        icon: Icons.gavel,
                        label: 'Sustento Legal',
                        onTap: () => _nav(
                          context,
                          AppRoutes.sustentoLegal,
                          requiredPerm: permSustento,
                        ),
                      ),

                    const Divider(height: 24),

                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text(
                        'Cerrar sesión',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: onLogout,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(label), onTap: onTap);
  }
}
