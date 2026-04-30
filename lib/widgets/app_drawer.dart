import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../services/auth_service.dart';
import '../services/home_resolver_service.dart';
import 'drawer_ui.dart';

class AppDrawer extends StatelessWidget {
  final bool trackingOn;

  const AppDrawer({super.key, required this.trackingOn});

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
      var ok =
          await AuthService.hasFullOperationalAccess() ||
          await AuthService.can(requiredPerm);
      if (!ok) {
        await AuthService.refreshCurrentUserAccess();
        ok =
            await AuthService.hasFullOperationalAccess() ||
            await AuthService.can(requiredPerm);
      }

      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No tienes permiso para acceder.')),
        );
        return;
      }
    }

    if (requiredUnitId != null) {
      var hasUnitAccess = await _hasRequiredUnitAccess(requiredUnitId);
      if (!hasUnitAccess) {
        await AuthService.refreshCurrentUserAccess();
        hasUnitAccess = await _hasRequiredUnitAccess(requiredUnitId);
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

  Future<bool> _hasRequiredUnitAccess(int requiredUnitId) async {
    if (await AuthService.hasFullOperationalAccess()) {
      return true;
    }

    if (requiredUnitId == AuthService.unidadVialidadesUrbanasId) {
      return AuthService.isVialidadesUrbanasUser();
    }
    if (requiredUnitId == AuthService.unidadProteccionCarreterasId) {
      return AuthService.isCarreterasUser();
    }

    return (await AuthService.getUnidadId()) == requiredUnitId;
  }

  bool _allowed(Set<String> perms, String? requiredPerm, {bool all = false}) {
    if (all) return true;
    if (requiredPerm == null || requiredPerm.trim().isEmpty) return true;
    return perms.contains(requiredPerm.trim().toLowerCase());
  }

  Future<_DrawerAccess> _loadAccess() async {
    try {
      await AuthService.refreshCurrentUserAccess();
    } catch (_) {}

    var permissions = await AuthService.getPermissions();
    var unidadId = await AuthService.getUnidadId();
    var canSeeCarreteras = await AuthService.isCarreterasUser();
    var canSeeVialidadesUrbanas = await AuthService.isVialidadesUrbanasUser();
    var isSuperadmin = await AuthService.isSuperadmin();
    var hasFullOperationalAccess = await AuthService.hasFullOperationalAccess();
    var canReviewCarreteras = await _canReviewCarreteras();
    var canUseConstanciasManejo = await AuthService.canUseConstanciasManejo();

    if (permissions.isEmpty) {
      await AuthService.refreshCurrentUserAccess();
      permissions = await AuthService.getPermissions();
      unidadId = await AuthService.getUnidadId();
      canSeeCarreteras = await AuthService.isCarreterasUser();
      canSeeVialidadesUrbanas = await AuthService.isVialidadesUrbanasUser();
      isSuperadmin = await AuthService.isSuperadmin();
      hasFullOperationalAccess = await AuthService.hasFullOperationalAccess();
      canReviewCarreteras = await _canReviewCarreteras();
      canUseConstanciasManejo = await AuthService.canUseConstanciasManejo();
    }

    return _DrawerAccess(
      perms: permissions.map((e) => e.trim().toLowerCase()).toSet(),
      unidadId: unidadId,
      canSeeCarreteras: canSeeCarreteras,
      canSeeVialidadesUrbanas: canSeeVialidadesUrbanas,
      isSuperadmin: isSuperadmin,
      hasFullOperationalAccess: hasFullOperationalAccess,
      canReviewCarreteras: canReviewCarreteras,
      canUseConstanciasManejo: canUseConstanciasManejo,
    );
  }

  Future<bool> _canReviewCarreteras() async {
    if (await AuthService.isSuperadmin()) return true;
    return await AuthService.hasRoleName('RT') ||
        await AuthService.hasRoleName('Encargado de Destacamento');
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF6F7FB),
      child: Column(
        children: [
          DrawerHeaderPanel(
            icon: Icons.shield_outlined,
            title: 'Seguridad Vial',
            subtitle: trackingOn
                ? 'Navegación principal con ubicación activa.'
                : 'Navegación principal del sistema.',
            helper:
                'Tu perfil, contraseña y cierre de sesión están en el menú derecho.',
            chips: <String>[
              trackingOn ? 'Ubicación activa' : 'Ubicación inactiva',
              'Menú principal',
            ],
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
                final hasFullOperationalAccess =
                    snap.data?.hasFullOperationalAccess ?? false;
                final canSeeDispositivos =
                    ((snap.data?.canSeeCarreteras ?? false) ||
                        hasFullOperationalAccess) &&
                    (_allowed(perms, permOperativosCarreteras) ||
                        perms.contains('crear operativos carreteras') ||
                        perms.contains('editar operativos carreteras') ||
                        perms.contains('eliminar operativos carreteras') ||
                        hasFullOperationalAccess);
                final canReviewDispositivos =
                    canSeeDispositivos &&
                    (snap.data?.canReviewCarreteras ?? false) &&
                    (perms.contains('editar operativos carreteras') ||
                        hasFullOperationalAccess);
                final canSeeVialidadesUrbanas =
                    (snap.data?.canSeeVialidadesUrbanas ?? false) ||
                    hasFullOperationalAccess;
                final unidadId = snap.data?.unidadId;
                final canSeeCulturaVial =
                    hasFullOperationalAccess ||
                    unidadId == AuthService.unidadCulturaVialId;
                final isSuperadmin = snap.data?.isSuperadmin ?? false;
                final canSeeAllButtons = hasFullOperationalAccess;
                final canSeePuestas =
                    _allowed(
                      perms,
                      permPuestasDisposicion,
                      all: canSeeAllButtons,
                    ) ||
                    isSuperadmin ||
                    unidadId != null;
                final canSeeDictamenes =
                    canSeeAllButtons ||
                    (_allowed(perms, permDictamenes) && unidadId == 1);
                final canSeeConstanciasManejo =
                    snap.data?.canUseConstanciasManejo ?? false;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  children: [
                    const DrawerSectionLabel(label: 'General'),
                    _DrawerItem(
                      icon: Icons.home,
                      label: 'Inicio',
                      subtitle: 'Volver al panel principal',
                      onTap: () => _nav(context, AppRoutes.home),
                    ),

                    if (_allowed(perms, permBusqueda, all: canSeeAllButtons))
                      _DrawerItem(
                        icon: Icons.search,
                        label: 'Búsqueda',
                        subtitle: 'Localizar hechos y registros',
                        onTap: () => _nav(
                          context,
                          AppRoutes.hechosBuscar,
                          requiredPerm: permBusqueda,
                        ),
                      ),

                    if (_allowed(
                      perms,
                      permEstadisticas,
                      all: canSeeAllButtons,
                    ))
                      _DrawerItem(
                        icon: Icons.insights,
                        label: 'Estadísticas',
                        subtitle: 'Consultar reportes globales',
                        onTap: () => _nav(
                          context,
                          AppRoutes.estadisticasGlobales,
                          requiredPerm: permEstadisticas,
                        ),
                      ),

                    const SizedBox(height: 12),
                    if (canSeePuestas || canSeeDictamenes) ...[
                      const DrawerSectionLabel(label: 'Operación'),
                      _DrawerGroup(
                        icon: Icons.gavel,
                        label: 'Puestas a disposición',
                        subtitle: 'Puestas, creación y dictámenes disponibles',
                        children: [
                          if (canSeePuestas)
                            _DrawerSubItem(
                              icon: Icons.folder_open,
                              label: 'Listado de puestas',
                              subtitle: 'Consultar registros capturados',
                              onTap: () =>
                                  _nav(context, AppRoutes.puestasDisposicion),
                            ),
                          if (canSeePuestas)
                            _DrawerSubItem(
                              icon: Icons.add_circle_outline,
                              label: 'Crear puesta',
                              subtitle: 'Registrar una nueva puesta',
                              onTap: () => _nav(
                                context,
                                AppRoutes.puestasDisposicionCreate,
                              ),
                            ),
                          if (canSeeDictamenes)
                            _DrawerSubItem(
                              icon: Icons.description,
                              label: 'Listado de dictámenes',
                              subtitle: 'Explorar dictámenes existentes',
                              onTap: () => _nav(
                                context,
                                AppRoutes.dictamenes,
                                requiredPerm: permDictamenes,
                              ),
                            ),
                        ],
                      ),
                    ],

                    if (_allowed(perms, permHechos, all: canSeeAllButtons))
                      _DrawerGroup(
                        icon: Icons.directions_car,
                        label: 'Hechos',
                        subtitle: 'Consulta, seguimiento y pendientes',
                        children: [
                          _DrawerSubItem(
                            icon: Icons.list_alt,
                            label: 'Listado de hechos',
                            subtitle: 'Ver hechos capturados',
                            onTap: () => _nav(
                              context,
                              AppRoutes.accidentes,
                              requiredPerm: permHechos,
                            ),
                          ),
                          _DrawerSubItem(
                            icon: Icons.assignment_late,
                            label: 'Cortes pendientes',
                            subtitle: 'Revisar pendientes por corte',
                            onTap: () => _nav(
                              context,
                              AppRoutes.pendientesCortes,
                              requiredPerm: permHechos,
                            ),
                          ),
                        ],
                      ),

                    if (_allowed(perms, permActividades, all: canSeeAllButtons))
                      _DrawerItem(
                        icon: Icons.photo_library,
                        label: 'Actividades',
                        subtitle: 'Operativos y actividades del día',
                        onTap: () => _nav(
                          context,
                          AppRoutes.actividades,
                          requiredPerm: permActividades,
                        ),
                      ),

                    if (canSeeConstanciasManejo)
                      _DrawerItem(
                        icon: Icons.badge,
                        label: 'Constancias de manejo',
                        subtitle: 'Generar lotes, imprimir y activar',
                        onTap: () => _nav(context, AppRoutes.constanciasManejo),
                      ),

                    if (canSeeCulturaVial)
                      _DrawerItem(
                        icon: Icons.sports_esports,
                        label: 'Cultura Vial',
                        subtitle: 'Salas, QR y minijuegos',
                        onTap: () => _nav(
                          context,
                          AppRoutes.culturaVial,
                          requiredUnitId: AuthService.unidadCulturaVialId,
                        ),
                      ),

                    if (canSeeDispositivos)
                      _DrawerGroup(
                        icon: Icons.add_road,
                        label: 'Dispositivos',
                        subtitle: 'Carreteras y revisión operativa',
                        children: [
                          _DrawerSubItem(
                            icon: Icons.list_alt,
                            label: 'Listado',
                            subtitle: 'Ver dispositivos registrados',
                            onTap: () => _nav(
                              context,
                              AppRoutes.dispositivos,
                              requiredUnitId:
                                  AuthService.unidadProteccionCarreterasId,
                            ),
                          ),
                          if (canReviewDispositivos)
                            _DrawerSubItem(
                              icon: Icons.fact_check_outlined,
                              label: 'Pendientes de revisión',
                              subtitle: 'Aprobar o rechazar capturas',
                              onTap: () => _nav(
                                context,
                                AppRoutes.dispositivosRevision,
                                requiredUnitId:
                                    AuthService.unidadProteccionCarreterasId,
                              ),
                            ),
                        ],
                      ),

                    if (canSeeVialidadesUrbanas)
                      _DrawerGroup(
                        icon: Icons.add_road,
                        label: 'Vialidades Urbanas',
                        subtitle: 'Operación y detalles urbanos',
                        children: [
                          _DrawerSubItem(
                            icon: Icons.list_alt,
                            label: 'Dispositivos',
                            subtitle: 'Ver capturas y detalles',
                            onTap: () => _nav(
                              context,
                              AppRoutes.vialidadesUrbanas,
                              requiredUnitId: 5,
                            ),
                          ),
                        ],
                      ),

                    if (_allowed(perms, permGruas, all: canSeeAllButtons))
                      _DrawerItem(
                        icon: Icons.local_shipping,
                        label: 'Grúas',
                        subtitle: 'Seguimiento de grúas y movimientos',
                        onTap: () => _nav(
                          context,
                          AppRoutes.gruas,
                          requiredPerm: permGruas,
                        ),
                      ),

                    const SizedBox(height: 12),
                    const DrawerSectionLabel(label: 'Consulta'),

                    if (_allowed(perms, permMapa, all: canSeeAllButtons))
                      _DrawerGroup(
                        icon: Icons.map,
                        label: 'Mapa',
                        subtitle: 'Ubicación de patrullas e incidencias',
                        children: [
                          _DrawerSubItem(
                            icon: Icons.local_police,
                            label: 'Mapa patrullas',
                            subtitle: 'Ubicar personal y patrullas',
                            onTap: () => _nav(
                              context,
                              AppRoutes.mapa,
                              requiredPerm: permMapa,
                            ),
                          ),
                          _DrawerSubItem(
                            icon: Icons.warning_amber,
                            label: 'Mapa incidencias',
                            subtitle: 'Visualizar incidencias activas',
                            onTap: () => _nav(
                              context,
                              AppRoutes.mapaIncidencias,
                              requiredPerm: permMapa,
                            ),
                          ),
                        ],
                      ),

                    if (_allowed(perms, permSustento, all: canSeeAllButtons))
                      _DrawerItem(
                        icon: Icons.gavel,
                        label: 'Sustento Legal',
                        subtitle: 'Consultar base normativa',
                        onTap: () => _nav(
                          context,
                          AppRoutes.sustentoLegal,
                          requiredPerm: permSustento,
                        ),
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
  final bool canSeeCarreteras;
  final bool canSeeVialidadesUrbanas;
  final bool isSuperadmin;
  final bool hasFullOperationalAccess;
  final bool canReviewCarreteras;
  final bool canUseConstanciasManejo;

  const _DrawerAccess({
    required this.perms,
    required this.unidadId,
    required this.canSeeCarreteras,
    required this.canSeeVialidadesUrbanas,
    required this.isSuperadmin,
    required this.hasFullOperationalAccess,
    required this.canReviewCarreteras,
    required this.canUseConstanciasManejo,
  });
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DrawerSurface(
        child: DrawerActionTile(
          icon: icon,
          title: label,
          subtitle: subtitle,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _DrawerSubItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _DrawerSubItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DrawerActionTile(
      icon: icon,
      title: label,
      subtitle: subtitle,
      compact: true,
      onTap: onTap,
    );
  }
}

class _DrawerGroup extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final List<Widget> children;

  const _DrawerGroup({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: DrawerSurface(
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.more_horiz, color: Colors.transparent),
            ),
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if ((subtitle ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            children: _withDividers(children),
          ),
        ),
      ),
    );
  }
}

List<Widget> _withDividers(List<Widget> children) {
  if (children.isEmpty) {
    return const <Widget>[];
  }

  final items = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) {
      items.add(Divider(height: 1, color: Colors.grey.shade200, indent: 56));
    }
    items.add(children[i]);
  }

  return items;
}
