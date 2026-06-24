import 'auth_service.dart';

class AdministrativeAccess {
  final bool canSeeUsers;
  final bool canSeePersonal;
  final bool canSeeSiniestrosFiles;
  final bool canSeeDelegacionesFiles;
  final bool canSeeVialidadesFiles;
  final bool canSeeFomentoFiles;

  const AdministrativeAccess({
    required this.canSeeUsers,
    required this.canSeePersonal,
    required this.canSeeSiniestrosFiles,
    required this.canSeeDelegacionesFiles,
    required this.canSeeVialidadesFiles,
    required this.canSeeFomentoFiles,
  });

  bool get canSeeAnyStatisticsFiles =>
      canSeeSiniestrosFiles ||
      canSeeDelegacionesFiles ||
      canSeeVialidadesFiles ||
      canSeeFomentoFiles;

  bool get canSeeConfigurationMenu =>
      canSeeUsers || canSeePersonal || canSeeAnyStatisticsFiles;
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
    final isFomento = await AuthService.isFomentoCulturaVialUser();
    final isSeguridadVial = unidadId == AuthService.unidadSeguridadVialId;

    final canSeeUsers =
        hasAdminRole && (isSuperadmin || hasPermission('ver usuarios'));
    final canSeePersonal =
        hasAdminRole && (isSuperadmin || hasPermission('ver personal'));

    final canSeeSiniestrosFiles =
        hasAdminRole &&
        (isSuperadmin || hasFullOperationalAccess || isSiniestros);
    final canSeeDelegacionesFiles =
        hasAdminRole &&
        (isSuperadmin || hasFullOperationalAccess || isDelegaciones);
    final canSeeVialidadesFiles =
        hasAdminRole &&
        (isSuperadmin ||
            hasFullOperationalAccess ||
            isSeguridadVial ||
            isVialidades);
    final canSeeFomentoFiles =
        hasAdminRole &&
        (isSuperadmin ||
            hasFullOperationalAccess ||
            isSeguridadVial ||
            isFomento);

    return AdministrativeAccess(
      canSeeUsers: canSeeUsers,
      canSeePersonal: canSeePersonal,
      canSeeSiniestrosFiles: canSeeSiniestrosFiles,
      canSeeDelegacionesFiles: canSeeDelegacionesFiles,
      canSeeVialidadesFiles: canSeeVialidadesFiles,
      canSeeFomentoFiles: canSeeFomentoFiles,
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
