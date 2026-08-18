import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../services/administrative_access_service.dart';
import '../services/auth_service.dart';
import '../services/settings_personal_service.dart';
import 'drawer_ui.dart';
import 'glass.dart';
import 'photo_viewer.dart';
import 'unit_branding_watermark.dart';

class AccountMenuAction extends StatelessWidget {
  final String tooltip;

  const AccountMenuAction({super.key, this.tooltip = 'Mi cuenta'});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return LiquidGlassIconButton(
          tooltip: tooltip,
          icon: Icons.person_outline,
          onPressed: () => Scaffold.of(context).openEndDrawer(),
        );
      },
    );
  }
}

class AppAccountDrawer extends StatelessWidget {
  final Future<void> Function() onLogout;

  const AppAccountDrawer({super.key, required this.onLogout});

  Future<_AccountSummary> _loadSummary() async {
    // El perfil local se actualiza desde el home; leerlo primero evita que la
    // apertura del drawer dependa de la latencia de red.
    var payload = await AuthService.getStoredUserPayload();
    payload ??= await AuthService.getCurrentUserPayload(refresh: false);

    final role =
        _readNestedString(payload?['role'], ['name', 'nombre']) ??
        (await AuthService.getRole()) ??
        'Sin rol';

    final unit =
        _readNestedString(payload?['unidad'], ['nombre', 'name']) ??
        _readString(payload, ['unidad_nombre', 'unidadName', 'area']) ??
        'Sin unidad';

    final name =
        _readString(payload, ['name', 'nombre', 'full_name']) ??
        (await AuthService.getUserName(refreshIfMissing: false)) ??
        'Usuario';

    final email =
        _readString(payload, ['email', 'correo']) ??
        (await AuthService.getUserEmail()) ??
        '';

    final photoUrl = SettingsPersonalService.photoUrlFor(payload);
    final unitId = await AuthService.getUnidadId();
    final permissions = await AuthService.getPermissions();
    final canUseTrafficPriority =
        await AuthService.isSuperadmin() ||
        await AuthService.hasFullOperationalAccess() ||
        permissions.contains('operar prioridad semaforica') ||
        unitId == AuthService.unidadSeguridadVialId ||
        unitId == AuthService.unidadProteccionCarreterasId ||
        unitId == AuthService.unidadVialidadesUrbanasId;

    var access = await AdministrativeAccessService.loadAccess();
    if (!access.canSeeConfigurationMenu) {
      access = await AdministrativeAccessService.loadAccess(refresh: true);
    }

    return _AccountSummary(
      name: name,
      email: email,
      role: role,
      unit: unit,
      photoUrl: photoUrl,
      access: access,
      canUseTrafficPriority: canUseTrafficPriority,
    );
  }

  Future<void> _goTo(
    BuildContext context,
    String route, {
    Object? arguments,
  }) async {
    final navigator = Navigator.of(context);
    final current = ModalRoute.of(context)?.settings.name;

    navigator.pop();

    if (current == route) {
      return;
    }

    await Future<void>.delayed(Duration.zero);
    if (!navigator.context.mounted) {
      return;
    }

    navigator.pushNamed(route, arguments: arguments);
  }

  Future<void> _handleLogout(BuildContext context) async {
    Navigator.of(context).pop();
    await Future<void>.delayed(Duration.zero);
    await onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: UnitBrandingBackdrop(
        opacity: .022,
        widthFactor: .82,
        child: FutureBuilder<_AccountSummary>(
          future: _loadSummary(),
          builder: (context, snapshot) {
            final summary = snapshot.data;
            final email = summary?.email ?? '';
            final photoUrl = summary?.photoUrl ?? '';

            return Column(
              children: [
                DrawerHeaderPanel(
                  avatarText: _initials(summary?.name ?? ''),
                  photoUrl: photoUrl,
                  onPhotoTap: photoUrl.trim().isEmpty
                      ? null
                      : () => showPhotoViewer(
                          context: context,
                          title: summary?.name ?? 'Foto de perfil',
                          photoUrl: photoUrl,
                        ),
                  title: summary?.name ?? 'Cargando perfil...',
                  subtitle: email.trim().isEmpty ? 'Cuenta actual' : email,
                  helper: 'Administra tu cuenta, contraseña y salida segura.',
                  chips: <String>[
                    summary?.role ?? 'Sin rol',
                    summary?.unit ?? 'Sin unidad',
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: drawerScrollablePadding(context),
                    children: [
                      const DrawerSectionLabel(label: 'Cuenta'),
                      DrawerSurface(
                        child: Column(
                          children: [
                            DrawerActionTile(
                              icon: Icons.person_outline,
                              title: 'Perfil',
                              subtitle: 'Ver mis datos y rol actual',
                              onTap: () => _goTo(context, AppRoutes.profile),
                            ),
                            Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                              indent: 66,
                            ),
                            DrawerActionTile(
                              icon: Icons.manage_search_outlined,
                              title: 'Mis capturas',
                              subtitle: 'Registros subidos por mi usuario',
                              onTap: () =>
                                  _goTo(context, AppRoutes.misCapturas),
                            ),
                            Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                              indent: 66,
                            ),
                            DrawerActionTile(
                              icon: Icons.lock_outline,
                              title: 'Cambiar contraseña',
                              subtitle: 'Actualizar credenciales de acceso',
                              onTap: () =>
                                  _goTo(context, AppRoutes.changePassword),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const DrawerSectionLabel(label: 'Herramientas'),
                      DrawerSurface(
                        child: Column(
                          children: _withDividers([
                            DrawerActionTile(
                              icon: Icons.forum_outlined,
                              title: 'Comunicaciones',
                              subtitle: 'Mensajes, avisos y órdenes',
                              onTap: () =>
                                  _goTo(context, AppRoutes.comunicaciones),
                            ),
                            if (summary?.canUseTrafficPriority == true)
                              DrawerActionTile(
                                icon: Icons.traffic_outlined,
                                title: 'Prioridad semafórica',
                                subtitle:
                                    'Solicitar y confirmar paso prioritario',
                                onTap: () =>
                                    _goTo(context, AppRoutes.controlSemaforico),
                              ),
                            DrawerActionTile(
                              icon: Icons.sticky_note_2_outlined,
                              title: 'Mis notas',
                              subtitle: 'Notas privadas, colores y marcatexto',
                              onTap: () => _goTo(context, AppRoutes.notes),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const DrawerSectionLabel(label: 'Ayuda'),
                      DrawerSurface(
                        child: Column(
                          children: [
                            DrawerActionTile(
                              icon: Icons.play_circle_outline,
                              title: 'Tutoriales',
                              subtitle: 'Videos de ayuda de la app movil',
                              onTap: () => _goTo(context, AppRoutes.tutoriales),
                            ),
                            Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                              indent: 66,
                            ),
                            DrawerActionTile(
                              icon: Icons.support_agent_outlined,
                              title: 'Red de apoyo',
                              subtitle: 'Contactos regionales para pedir apoyo',
                              onTap: () =>
                                  _goTo(context, AppRoutes.directorioRedApoyo),
                            ),
                          ],
                        ),
                      ),
                      if (summary?.access.canSeeConfigurationMenu == true) ...[
                        const SizedBox(height: 12),
                        const DrawerSectionLabel(label: 'Configuración'),
                        DrawerSurface(
                          child: Column(
                            children: _withDividers([
                              DrawerActionTile(
                                icon: Icons.settings_outlined,
                                title: 'Configuraciones',
                                subtitle: 'Usuarios, personal y archivos',
                                onTap: () => _goTo(context, AppRoutes.settings),
                              ),
                              if (summary?.access.canSeeSiniestrosFiles == true)
                                DrawerActionTile(
                                  icon: Icons.car_crash_outlined,
                                  title: 'Archivos Siniestros',
                                  subtitle:
                                      'Patrullas, partes, bitácoras y Excel',
                                  onTap: () => _goTo(
                                    context,
                                    AppRoutes.settingsStatisticsFiles,
                                    arguments: 'siniestros',
                                  ),
                                ),
                              if (summary?.access.canSeeDelegacionesFiles ==
                                  true)
                                DrawerActionTile(
                                  icon: Icons.rule_folder_outlined,
                                  title: 'Revisión Excel Delegaciones',
                                  subtitle:
                                      'Ver registros contemplados y alertas',
                                  onTap: () => _goTo(
                                    context,
                                    AppRoutes.delegacionesExcelRevision,
                                  ),
                                ),
                              if (summary?.access.canSeeDelegacionesFiles ==
                                  true)
                                DrawerActionTile(
                                  icon: Icons.fact_check_outlined,
                                  title: 'Archivos Delegaciones',
                                  subtitle: 'Excel diario y mensual',
                                  onTap: () => _goTo(
                                    context,
                                    AppRoutes.settingsStatisticsFiles,
                                    arguments: 'delegaciones',
                                  ),
                                ),
                              if (summary?.access.canSeeVialidadesFiles == true)
                                DrawerActionTile(
                                  icon: Icons.traffic_outlined,
                                  title: 'Archivos Vialidades',
                                  subtitle:
                                      'Excel diario de Vialidades Urbanas',
                                  onTap: () => _goTo(
                                    context,
                                    AppRoutes.settingsStatisticsFiles,
                                    arguments: 'vialidades',
                                  ),
                                ),
                              if (summary?.access.canSeeFomentoFiles == true)
                                DrawerActionTile(
                                  icon: Icons.school_outlined,
                                  title: 'Archivos Fomento',
                                  subtitle: 'Excel diario de Fomento',
                                  onTap: () => _goTo(
                                    context,
                                    AppRoutes.settingsStatisticsFiles,
                                    arguments: 'fomento',
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const DrawerSectionLabel(label: 'Sesión'),
                      DrawerSurface(
                        child: DrawerActionTile(
                          icon: Icons.logout,
                          title: 'Cerrar sesión',
                          subtitle: 'Salir de la cuenta actual',
                          danger: true,
                          onTap: () => _handleLogout(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountSummary {
  final String name;
  final String email;
  final String role;
  final String unit;
  final String photoUrl;
  final AdministrativeAccess access;
  final bool canUseTrafficPriority;

  const _AccountSummary({
    required this.name,
    required this.email,
    required this.role,
    required this.unit,
    required this.photoUrl,
    required this.access,
    required this.canUseTrafficPriority,
  });
}

String _initials(String raw) {
  final parts = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return 'SV';
  }

  if (parts.length == 1) {
    final text = parts.first;
    return text.substring(0, text.length >= 2 ? 2 : 1).toUpperCase();
  }

  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String? _readString(Map<String, dynamic>? payload, List<String> keys) {
  if (payload == null || payload.isEmpty) {
    return null;
  }

  for (final key in keys) {
    final text = payload[key]?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
  }

  return null;
}

String? _readNestedString(dynamic raw, List<String> keys) {
  if (raw is! Map) {
    return null;
  }

  for (final key in keys) {
    final text = raw[key]?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
  }

  return null;
}

List<Widget> _withDividers(List<Widget> children) {
  if (children.isEmpty) {
    return const <Widget>[];
  }

  final items = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) {
      items.add(Divider(height: 1, color: Colors.grey.shade200, indent: 66));
    }
    items.add(children[i]);
  }

  return items;
}
