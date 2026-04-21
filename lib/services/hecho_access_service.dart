import 'auth_service.dart';

class HechoEditAccess {
  final bool canEditByPermission;
  final bool canEditAnyHecho;
  final bool canEditDelegacionHechos;
  final bool isDelegacionesUser;
  final bool hechosModuleExcluded;
  final bool canEditOwnHechos;
  final int? currentUserId;
  final int? currentDelegacionId;
  final String? currentUserName;

  const HechoEditAccess({
    this.canEditByPermission = false,
    this.canEditAnyHecho = false,
    this.canEditDelegacionHechos = false,
    this.isDelegacionesUser = false,
    this.hechosModuleExcluded = false,
    this.canEditOwnHechos = false,
    this.currentUserId,
    this.currentDelegacionId,
    this.currentUserName,
  });

  static const none = HechoEditAccess();

  bool canEditHecho(Map<String, dynamic> hecho) {
    if (hechosModuleExcluded) return false;

    if (canEditAnyHecho) return true;
    if (_backendAllowsEdit(hecho)) return true;

    if (isDelegacionesUser && canEditDelegacionHechos) {
      final hechoDelegacionId = _delegacionIdFromHecho(hecho);
      if (currentDelegacionId != null &&
          hechoDelegacionId == currentDelegacionId) {
        return true;
      }
    }

    if (canEditOwnHechos && _isOwnHecho(hecho)) {
      return true;
    }

    return false;
  }

  bool _backendAllowsEdit(Map<String, dynamic> hecho) {
    if (!hecho.containsKey('puede_editar')) return false;
    return _boolFrom(hecho['puede_editar']);
  }

  bool _isOwnHecho(Map<String, dynamic> hecho) {
    if (currentUserId != null) {
      for (final ownerId in _ownerUserIds(hecho)) {
        if (ownerId == currentUserId) return true;
      }
    }

    final normalizedCurrentName = _normalizeText(currentUserName ?? '');
    if (normalizedCurrentName.isNotEmpty) {
      for (final ownerName in _ownerNames(hecho)) {
        if (_normalizeText(ownerName) == normalizedCurrentName) return true;
      }
    }

    return false;
  }

  Iterable<int> _ownerUserIds(Map<String, dynamic> hecho) sync* {
    const directKeys = <String>[
      'created_by',
      'createdBy',
      'created_user_id',
      'createdUserId',
      'creado_por_id',
      'creadoPorId',
      'capturado_por_id',
      'capturadoPorId',
      'registrado_por_id',
      'registradoPorId',
      'usuario_id',
      'usuarioId',
      'user_id',
      'userId',
      'owner_id',
      'ownerId',
    ];

    for (final key in directKeys) {
      final id = _intFrom(hecho[key]);
      if (id != null) yield id;
    }

    const nestedKeys = <String>[
      'created_by_user',
      'createdByUser',
      'creado_por',
      'creadoPor',
      'capturado_por',
      'capturadoPor',
      'registrado_por',
      'registradoPor',
      'usuario',
      'user',
      'owner',
    ];

    for (final key in nestedKeys) {
      final raw = hecho[key];
      if (raw is Map) {
        final id = _intFrom(
          raw['id'] ??
              raw['value'] ??
              raw['user_id'] ??
              raw['userId'] ??
              raw['usuario_id'] ??
              raw['usuarioId'],
        );
        if (id != null) yield id;
      } else {
        final id = _intFrom(raw);
        if (id != null) yield id;
      }
    }
  }

  Iterable<String> _ownerNames(Map<String, dynamic> hecho) sync* {
    const directKeys = <String>[
      'perito',
      'created_by',
      'createdBy',
      'created_by_name',
      'createdByName',
      'creado_por',
      'creadoPor',
      'creado_por_nombre',
      'creadoPorNombre',
      'capturado_por',
      'capturadoPor',
      'capturado_por_nombre',
      'capturadoPorNombre',
      'registrado_por',
      'registradoPor',
      'registrado_por_nombre',
      'registradoPorNombre',
      'usuario_nombre',
      'usuarioNombre',
      'user_name',
      'userName',
      'owner_name',
      'ownerName',
    ];

    for (final key in directKeys) {
      final text = _nameText(hecho[key]);
      if (text != null) yield text;
    }

    const nestedKeys = <String>[
      'created_by_user',
      'createdByUser',
      'creado_por',
      'creadoPor',
      'capturado_por',
      'capturadoPor',
      'registrado_por',
      'registradoPor',
      'usuario',
      'user',
      'owner',
    ];

    for (final key in nestedKeys) {
      final raw = hecho[key];
      if (raw is Map) {
        for (final nameKey in const <String>[
          'name',
          'nombre',
          'full_name',
          'fullName',
          'display_name',
          'displayName',
        ]) {
          final text = _nameText(raw[nameKey]);
          if (text != null) yield text;
        }
      } else {
        final text = _nameText(raw);
        if (text != null) yield text;
      }
    }
  }

  int? _delegacionIdFromHecho(Map<String, dynamic> hecho) {
    final direct = _intFrom(
      hecho['delegacion_id'] ??
          hecho['delegacionId'] ??
          hecho['delegacion_org_id'],
    );
    if (direct != null) return direct;

    final delegacion = hecho['delegacion'];
    if (delegacion is Map) {
      return _intFrom(delegacion['id'] ?? delegacion['value']);
    }

    return null;
  }

  static int? _intFrom(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool _boolFrom(dynamic value) {
    if (value is bool) return value;
    final s = (value ?? '').toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'si' || s == 'sí';
  }

  static String? _nameText(dynamic value) {
    if (value == null || value is Map || value is Iterable) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    if (int.tryParse(text) != null) return null;
    return text;
  }

  static String _normalizeText(String raw) {
    return raw
        .trim()
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}

class HechoAccessService {
  static Future<HechoEditAccess> loadEditAccess({bool refresh = false}) async {
    if (refresh) {
      try {
        await AuthService.refreshCurrentUserAccess();
      } catch (_) {}
    }

    final isSuperadmin = await AuthService.isSuperadmin();
    final canEditByPermission =
        isSuperadmin || await AuthService.can('editar hechos');
    final excluded = await AuthService.isHechosModuleExcludedUser();
    final userId = await AuthService.getUserId();
    final userName = await AuthService.getUserName(refreshIfMissing: false);
    final delegacionId = await AuthService.getDelegacionId();
    final isDelegaciones = await AuthService.isDelegacionesUser();
    final isSiniestros = await AuthService.isSiniestrosUser();
    final isPerito = await AuthService.isPerito();
    final isDelegacionesPrivileged =
        await AuthService.isDelegacionesHechosPrivilegedRole();
    final isAdministrativo = await AuthService.isAdministrativoRole();
    final role = (await AuthService.getRole())?.trim().toLowerCase() ?? '';

    final canEditAny =
        canEditByPermission &&
        !excluded &&
        (isDelegaciones
            ? isDelegacionesPrivileged
            : const {
                'superadmin',
                'administrador',
                'administrativo',
                'subdirector',
              }.contains(role));

    return HechoEditAccess(
      canEditByPermission: canEditByPermission,
      canEditAnyHecho: canEditAny,
      canEditDelegacionHechos:
          canEditByPermission &&
          !excluded &&
          isDelegaciones &&
          isAdministrativo,
      isDelegacionesUser: isDelegaciones,
      hechosModuleExcluded: excluded,
      canEditOwnHechos:
          canEditByPermission || (!excluded && (isSiniestros || isPerito)),
      currentUserId: userId,
      currentDelegacionId: delegacionId,
      currentUserName: userName,
    );
  }
}
