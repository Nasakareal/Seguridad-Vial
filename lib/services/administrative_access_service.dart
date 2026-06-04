import 'auth_service.dart';

class AdministrativeAccess {
  final bool canSeeUsers;
  final bool canSeePersonal;
  final bool canSeeSiniestrosStats;
  final bool canSeeActividadesStats;
  final bool canSeeDelegacionesStats;
  final bool canSeeVialidadesStats;

  const AdministrativeAccess({
    required this.canSeeUsers,
    required this.canSeePersonal,
    required this.canSeeSiniestrosStats,
    required this.canSeeActividadesStats,
    required this.canSeeDelegacionesStats,
    required this.canSeeVialidadesStats,
  });

  bool get canSeeAnyStatistics =>
      canSeeSiniestrosStats ||
      canSeeActividadesStats ||
      canSeeDelegacionesStats ||
      canSeeVialidadesStats;

  bool get canSeeConfigurationMenu =>
      canSeeUsers || canSeePersonal || canSeeAnyStatistics;
}

class AdministrativeAccessService {
  const AdministrativeAccessService._();

  static Future<AdministrativeAccess> loadAccess({bool refresh = false}) async {
    if (refresh) {
      await AuthService.refreshCurrentUserAccess();
    }

    final isSuperadmin = await AuthService.isSuperadmin();
    final hasFullOperationalAccess =
        await AuthService.hasFullOperationalAccess();
    final hasAdminRole = await hasAdministrativeRole();
    final permissions = (await AuthService.getPermissions())
        .map((permission) => permission.trim().toLowerCase())
        .toSet();
    final unidadId = await AuthService.getUnidadId();

    bool hasPermission(String permission) {
      return permissions.contains(permission.trim().toLowerCase());
    }

    final isSiniestros = unidadId == 1 || await AuthService.isSiniestrosUser();
    final isDelegaciones =
        unidadId == AuthService.unidadDelegacionesId ||
        await AuthService.isDelegacionesUser();
    final isVialidades =
        unidadId == AuthService.unidadVialidadesUrbanasId ||
        await AuthService.isVialidadesUrbanasUser();
    final isFomento = unidadId == AuthService.unidadCulturaVialId;

    final canSeeUsers =
        hasAdminRole && (isSuperadmin || hasPermission('ver usuarios'));
    final canSeePersonal =
        hasAdminRole && (isSuperadmin || hasPermission('ver personal'));

    final canSeeSiniestrosStats =
        isSuperadmin ||
        hasFullOperationalAccess ||
        (hasPermission('ver estadisticas globales') && isSiniestros);

    final canSeeActividadesStats =
        isSuperadmin ||
        hasFullOperationalAccess ||
        (hasPermission('ver estadisticas actividades') &&
            (isSiniestros || isFomento));

    final canSeeDelegacionesStats =
        isSuperadmin ||
        hasFullOperationalAccess ||
        (hasPermission('ver estadisticas') && isDelegaciones);

    final canSeeVialidadesStats =
        isSuperadmin ||
        hasFullOperationalAccess ||
        (hasPermission('ver operativos vialidades') && isVialidades);

    return AdministrativeAccess(
      canSeeUsers: canSeeUsers,
      canSeePersonal: canSeePersonal,
      canSeeSiniestrosStats: canSeeSiniestrosStats,
      canSeeActividadesStats: canSeeActividadesStats,
      canSeeDelegacionesStats: canSeeDelegacionesStats,
      canSeeVialidadesStats: canSeeVialidadesStats,
    );
  }

  static Future<bool> canSeeConfigurationMenu() async {
    return (await loadAccess()).canSeeConfigurationMenu;
  }

  static Future<bool> hasAdministrativeRole() async {
    final roleId = await AuthService.getRoleId();
    if (roleId == 1 || roleId == 2 || roleId == 3 || roleId == 5) {
      return true;
    }

    return await AuthService.isSuperadmin() ||
        await AuthService.hasRoleName('subdirector') ||
        await AuthService.hasRoleName('administrador') ||
        await AuthService.isAdministrativoRole();
  }
}
