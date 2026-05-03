import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class GruasCatalogService {
  static Future<List<Map<String, dynamic>>> fetchVisibleGruas() async {
    final access = await _currentAccess();
    if (!access.hasFullAccess && access.unidadFiltroId == null) {
      return const <Map<String, dynamic>>[];
    }

    final uri = Uri.parse('${AuthService.baseUrl}/gruas').replace(
      queryParameters: access.queryParameters.isEmpty
          ? null
          : access.queryParameters,
    );

    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errorText(res));
    }

    final raw = jsonDecode(_decodeBody(res));
    final list = raw is Map && raw['data'] is List
        ? raw['data'] as List
        : raw is List
        ? raw
        : const <dynamic>[];

    final gruas = list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => _isAllowedForAccess(item, access))
        .toList();

    gruas.sort((a, b) {
      return displayName(
        a,
      ).toUpperCase().compareTo(displayName(b).toUpperCase());
    });

    return gruas;
  }

  static int? idOf(Map<String, dynamic> grua) {
    final parsed = _toInt(grua['id']);
    return parsed > 0 ? parsed : null;
  }

  static String displayName(
    Map<String, dynamic> grua, {
    String fallbackPrefix = 'GRÚA',
  }) {
    final nombre =
        (grua['nombre'] ?? grua['name'] ?? grua['razon_social'] ?? '')
            .toString()
            .trim();
    if (nombre.isNotEmpty) return nombre;

    final id = idOf(grua);
    return id == null ? fallbackPrefix : '$fallbackPrefix #$id';
  }

  static bool containsId(List<Map<String, dynamic>> gruas, int? id) {
    if (id == null || id <= 0) return false;
    return gruas.any((grua) => idOf(grua) == id);
  }

  static String? findNameById(List<Map<String, dynamic>> gruas, int? id) {
    if (id == null || id <= 0) return null;
    for (final grua in gruas) {
      if (idOf(grua) == id) return displayName(grua);
    }
    return null;
  }

  static List<int> extractUnidadIds(Map<String, dynamic> raw) {
    final ids = <int>{};

    void add(dynamic value) {
      final id = _toInt(value);
      if (id > 0) ids.add(id);
    }

    void scan(dynamic value) {
      if (value == null) return;

      if (value is int || value is double || value is String) {
        add(value);
        return;
      }

      if (value is Map) {
        add(value['unidad_id']);
        add(value['unidad_org_id']);
        add(value['unit_id']);
        add(value['id']);
        scan(value['pivot']);
        scan(value['unidad']);
        scan(value['unidades']);
        return;
      }

      if (value is Iterable) {
        for (final item in value) {
          scan(item);
        }
      }
    }

    scan(raw['unidad_ids']);
    scan(raw['unidades_ids']);
    scan(raw['unidad_id']);
    scan(raw['unidad_org_id']);
    scan(raw['unidad_grua']);
    scan(raw['unidades_gruas']);
    scan(raw['unidadGrua']);
    scan(raw['unidadesGruas']);
    scan(raw['unidades']);
    scan(raw['unidad']);

    return ids.toList()..sort();
  }

  static List<int> extractDelegacionIds(Map<String, dynamic> raw) {
    final ids = <int>{};

    void add(dynamic value) {
      final id = _toInt(value);
      if (id > 0) ids.add(id);
    }

    void scan(dynamic value) {
      if (value == null) return;

      if (value is int || value is double || value is String) {
        add(value);
        return;
      }

      if (value is Map) {
        add(value['delegacion_id']);
        add(value['delegacionId']);
        add(value['id']);
        scan(value['pivot']);
        scan(value['delegacion']);
        scan(value['delegaciones']);
        return;
      }

      if (value is Iterable) {
        for (final item in value) {
          scan(item);
        }
      }
    }

    scan(raw['delegacion_id']);
    scan(raw['delegacionId']);
    scan(raw['delegacion_ids']);
    scan(raw['delegaciones_ids']);
    scan(raw['delegacion_grua']);
    scan(raw['delegaciones_gruas']);
    scan(raw['delegacionGrua']);
    scan(raw['delegacionesGruas']);
    scan(raw['delegaciones']);
    scan(raw['delegacion']);

    return ids.toList()..sort();
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sin token. Inicia sesión otra vez.');
    }

    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<_GruasAccess> _currentAccess() async {
    final fullAccess = await AuthService.hasFullOperationalAccess();
    final unidadId = await AuthService.getUnidadId();
    final delegacionId = await AuthService.getDelegacionId();
    final isDelegaciones = await AuthService.isDelegacionesUser();
    final isSiniestros = await AuthService.isSiniestrosUser();

    int? unidadFiltroId;
    if (!fullAccess) {
      if (isDelegaciones) {
        unidadFiltroId = AuthService.unidadDelegacionesId;
      } else if (isSiniestros) {
        unidadFiltroId = 1;
      } else if (unidadId == 1 ||
          unidadId == AuthService.unidadDelegacionesId) {
        unidadFiltroId = unidadId;
      }
    }

    final params = <String, String>{};
    if (unidadFiltroId != null && unidadFiltroId > 0) {
      params['unidad_id'] = '$unidadFiltroId';
    }
    if (unidadFiltroId == AuthService.unidadDelegacionesId &&
        delegacionId != null &&
        delegacionId > 0) {
      params['delegacion_id'] = '$delegacionId';
    }

    return _GruasAccess(
      hasFullAccess: fullAccess,
      unidadFiltroId: unidadFiltroId,
      delegacionFiltroId: unidadFiltroId == AuthService.unidadDelegacionesId
          ? delegacionId
          : null,
      queryParameters: params,
    );
  }

  static bool _isAllowedForAccess(
    Map<String, dynamic> grua,
    _GruasAccess access,
  ) {
    if (access.hasFullAccess) return true;

    final unidadFiltroId = access.unidadFiltroId;
    if (unidadFiltroId != null && unidadFiltroId > 0) {
      final unidadIds = extractUnidadIds(grua);
      if (unidadIds.isNotEmpty && !unidadIds.contains(unidadFiltroId)) {
        return false;
      }
    }

    final delegacionFiltroId = access.delegacionFiltroId;
    if (delegacionFiltroId != null && delegacionFiltroId > 0) {
      final delegacionIds = extractDelegacionIds(grua);
      if (delegacionIds.isNotEmpty &&
          !delegacionIds.contains(delegacionFiltroId)) {
        return false;
      }
    }

    return true;
  }

  static String _decodeBody(http.Response res) {
    try {
      return utf8.decode(res.bodyBytes);
    } catch (_) {
      return res.body;
    }
  }

  static String _errorText(http.Response res) {
    final body = _decodeBody(res).trim();
    try {
      final raw = jsonDecode(body);
      if (raw is Map) {
        final msg = (raw['message'] ?? '').toString().trim();
        if (msg.isNotEmpty) return msg;
      }
    } catch (_) {}

    if (body.isEmpty ||
        body.startsWith('<!doctype') ||
        body.startsWith('<html')) {
      return 'No se pudieron cargar grúas (HTTP ${res.statusCode}).';
    }
    return 'No se pudieron cargar grúas (HTTP ${res.statusCode}). $body';
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse((value ?? '').toString().trim()) ?? 0;
  }
}

class _GruasAccess {
  final bool hasFullAccess;
  final int? unidadFiltroId;
  final int? delegacionFiltroId;
  final Map<String, String> queryParameters;

  const _GruasAccess({
    required this.hasFullAccess,
    required this.unidadFiltroId,
    required this.delegacionFiltroId,
    required this.queryParameters,
  });
}
