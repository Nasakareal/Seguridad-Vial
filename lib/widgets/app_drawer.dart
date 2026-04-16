import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../services/auth_service.dart';
import '../services/home_resolver_service.dart';

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
  static const String permPuestasDisposicion = 'ver puestas a disposicion';
  static const String permHechos = 'ver hechos';
  static const String permOperativosCarreteras = 'ver operativos carreteras';
  static const String permOperativosVialidades = 'ver operativos vialidades';
  static const String permActividades = 'ver actividades';
  static const String permGruas = 'ver gruas';
  static const String permMapa = 'ver mapa';
  static const String permSustento = 'ver sustento legal';

  Future<void> _nav(
    BuildContext context,
    String route, {
    String? requiredPerm,
    int? requiredUnitId,
    Object? arguments,
  }) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final current = ModalRoute.of(context)?.settings.name;

    Navigator.pop(context);

    if (requiredPerm != null && requiredPerm.trim().isNotEmpty) {
      var ok = await AuthService.can(requiredPerm);
      if (!ok) {
        await AuthService.refreshCurrentUserAccess();
        ok = await AuthService.can(requiredPerm);
      }

      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No tienes permiso para acceder.')),
        );
        return;
      }
    }

    if (requiredUnitId != null) {
      var hasUnitAccess = requiredUnitId == 5
          ? await AuthService.isVialidadesUrbanasUser()
          : (await AuthService.getUnidadId()) == requiredUnitId;
      if (!hasUnitAccess) {
        await AuthService.refreshCurrentUserAccess();
        hasUnitAccess = requiredUnitId == 5
            ? await AuthService.isVialidadesUrbanasUser()
            : (await AuthService.getUnidadId()) == requiredUnitId;
      }

      if (!hasUnitAccess) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No tienes acceso a este modulo.')),
        );
        return;
      }
    }

    if (current == route) return;

    if (route == AppRoutes.home) {
      final agenteUpecHomeAvailable =
          await HomeResolverService.isAgenteUpecHomeAvailable();
      final peritoHomeAvailable =
          await HomeResolverService.isPeritoHomeAvailable();
      final homeRoute = agenteUpecHomeAvailable
          ? AppRoutes.homeAgenteUpec
          : (peritoHomeAvailable ? AppRoutes.homePerito : AppRoutes.home);
      navigator.pushNamedAndRemoveUntil(homeRoute, (_) => false);
      return;
    }

    navigator.pushNamed(route, arguments: arguments);
  }

  bool _allowed(Set<String> perms, String? requiredPerm) {
    if (requiredPerm == null || requiredPerm.trim().isEmpty) return true;
    return perms.contains(requiredPerm.trim().toLowerCase());
  }

  Future<_DrawerAccess> _loadAccess() async {
    var permissions = await AuthService.getPermissions();
    var unidadId = await AuthService.getUnidadId();
    var canSeeVialidadesUrbanas = await AuthService.isVialidadesUrbanasUser();
    var isSuperadmin = await AuthService.isSuperadmin();

    if (!canSeeVialidadesUrbanas || permissions.isEmpty) {
      await AuthService.refreshCurrentUserAccess();
      permissions = await AuthService.getPermissions();
      unidadId = await AuthService.getUnidadId();
      canSeeVialidadesUrbanas = await AuthService.isVialidadesUrbanasUser();
      isSuperadmin = await AuthService.isSuperadmin();
    }

    return _DrawerAccess(
      perms: permissions.map((e) => e.trim().toLowerCase()).toSet(),
      unidadId: unidadId,
      canSeeVialidadesUrbanas: canSeeVialidadesUrbanas,
      isSuperadmin: isSuperadmin,
    );
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
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .9),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                Text(
                  'El control de ubicación lo realiza el mapa.',
                  style: TextStyle(color: Colors.white.withValues(alpha: .85)),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<_DrawerAccess>(
              future: _loadAccess(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final perms = snap.data?.perms ?? <String>{};
                final canSeeDispositivos =
                    _allowed(perms, permOperativosCarreteras) ||
                    perms.contains('crear operativos carreteras') ||
                    perms.contains('editar operativos carreteras') ||
                    perms.contains('eliminar operativos carreteras');
                final canSeeVialidadesUrbanas =
                    snap.data?.canSeeVialidadesUrbanas ?? false;
                final unidadId = snap.data?.unidadId;
                final isSuperadmin = snap.data?.isSuperadmin ?? false;
                final canSeePuestas =
                    _allowed(perms, permPuestasDisposicion) ||
                    isSuperadmin ||
                    unidadId != null;
                final canSeeDictamenes =
                    isSuperadmin ||
                    (_allowed(perms, permDictamenes) && unidadId == 1);

                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _DrawerItem(
                      icon: Icons.home,
                      label: 'Inicio',
                      onTap: () => _nav(context, AppRoutes.home),
                    ),
                    const Divider(height: 24),

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

                    if (canSeePuestas || canSeeDictamenes)
                      _DrawerGroup(
                        icon: Icons.gavel,
                        label: 'Puestas a disposición',
                        children: [
                          if (canSeePuestas)
                            _DrawerSubItem(
                              icon: Icons.folder_open,
                              label: 'Listado de puestas',
                              onTap: () =>
                                  _nav(context, AppRoutes.puestasDisposicion),
                            ),
                          if (canSeePuestas)
                            _DrawerSubItem(
                              icon: Icons.add_circle_outline,
                              label: 'Crear puesta',
                              onTap: () => _nav(
                                context,
                                AppRoutes.puestasDisposicionCreate,
                              ),
                            ),
                          if (canSeeDictamenes)
                            _DrawerSubItem(
                              icon: Icons.description,
                              label: 'Listado de dictámenes',
                              onTap: () => _nav(
                                context,
                                AppRoutes.dictamenes,
                                requiredPerm: permDictamenes,
                              ),
                            ),
                        ],
                      ),

                    const Divider(height: 24),

                    if (_allowed(perms, permHechos))
                      _DrawerGroup(
                        icon: Icons.directions_car,
                        label: 'Hechos',
                        children: [
                          _DrawerSubItem(
                            icon: Icons.list_alt,
                            label: 'Listado de hechos',
                            onTap: () => _nav(
                              context,
                              AppRoutes.accidentes,
                              requiredPerm: permHechos,
                            ),
                          ),
                          _DrawerSubItem(
                            icon: Icons.assignment_late,
                            label: 'Cortes pendientes',
                            onTap: () => _nav(
                              context,
                              AppRoutes.pendientesCortes,
                              requiredPerm: permHechos,
                            ),
                          ),
                        ],
                      ),

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

                    if (canSeeDispositivos)
                      _DrawerGroup(
                        icon: Icons.add_road,
                        label: 'Dispositivos',
                        children: [
                          _DrawerSubItem(
                            icon: Icons.list_alt,
                            label: 'Listado',
                            onTap: () => _nav(context, AppRoutes.dispositivos),
                          ),
                        ],
                      ),

                    if (canSeeVialidadesUrbanas)
                      _DrawerGroup(
                        icon: Icons.add_road,
                        label: 'Vialidades Urbanas',
                        children: [
                          _DrawerSubItem(
                            icon: Icons.list_alt,
                            label: 'Dispositivos',
                            onTap: () => _nav(
                              context,
                              AppRoutes.vialidadesUrbanas,
                              requiredUnitId: 5,
                            ),
                          ),
                        ],
                      ),

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

                    if (_allowed(perms, permMapa))
                      _DrawerGroup(
                        icon: Icons.map,
                        label: 'Mapa',
                        children: [
                          _DrawerSubItem(
                            icon: Icons.local_police,
                            label: 'Mapa patrullas',
                            onTap: () => _nav(
                              context,
                              AppRoutes.mapa,
                              requiredPerm: permMapa,
                            ),
                          ),
                          _DrawerSubItem(
                            icon: Icons.warning_amber,
                            label: 'Mapa incidencias',
                            onTap: () => _nav(
                              context,
                              AppRoutes.mapaIncidencias,
                              requiredPerm: permMapa,
                            ),
                          ),
                        ],
                      ),

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

class _DrawerAccess {
  final Set<String> perms;
  final int? unidadId;
  final bool canSeeVialidadesUrbanas;
  final bool isSuperadmin;

  const _DrawerAccess({
    required this.perms,
    required this.unidadId,
    required this.canSeeVialidadesUrbanas,
    required this.isSuperadmin,
  });
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

class _DrawerSubItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerSubItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 56, right: 16),
      leading: Icon(icon, size: 20),
      title: Text(label),
      onTap: onTap,
    );
  }
}

class _DrawerGroup extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Widget> children;

  const _DrawerGroup({
    required this.icon,
    required this.label,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(label),
        children: children,
      ),
    );
  }
}
