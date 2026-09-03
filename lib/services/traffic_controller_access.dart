import 'auth_service.dart';

class TrafficControllerAccess {
  const TrafficControllerAccess._();

  static bool isAllowed({
    required int? unitId,
    required int? roleId,
    required String? roleName,
  }) {
    return roleId == 1 ||
        roleName?.trim().toLowerCase() == 'superadmin' ||
        unitId == AuthService.unidadCulturaVialId;
  }

  static Future<bool> currentUserIsAllowed() async {
    return isAllowed(
      unitId: await AuthService.getUnidadId(),
      roleId: await AuthService.getRoleId(),
      roleName: await AuthService.getRole(),
    );
  }
}
