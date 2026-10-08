import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../services/auth_service.dart';
import '../services/home_resolver_service.dart';
import '../screens/conduce_legalidad/conduce_legalidad_module.dart';
import 'drawer_ui.dart';
import 'unit_branding_watermark.dart';

class AppDrawer extends StatelessWidget {
  final bool trackingOn;

  const AppDrawer({super.key, required this.trackingOn});

  static const String permBusqueda = 'ver busqueda';
  static const String permEstadisticas = 'ver estadisticas';
  static const String permEstadisticasGlobales = 'ver estadisticas globales';
  static const String permEstadisticasActividades =
      'ver estadisticas actividades';
  static const String permDictamenes = 'ver dictamenes';
  static const String permPuestasDisposicion = 'ver puestas a disposicion';
  static const String permHechos = 'ver hechos';
  static const String permOperativosCarreteras = 'ver operativos carreteras';
  static const String permOperativosVialidades = 'ver operativos vialidades';
  static const String permActividades = 'ver actividades';
  static const String permGruas = 'ver gruas';
  static const String permMapa = 'ver mapa';
  static const String permSustento = 'ver sustento legal';
  static const String permPuntosLicencias = 'ver puntos licencias';
  static const String permConduceLegalidad = 'ver conduce legalidad';

  static bool _constanciasOnlyAllowsRoute(String route) {
    return route == AppRoutes.home ||
        route == AppRoutes.constanciasManejo ||
        route == AppRoutes.constanciasManejoScanner ||
        route == AppRoutes.constanciasManejoDetalle ||
        route == AppRoutes.actividades ||
        route == AppRoutes.actividadesCreate ||
        route == AppRoutes.actividadesShow ||
        route == AppRoutes.herramientasVelocidadFrenado ||
        route == AppRoutes.herramientasVelocidadDeformacion ||
        route == AppRoutes.herramientasRndFaltas ||
        route == AppRoutes.sustentoLegal ||
        route == AppRoutes.sustentoLegalCategoria ||
        route == AppRoutes.sustentoLegalDetalle ||
        route == AppRoutes.sustentoLegalBuscar;
  }

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

    final constanciasOnly =
        await AuthService.isEvaluadorTeoricoConstanciasOnly();
    if (constanciasOnly && !_constanciasOnlyAllowsRoute(route)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Este rol solo tiene acceso a Constancias, Actividades, Herramientas y Sustento Legal.',
          ),
        ),
      );
      return;
    }

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

    // La misma pantalla puede abrirse con el filtro de otra unidad desde los
    // submenús de Coordinación/Superadmin.
    if (current == route && arguments == null) return;

    if (route == AppRoutes.home) {
      if (constanciasOnly) {
        navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
        return;
      }

      final motociclistaHomeAvailable =
          await HomeResolverService.isMotociclistaHomeAvailable();
      final fenixHomeAvailable =
          await HomeResolverService.isFenixHomeAvailable();
      final agenteVialHomeAvailable =
          await HomeResolverService.isAgenteVialHomeAvailable();
      final agenteUpecHomeAvailable =
          await HomeResolverService.isAgenteUpecHomeAvailable();
      final delegacionesHomeAvailable =
          await HomeResolverService.isDelegacionesPoliciaHomeAvailable();
      final peritoHomeAvailable =
          await HomeResolverService.isPeritoHomeAvailable();
      final homeRoute = motociclistaHomeAvailable
          ? AppRoutes.homeMotociclista
          : (fenixHomeAvailable
                ? AppRoutes.homeFenix
                : (agenteVialHomeAvailable
                      ? AppRoutes.homeAgenteVial
                      : (agenteUpecHomeAvailable
                            ? AppRoutes.homeAgenteUpec
                            : (delegacionesHomeAvailable
                                  ? AppRoutes.homeDelegaciones
                                  : (peritoHomeAvailable
                                        ? AppRoutes.homePerito
                                        : AppRoutes.home)))));
      navigator.pushNamedAndRemoveUntil(homeRoute, (_) => false);
      return;
    }

    if (current == route) {
      navigator.pushReplacementNamed(route, arguments: arguments);
    } else {
      navigator.pushNamed(route, arguments: arguments);
    }
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
    if (requiredUnitId == AuthService.unidadCulturaVialId) {
      return AuthService.isFomentoCulturaVialUser();
    }

    return (await AuthService.getUnidadId()) == requiredUnitId;
  }

  bool _allowed(Set<String> perms, String? requiredPerm, {bool all = false}) {
    if (all) return true;
    if (requiredPerm == null || requiredPerm.trim().isEmpty) return true;
    return perms.contains(requiredPerm.trim().toLowerCase());
  }

  Future<_DrawerAccess> _loadAccess() async {
    var permissions = await AuthService.getPermissions();
    var unidadId = await AuthService.getUnidadId();
    var canSeeCarreteras = await AuthService.isCarreterasUser();
    var canSeeVialidadesUrbanas =
        await AuthService.canAccessVialidadesUrbanasMenu();
    var isSuperadmin = await AuthService.isSuperadmin();
    var hasFullOperationalAccess = await AuthService.hasFullOperationalAccess();
    var canReviewCarreteras = await _canReviewCarreteras();
    var canUseConstanciasManejo = await AuthService.canUseConstanciasManejo();
    var canViewMapaPatrullas = await AuthService.canViewMapaPatrullas();
    var canUseLicensePointsModule =
        await AuthService.canUseLicensePointsModule();
    var canUseCulturaVial = await AuthService.isFomentoCulturaVialUser();
    var canUseDelegacionesActividadesFisicas =
        await AuthService.canUseDelegacionesActividadesFisicas();
    var canAccessConduceLegalidad =
        await AuthService.canAccessConduceLegalidad();
    var constanciasOnly = await AuthService.isEvaluadorTeoricoConstanciasOnly();

    if (permissions.isEmpty) {
      await AuthService.refreshCurrentUserAccess();
      permissions = await AuthService.getPermissions();
      unidadId = await AuthService.getUnidadId();
      canSeeCarreteras = await AuthService.isCarreterasUser();
      canSeeVialidadesUrbanas =
          await AuthService.canAccessVialidadesUrbanasMenu();
      isSuperadmin = await AuthService.isSuperadmin();
      hasFullOperationalAccess = await AuthService.hasFullOperationalAccess();
      canReviewCarreteras = await _canReviewCarreteras();
      canUseConstanciasManejo = await AuthService.canUseConstanciasManejo();
      canViewMapaPatrullas = await AuthService.canViewMapaPatrullas();
      canUseLicensePointsModule = await AuthService.canUseLicensePointsModule();
      canUseCulturaVial = await AuthService.isFomentoCulturaVialUser();
      canUseDelegacionesActividadesFisicas =
          await AuthService.canUseDelegacionesActividadesFisicas();
      canAccessConduceLegalidad = await AuthService.canAccessConduceLegalidad();
      constanciasOnly = await AuthService.isEvaluadorTeoricoConstanciasOnly();
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
      canViewMapaPatrullas: canViewMapaPatrullas,
      canUseLicensePointsModule: canUseLicensePointsModule,
      canUseCulturaVial: canUseCulturaVial,
      canUseDelegacionesActividadesFisicas:
          canUseDelegacionesActividadesFisicas,
      canAccessConduceLegalidad: canAccessConduceLegalidad,
      constanciasOnly: constanciasOnly,
    );
  }

  Future<bool> _canReviewCarreteras() async {
    if (await AuthService.isSuperadmin()) return true;
    return await AuthService.hasRoleName('RT') ||
        await AuthService.hasRoleName('Encargado de Destacamento');
  }

  Future<_DrawerHeaderData> _loadHeaderData() async {
    final constanciasOnly =
        await AuthService.isEvaluadorTeoricoConstanciasOnly();
    final unidadId = await AuthService.getUnidadId();

    return _DrawerHeaderData(
      constanciasOnly: constanciasOnly,
      backgroundAssetPath: unitBrandingAssetForUnitId(unidadId),
    );
  }

  _DrawerSubItem _statisticsLink(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required int unidadId,
    required String unidadNombre,
    String? requiredPerm,
  }) {
    return _DrawerSubItem(
      icon: icon,
      label: label,
      subtitle: 'Datos filtrados de $unidadNombre',
      onTap: () => _nav(
        context,
        route,
        requiredPerm: requiredPerm,
        arguments: <String, dynamic>{
          'unidad_id': unidadId,
          'unidad_nombre': unidadNombre,
        },
      ),
    );
  }

  _DrawerSubItem _statisticsReportLink(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String report,
  }) {
    return _DrawerSubItem(
      icon: icon,
      label: label,
      subtitle: 'Reporte e indicadores',
      onTap: () => _nav(
        context,
        AppRoutes.estadisticasReporte,
        arguments: <String, dynamic>{'reporte': report, 'titulo': label},
      ),
    );
  }

  List<Widget> _statisticsForUnit(
    BuildContext context, {
    required int unidadId,
    required String unidadNombre,
    required bool showHechos,
    required bool showActividades,
    required bool showAseguramientos,
    required bool showCarreteras,
    required bool bypassHechosPermission,
    required bool bypassActividadesPermission,
  }) {
    final hechos = _statisticsLink(
      context,
      icon: Icons.car_crash,
      label: 'Panel de Siniestros',
      route: AppRoutes.estadisticasGlobales,
      unidadId: unidadId,
      unidadNombre: unidadNombre,
      requiredPerm: bypassHechosPermission ? null : permEstadisticasGlobales,
    );
    final actividades = _statisticsLink(
      context,
      icon: Icons.photo_library,
      label: 'Panel de Actividades',
      route: AppRoutes.estadisticasActividades,
      unidadId: unidadId,
      unidadNombre: unidadNombre,
      requiredPerm: bypassActividadesPermission
          ? null
          : permEstadisticasActividades,
    );
    final aseguramientos = _statisticsLink(
      context,
      icon: Icons.inventory_2,
      label: unidadId == AuthService.unidadProteccionCarreterasId
          ? 'Aseguramientos'
          : 'Panel de Aseguramientos',
      route: AppRoutes.estadisticasAseguramientos,
      unidadId: unidadId,
      unidadNombre: unidadNombre,
    );

    if (unidadId == AuthService.unidadProteccionCarreterasId) {
      return <Widget>[
        if (showCarreteras)
          _statisticsReportLink(
            context,
            icon: Icons.table_chart,
            label: 'Concentrado',
            report: 'carreteras-concentrado',
          ),
        if (showCarreteras)
          _statisticsReportLink(
            context,
            icon: Icons.show_chart,
            label: 'Panel Carreteras',
            report: 'carreteras-panel',
          ),
        if (showCarreteras)
          _statisticsReportLink(
            context,
            icon: Icons.leaderboard,
            label: 'Puestas por elemento',
            report: 'carreteras-elementos',
          ),
        if (showCarreteras)
          _statisticsReportLink(
            context,
            icon: Icons.military_tech,
            label: 'Rendimiento operativo',
            report: 'carreteras-rendimiento',
          ),
        if (showCarreteras)
          _statisticsReportLink(
            context,
            icon: Icons.medical_information,
            label: 'Incapacidades del personal',
            report: 'carreteras-incapacidades',
          ),
        if (showAseguramientos) aseguramientos,
      ];
    }

    if (unidadId == AuthService.unidadCulturaVialId) {
      return <Widget>[
        _statisticsReportLink(
          context,
          icon: Icons.dashboard,
          label: 'Panel General de Estadísticas',
          report: 'fomento-panel',
        ),
        if (showActividades) actividades,
        if (showAseguramientos) aseguramientos,
        _statisticsReportLink(
          context,
          icon: Icons.leaderboard,
          label: 'Servicios por personal',
          report: 'fomento-servicios-personal',
        ),
      ];
    }

    return <Widget>[
      if (showHechos) hechos,
      if (unidadId == AuthService.unidadSiniestrosId && showHechos)
        _statisticsReportLink(
          context,
          icon: Icons.leaderboard,
          label: 'Rendimiento de Peritos',
          report: 'siniestros-rendimiento-peritos',
        ),
      if (showActividades) actividades,
      if (showAseguramientos) aseguramientos,
      if (unidadId == AuthService.unidadSiniestrosId && showHechos)
        _statisticsReportLink(
          context,
          icon: Icons.analytics,
          label: 'Resumen Ejecutivo',
          report: 'siniestros-resumen-ejecutivo',
        ),
      if (unidadId == AuthService.unidadSiniestrosId && showHechos)
        _DrawerSubItem(
          icon: Icons.polyline,
          label: 'Mapa de Choques por Zona',
          subtitle: 'Mapa y distribución de incidencias',
          onTap: () => _nav(context, AppRoutes.mapaIncidencias),
        ),
      if (unidadId == AuthService.unidadDelegacionesId) ...[
        _statisticsReportLink(
          context,
          icon: Icons.directions_run,
          label: 'Panel de Actividades Físicas',
          report: 'delegaciones-actividades-fisicas',
        ),
        _statisticsReportLink(
          context,
          icon: Icons.fact_check,
          label: 'Control envío INEGI',
          report: 'delegaciones-control-inegi',
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: UnitBrandingBackdrop(
        opacity: .022,
        widthFactor: .82,
        child: Column(
          children: [
            FutureBuilder<_DrawerHeaderData>(
              future: _loadHeaderData(),
              builder: (context, snapshot) {
                final headerData = snapshot.data ?? const _DrawerHeaderData();
                final constanciasOnly = headerData.constanciasOnly;
                return DrawerHeaderPanel(
                  title: 'Seguridad Vial',
                  subtitle: '',
                  backgroundAssetPath: headerData.backgroundAssetPath,
                  chips: <String>[
                    if (!constanciasOnly)
                      trackingOn ? 'Ubicación activa' : 'Ubicación inactiva',
                    'Menú principal',
                  ],
                );
              },
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
                      snap.data?.canSeeVialidadesUrbanas ?? false;
                  final unidadId = snap.data?.unidadId;
                  final canSeeCulturaVial =
                      hasFullOperationalAccess ||
                      (snap.data?.canUseCulturaVial ?? false);
                  final isSuperadmin = snap.data?.isSuperadmin ?? false;
                  final canSeeAllButtons = hasFullOperationalAccess;
                  final canSeePuestas =
                      canSeeAllButtons ||
                      isSuperadmin ||
                      _allowed(perms, permPuestasDisposicion);
                  final canCreatePuestas =
                      canSeeAllButtons ||
                      isSuperadmin ||
                      perms.contains('crear puestas a disposicion');
                  final canSeeDictamenes =
                      canSeeAllButtons ||
                      (_allowed(perms, permDictamenes) && unidadId == 1);
                  final canSeeConstanciasManejo =
                      snap.data?.canUseConstanciasManejo ?? false;
                  final constanciasOnly = snap.data?.constanciasOnly ?? false;
                  final canBypassEstadisticasPerm =
                      hasFullOperationalAccess || isSuperadmin;
                  final canSeeEstadisticasGlobales =
                      _allowed(
                        perms,
                        permEstadisticasGlobales,
                        all: canBypassEstadisticasPerm,
                      ) ||
                      _allowed(
                        perms,
                        permEstadisticas,
                        all: canBypassEstadisticasPerm,
                      );
                  final canSeeEstadisticasActividades = _allowed(
                    perms,
                    permEstadisticasActividades,
                    all: canBypassEstadisticasPerm,
                  );
                  final canSeeEstadisticasCarreteras =
                      canBypassEstadisticasPerm ||
                      perms.contains('ver estadisticas carreteras');
                  final canSeeAseguramientos =
                      canSeeEstadisticasGlobales ||
                      canSeeEstadisticasActividades ||
                      canSeeEstadisticasCarreteras;
                  final canSeeAllUnitStatistics =
                      isSuperadmin ||
                      unidadId == AuthService.unidadSeguridadVialId;
                  final canSeeMapaPatrullas =
                      snap.data?.canViewMapaPatrullas ?? false;
                  final canSeeMapaIncidencias = _allowed(
                    perms,
                    permMapa,
                    all: canSeeAllButtons,
                  );
                  final canSeeLicenciasPuntos =
                      snap.data?.canUseLicensePointsModule ?? false;
                  final canUseDelegacionesActividadesFisicas =
                      snap.data?.canUseDelegacionesActividadesFisicas ?? false;
                  final canSeeConduceLegalidad =
                      snap.data?.canAccessConduceLegalidad ??
                      _allowed(perms, permConduceLegalidad, all: isSuperadmin);
                  final canSeeOperativosGroup = canSeeConduceLegalidad;
                  final canSeeRndTool = unidadId != 2;

                  if (constanciasOnly) {
                    return ListView(
                      padding: drawerScrollablePadding(context),
                      children: [
                        const DrawerSectionLabel(label: 'General'),
                        _DrawerItem(
                          icon: Icons.home,
                          label: 'Inicio',
                          subtitle: 'Volver al feed',
                          onTap: () => _nav(context, AppRoutes.home),
                        ),
                        if (canSeeConstanciasManejo)
                          _DrawerItem(
                            icon: Icons.badge,
                            label: 'Constancias de manejo',
                            subtitle: 'Alta y captura de constancias',
                            onTap: () =>
                                _nav(context, AppRoutes.constanciasManejo),
                          ),
                        if (_allowed(perms, permActividades))
                          _DrawerItem(
                            icon: Icons.photo_library,
                            label: 'Actividades',
                            subtitle: 'Subir actividades del día',
                            onTap: () => _nav(
                              context,
                              AppRoutes.actividades,
                              requiredPerm: permActividades,
                            ),
                          ),
                        const SizedBox(height: 12),
                        const DrawerSectionLabel(label: 'Consulta'),
                        _DrawerGroup(
                          icon: Icons.handyman,
                          label: 'Herramientas',
                          subtitle: 'Calculadoras de apoyo',
                          children: [
                            if (canSeeRndTool)
                              _DrawerSubItem(
                                icon: Icons.app_registration,
                                label: 'Solicitar RND',
                                subtitle: 'Mensaje para faltas administrativas',
                                onTap: () => _nav(
                                  context,
                                  AppRoutes.herramientasRndFaltas,
                                ),
                              ),
                            _DrawerSubItem(
                              icon: Icons.tire_repair,
                              label: 'Huella de frenado',
                              subtitle: 'Calcular velocidad por huella',
                              onTap: () => _nav(
                                context,
                                AppRoutes.herramientasVelocidadFrenado,
                              ),
                            ),
                            _DrawerSubItem(
                              icon: Icons.car_repair,
                              label: 'Deformación de láminas',
                              subtitle: 'Calcular EES/EBS',
                              onTap: () => _nav(
                                context,
                                AppRoutes.herramientasVelocidadDeformacion,
                              ),
                            ),
                          ],
                        ),
                        _DrawerItem(
                          icon: Icons.gavel,
                          label: 'Sustento Legal',
                          subtitle: 'Fundamento legal de consulta',
                          onTap: () => _nav(context, AppRoutes.sustentoLegal),
                        ),
                      ],
                    );
                  }

                  return ListView(
                    padding: drawerScrollablePadding(context),
                    children: [
                      const DrawerSectionLabel(label: 'General'),
                      _DrawerItem(
                        icon: Icons.home,
                        label: 'Inicio',
                        subtitle: 'Volver al panel principal',
                        onTap: () => _nav(context, AppRoutes.home),
                      ),

                      if (_allowed(
                            perms,
                            permBusqueda,
                            all: canSeeAllButtons,
                          ) ||
                          canSeeConduceLegalidad)
                        _DrawerItem(
                          icon: Icons.search,
                          label: 'Búsqueda',
                          subtitle: 'Folios, personas, vehículos y hechos',
                          onTap: () => _nav(
                            context,
                            AppRoutes.hechosBuscar,
                            requiredPerm:
                                _allowed(
                                  perms,
                                  permBusqueda,
                                  all: canSeeAllButtons,
                                )
                                ? permBusqueda
                                : null,
                          ),
                        ),

                      if (canSeeEstadisticasGlobales ||
                          canSeeEstadisticasActividades ||
                          canSeeAseguramientos)
                        _DrawerGroup(
                          icon: Icons.insights,
                          label: 'Estadísticas',
                          subtitle: 'Siniestros, actividades e indicadores',
                          children: canSeeAllUnitStatistics
                              ? <Widget>[
                                  _DrawerGroup(
                                    icon: Icons.car_crash,
                                    label: 'Unidad Siniestros',
                                    children: _statisticsForUnit(
                                      context,
                                      unidadId: AuthService.unidadSiniestrosId,
                                      unidadNombre: 'Siniestros',
                                      showHechos: canSeeEstadisticasGlobales,
                                      showActividades:
                                          canSeeEstadisticasActividades,
                                      showAseguramientos: canSeeAseguramientos,
                                      showCarreteras:
                                          canSeeEstadisticasCarreteras,
                                      bypassHechosPermission:
                                          canBypassEstadisticasPerm ||
                                          _allowed(perms, permEstadisticas),
                                      bypassActividadesPermission:
                                          canBypassEstadisticasPerm,
                                    ),
                                  ),
                                  _DrawerGroup(
                                    icon: Icons.apartment,
                                    label: 'Unidad Delegaciones',
                                    children: _statisticsForUnit(
                                      context,
                                      unidadId:
                                          AuthService.unidadDelegacionesId,
                                      unidadNombre: 'Delegaciones',
                                      showHechos: canSeeEstadisticasGlobales,
                                      showActividades:
                                          canSeeEstadisticasActividades,
                                      showAseguramientos: canSeeAseguramientos,
                                      showCarreteras:
                                          canSeeEstadisticasCarreteras,
                                      bypassHechosPermission:
                                          canBypassEstadisticasPerm ||
                                          _allowed(perms, permEstadisticas),
                                      bypassActividadesPermission:
                                          canBypassEstadisticasPerm,
                                    ),
                                  ),
                                  _DrawerGroup(
                                    icon: Icons.route,
                                    label: 'Unidad Carreteras',
                                    children: _statisticsForUnit(
                                      context,
                                      unidadId: AuthService
                                          .unidadProteccionCarreterasId,
                                      unidadNombre: 'Carreteras',
                                      showHechos: false,
                                      showActividades:
                                          canSeeEstadisticasActividades,
                                      showAseguramientos: canSeeAseguramientos,
                                      showCarreteras:
                                          canSeeEstadisticasCarreteras,
                                      bypassHechosPermission:
                                          canBypassEstadisticasPerm ||
                                          _allowed(perms, permEstadisticas),
                                      bypassActividadesPermission:
                                          canBypassEstadisticasPerm,
                                    ),
                                  ),
                                  _DrawerGroup(
                                    icon: Icons.traffic,
                                    label: 'Unidad Vialidades Urbanas',
                                    children: _statisticsForUnit(
                                      context,
                                      unidadId:
                                          AuthService.unidadVialidadesUrbanasId,
                                      unidadNombre: 'Vialidades Urbanas',
                                      showHechos: false,
                                      showActividades:
                                          canSeeEstadisticasActividades,
                                      showAseguramientos: canSeeAseguramientos,
                                      showCarreteras:
                                          canSeeEstadisticasCarreteras,
                                      bypassHechosPermission:
                                          canBypassEstadisticasPerm ||
                                          _allowed(perms, permEstadisticas),
                                      bypassActividadesPermission:
                                          canBypassEstadisticasPerm,
                                    ),
                                  ),
                                  _DrawerGroup(
                                    icon: Icons.school,
                                    label: 'Unidad Cultura Vial',
                                    children: _statisticsForUnit(
                                      context,
                                      unidadId: AuthService.unidadCulturaVialId,
                                      unidadNombre: 'Cultura Vial',
                                      showHechos: false,
                                      showActividades:
                                          canSeeEstadisticasActividades,
                                      showAseguramientos: canSeeAseguramientos,
                                      showCarreteras:
                                          canSeeEstadisticasCarreteras,
                                      bypassHechosPermission:
                                          canBypassEstadisticasPerm ||
                                          _allowed(perms, permEstadisticas),
                                      bypassActividadesPermission:
                                          canBypassEstadisticasPerm,
                                    ),
                                  ),
                                ]
                              : _statisticsForUnit(
                                  context,
                                  unidadId: unidadId ?? 0,
                                  unidadNombre: switch (unidadId) {
                                    AuthService.unidadSiniestrosId =>
                                      'Siniestros',
                                    AuthService.unidadDelegacionesId =>
                                      'Delegaciones',
                                    AuthService.unidadProteccionCarreterasId =>
                                      'Carreteras',
                                    AuthService.unidadVialidadesUrbanasId =>
                                      'Vialidades Urbanas',
                                    AuthService.unidadCulturaVialId =>
                                      'Cultura Vial',
                                    _ => 'tu unidad',
                                  },
                                  showHechos:
                                      canSeeEstadisticasGlobales &&
                                      (unidadId ==
                                              AuthService.unidadSiniestrosId ||
                                          unidadId ==
                                              AuthService.unidadDelegacionesId),
                                  showActividades:
                                      canSeeEstadisticasActividades,
                                  showAseguramientos: canSeeAseguramientos,
                                  showCarreteras: canSeeEstadisticasCarreteras,
                                  bypassHechosPermission:
                                      canBypassEstadisticasPerm ||
                                      _allowed(perms, permEstadisticas),
                                  bypassActividadesPermission:
                                      canBypassEstadisticasPerm,
                                ),
                        ),

                      const SizedBox(height: 12),
                      if (canSeePuestas || canSeeDictamenes) ...[
                        const DrawerSectionLabel(label: 'Operación'),
                        _DrawerGroup(
                          icon: Icons.gavel,
                          label: 'Puestas a disposición',
                          subtitle:
                              'Puestas, creación y dictámenes disponibles',
                          children: [
                            if (canSeePuestas)
                              _DrawerSubItem(
                                icon: Icons.folder_open,
                                label: 'Listado de puestas',
                                subtitle: 'Consultar registros capturados',
                                onTap: () => _nav(
                                  context,
                                  AppRoutes.puestasDisposicion,
                                  requiredPerm: permPuestasDisposicion,
                                ),
                              ),
                            if (canCreatePuestas)
                              _DrawerSubItem(
                                icon: Icons.add_circle_outline,
                                label: 'Crear puesta',
                                subtitle: 'Registrar una nueva puesta',
                                onTap: () => _nav(
                                  context,
                                  AppRoutes.puestasDisposicionCreate,
                                  requiredPerm: 'crear puestas a disposicion',
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
                              icon: Icons.fact_check_outlined,
                              label: 'Seguimiento de hechos',
                              subtitle: 'Pendientes, turnados y faltantes',
                              onTap: () => _nav(
                                context,
                                AppRoutes.hechosSeguimiento,
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

                      if (_allowed(
                        perms,
                        permActividades,
                        all: canSeeAllButtons,
                      ))
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

                      if (canUseDelegacionesActividadesFisicas)
                        _DrawerItem(
                          icon: Icons.fitness_center_outlined,
                          label: 'Ejercicios Delegaciones',
                          subtitle: 'Subir foto y participantes',
                          onTap: () => _nav(
                            context,
                            AppRoutes.delegacionesActividadesFisicas,
                          ),
                        ),

                      if (canSeeConstanciasManejo)
                        _DrawerGroup(
                          icon: Icons.fact_check,
                          label: 'Modulo de examenes',
                          subtitle: 'Captura diaria y constancias',
                          children: [
                            _DrawerSubItem(
                              icon: Icons.today,
                              label: 'Examenes diarios',
                              subtitle: 'Capturar totales por modulo',
                              onTap: () => _nav(
                                context,
                                AppRoutes.moduloExamenesDiarios,
                              ),
                            ),
                            _DrawerSubItem(
                              icon: Icons.badge,
                              label: 'Constancias de manejo',
                              subtitle: 'Generar lotes, imprimir y activar',
                              onTap: () =>
                                  _nav(context, AppRoutes.constanciasManejo),
                            ),
                          ],
                        ),

                      if (canSeeLicenciasPuntos)
                        _DrawerItem(
                          icon: Icons.scoreboard_outlined,
                          label: 'Puntos de licencia',
                          subtitle: 'Escanear licencia y revisar saldo',
                          onTap: () => _nav(context, AppRoutes.licenciasPuntos),
                        ),

                      if (canSeeOperativosGroup)
                        _DrawerGroup(
                          icon: Icons.assignment_turned_in_outlined,
                          label: 'Operativos',
                          subtitle:
                              'Conduce con legalidad, alcoholimetría y listados',
                          children: [
                            if (canSeeConduceLegalidad)
                              _DrawerSubItem(
                                icon: ConduceLegalidadModule
                                    .conduceLegalidad
                                    .icon,
                                label: ConduceLegalidadModule
                                    .conduceLegalidad
                                    .title,
                                subtitle: ConduceLegalidadModule
                                    .conduceLegalidad
                                    .listSubtitle,
                                onTap: () =>
                                    _nav(context, AppRoutes.conduceLegalidad),
                              ),
                            if (canSeeConduceLegalidad)
                              _DrawerSubItem(
                                icon:
                                    ConduceLegalidadModule.alcoholimetria.icon,
                                label:
                                    ConduceLegalidadModule.alcoholimetria.title,
                                subtitle: ConduceLegalidadModule
                                    .alcoholimetria
                                    .listSubtitle,
                                onTap: () =>
                                    _nav(context, AppRoutes.alcoholimetria),
                              ),
                            _DrawerSubItem(
                              icon: Icons.list_alt,
                              label: 'Listado de operativos',
                              subtitle: 'Elegir el módulo operativo',
                              onTap: () => _nav(context, AppRoutes.operativos),
                            ),
                          ],
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

                      if (canSeeMapaPatrullas || canSeeMapaIncidencias)
                        _DrawerGroup(
                          icon: Icons.map,
                          label: 'Mapa',
                          subtitle: 'Ubicación de patrullas e incidencias',
                          children: [
                            if (canSeeMapaPatrullas)
                              _DrawerSubItem(
                                icon: Icons.local_police,
                                label: 'Mapa patrullas',
                                subtitle: 'Ubicar personal y patrullas',
                                onTap: () => _nav(context, AppRoutes.mapa),
                              ),
                            if (canSeeMapaIncidencias)
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

                      _DrawerGroup(
                        icon: Icons.handyman,
                        label: 'Herramientas',
                        subtitle: 'Calculadoras de apoyo pericial',
                        children: [
                          if (canSeeRndTool)
                            _DrawerSubItem(
                              icon: Icons.app_registration,
                              label: 'Solicitar RND',
                              subtitle: 'Mensaje para faltas administrativas',
                              onTap: () => _nav(
                                context,
                                AppRoutes.herramientasRndFaltas,
                              ),
                            ),
                          _DrawerSubItem(
                            icon: Icons.tire_repair,
                            label: 'Huella de frenado',
                            subtitle:
                                'Calcular velocidad con base a la huella de frenado',
                            onTap: () => _nav(
                              context,
                              AppRoutes.herramientasVelocidadFrenado,
                            ),
                          ),
                          _DrawerSubItem(
                            icon: Icons.car_repair,
                            label: 'Deformación de láminas',
                            subtitle:
                                'Calcular EES/EBS con perfil de deformación',
                            onTap: () => _nav(
                              context,
                              AppRoutes.herramientasVelocidadDeformacion,
                            ),
                          ),
                          _DrawerSubItem(
                            icon: Icons.route,
                            label: 'Reconstructor de tránsito 2D',
                            subtitle: 'Escenas, trayectorias y secuencias',
                            onTap: () => _nav(
                              context,
                              AppRoutes.herramientasReconstructorTransito2d,
                            ),
                          ),
                          if (isSuperadmin)
                            _DrawerSubItem(
                              icon: Icons.badge_outlined,
                              label: 'Emisión de licencias',
                              subtitle: 'Examen, constancia e historial',
                              onTap: () => _nav(
                                context,
                                AppRoutes.herramientasLicenciasEmision,
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
      ),
    );
  }
}

class _DrawerHeaderData {
  const _DrawerHeaderData({
    this.constanciasOnly = false,
    this.backgroundAssetPath,
  });

  final bool constanciasOnly;
  final String? backgroundAssetPath;
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
  final bool canViewMapaPatrullas;
  final bool canUseLicensePointsModule;
  final bool canUseCulturaVial;
  final bool canUseDelegacionesActividadesFisicas;
  final bool canAccessConduceLegalidad;
  final bool constanciasOnly;

  const _DrawerAccess({
    required this.perms,
    required this.unidadId,
    required this.canSeeCarreteras,
    required this.canSeeVialidadesUrbanas,
    required this.isSuperadmin,
    required this.hasFullOperationalAccess,
    required this.canReviewCarreteras,
    required this.canUseConstanciasManejo,
    required this.canViewMapaPatrullas,
    required this.canUseLicensePointsModule,
    required this.canUseCulturaVial,
    required this.canUseDelegacionesActividadesFisicas,
    required this.canAccessConduceLegalidad,
    required this.constanciasOnly,
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
