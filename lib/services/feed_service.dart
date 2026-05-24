import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/feed_item.dart';
import 'auth_service.dart';
import 'guardianes_camino_dispositivos_service.dart';

class _FeedDelegacionContext {
  final int? id;
  final String? nombre;

  const _FeedDelegacionContext({this.id, this.nombre});

  bool get isEmpty => id == null && (nombre == null || nombre!.trim().isEmpty);
}

class FeedUnidad {
  final int id;
  final String nombre;
  final String slug;

  const FeedUnidad({
    required this.id,
    required this.nombre,
    required this.slug,
  });
}

class FeedResponse {
  final List<FeedItem> items;
  final bool puedeFiltrarUnidades;
  final List<int> unidadIdsAplicadas;
  final List<FeedUnidad> unidadesFiltrables;

  const FeedResponse({
    required this.items,
    required this.puedeFiltrarUnidades,
    required this.unidadIdsAplicadas,
    required this.unidadesFiltrables,
  });
}

class FeedService {
  static final Map<int, _FeedDelegacionContext?> _delegacionByUserIdCache =
      <int, _FeedDelegacionContext?>{};

  static Future<FeedResponse> fetchFeed({
    required int limit,
    DateTime? date,
    int? unidadId,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No autenticado (token vacío).');
    }

    final safeLimit = limit.clamp(1, 50);
    final delegacionFilterId = await AuthService.getFeedDelegacionFilterId();
    final delegacionFilterContext = await _feedDelegacionContext(
      delegacionFilterId,
    );

    final query = <String, String>{'limit': safeLimit.toString()};

    if (date != null) {
      String two(int x) => x.toString().padLeft(2, '0');
      final ymd = '${date.year}-${two(date.month)}-${two(date.day)}';
      query['date'] = ymd;
    }

    if (unidadId != null && unidadId > 0) {
      query['unidad_ids'] = unidadId.toString();
      query['unidad_id'] = unidadId.toString();
    }

    if (delegacionFilterId != null && delegacionFilterId > 0) {
      query['delegacion_id'] = delegacionFilterId.toString();
      query['delegacion_ids'] = delegacionFilterId.toString();
    }

    final uri = Uri.parse(
      '${AuthService.baseUrl}/feed',
    ).replace(queryParameters: query);

    final resp = await http.get(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (resp.statusCode == 401) {
      throw Exception('No autorizado (401).');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Error HTTP ${resp.statusCode}');
    }

    final decoded = json.decode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      return const FeedResponse(
        items: <FeedItem>[],
        puedeFiltrarUnidades: false,
        unidadIdsAplicadas: <int>[],
        unidadesFiltrables: <FeedUnidad>[],
      );
    }

    final data = decoded['data'];

    final out = <FeedItem>[];
    if (data is List) {
      for (final e in data) {
        if (e is Map<String, dynamic>) {
          final item = _withDelegacionFallback(
            FeedItem.fromJson(e),
            delegacionFilterContext,
          );
          if (_isAllowedByDelegacionFilter(item, delegacionFilterId)) {
            out.add(item);
          }
        }
      }
    }

    final rawUnidadIds = decoded['unidad_ids_aplicadas'];
    final unidadIds = <int>[];
    if (rawUnidadIds is List) {
      for (final value in rawUnidadIds) {
        final parsed = int.tryParse('${value ?? ''}');
        if (parsed != null && parsed > 0) unidadIds.add(parsed);
      }
    }

    final unidadesFiltrables = _parseUnidadesFiltrables(
      decoded['unidades_filtrables'],
      fallbackIds: unidadIds,
    );

    final withDelegaciones = await _hydrateDelegacionesFromUsers(out);
    final items = await _hydrateCarreterasFotos(withDelegaciones, date: date);

    return FeedResponse(
      items: items,
      puedeFiltrarUnidades: decoded['puede_filtrar_unidades'] == true,
      unidadIdsAplicadas: unidadIds.toSet().toList()..sort(),
      unidadesFiltrables: unidadesFiltrables,
    );
  }

  static bool _isAllowedByDelegacionFilter(
    FeedItem item,
    int? delegacionFilterId,
  ) {
    if (delegacionFilterId == null || delegacionFilterId <= 0) {
      return true;
    }

    final itemDelegacionId = item.delegacionId;
    return itemDelegacionId == null || itemDelegacionId == delegacionFilterId;
  }

  static Future<List<FeedItem>> _hydrateCarreterasFotos(
    List<FeedItem> items, {
    DateTime? date,
  }) async {
    final missingIds = items
        .where(
          (item) =>
              item.type == FeedItemType.carreteras &&
              item.id > 0 &&
              (item.fotoUrl == null || item.fotoUrl!.trim().isEmpty),
        )
        .map((item) => item.id)
        .toSet();

    if (missingIds.isEmpty) return items;

    final fotoById = <int, String>{};

    if (date != null) {
      try {
        final index = await GuardianesCaminoDispositivosService.fetchIndex(
          fecha: date,
          perPage: 100,
        );
        for (final dispositivo in index.items) {
          if (!missingIds.contains(dispositivo.id)) continue;
          if (dispositivo.fotoUrls.isEmpty) continue;

          final foto = dispositivo.fotoUrls.first.trim();
          if (foto.isNotEmpty) fotoById[dispositivo.id] = foto;
        }
      } catch (_) {}
    }

    final remainingIds = missingIds
        .where((id) => !fotoById.containsKey(id))
        .take(12)
        .toList();

    if (remainingIds.isNotEmpty) {
      await Future.wait(
        remainingIds.map((id) async {
          try {
            final dispositivo =
                await GuardianesCaminoDispositivosService.fetchDispositivo(
                  dispositivoId: id,
                );
            if (dispositivo.fotoUrls.isEmpty) return;

            final foto = dispositivo.fotoUrls.first.trim();
            if (foto.isNotEmpty) fotoById[id] = foto;
          } catch (_) {}
        }),
      );
    }

    if (fotoById.isEmpty) return items;

    return items.map((item) {
      final foto = fotoById[item.id];
      if (foto == null || foto.trim().isEmpty) return item;
      return item.copyWith(fotoUrl: foto.trim());
    }).toList();
  }

  static Future<List<FeedItem>> _hydrateDelegacionesFromUsers(
    List<FeedItem> items,
  ) async {
    final userIds = items
        .where(_needsDelegacionHydration)
        .map((item) => item.userId)
        .where((id) => id > 0)
        .toSet()
        .take(12)
        .toList();

    if (userIds.isEmpty) return items;

    final contexts = <int, _FeedDelegacionContext?>{};
    await Future.wait(
      userIds.map((userId) async {
        contexts[userId] = await _fetchUserDelegacionContext(userId);
      }),
    );

    if (contexts.values.every(
      (context) => context == null || context.isEmpty,
    )) {
      return items;
    }

    return items.map((item) {
      if (!_needsDelegacionHydration(item)) return item;

      final context = contexts[item.userId];
      if (context == null || context.isEmpty) return item;

      return _withDelegacionFallback(item, context);
    }).toList();
  }

  static bool _needsDelegacionHydration(FeedItem item) {
    return item.userId > 0 &&
        item.delegacionId == null &&
        (item.delegacionNombre == null ||
            item.delegacionNombre!.trim().isEmpty) &&
        _isDelegacionesItem(item);
  }

  static bool _isDelegacionesItem(FeedItem item) {
    if (item.unidadId == AuthService.unidadDelegacionesId) return true;

    final unidad = (item.unidadLabel ?? '').toUpperCase();
    return unidad.contains('DELEGACION') || unidad.contains('DELEGACIÓN');
  }

  static FeedItem _withDelegacionFallback(
    FeedItem item,
    _FeedDelegacionContext? context,
  ) {
    if (context == null || context.isEmpty) return item;
    if (!_isDelegacionesItem(item)) return item;
    if (item.delegacionId != null ||
        (item.delegacionNombre ?? '').trim().isNotEmpty) {
      return item;
    }

    return item.copyWith(
      delegacionId: context.id,
      delegacionNombre: context.nombre,
    );
  }

  static Future<_FeedDelegacionContext?> _feedDelegacionContext(
    int? delegacionFilterId,
  ) async {
    if (delegacionFilterId == null || delegacionFilterId <= 0) {
      return null;
    }

    final payload = await AuthService.getStoredUserPayload();
    final context = _delegacionContextFromPayload(payload);

    if (context != null && context.id == delegacionFilterId) {
      return context;
    }

    return _FeedDelegacionContext(id: delegacionFilterId);
  }

  static Future<_FeedDelegacionContext?> _fetchUserDelegacionContext(
    int userId,
  ) async {
    if (_delegacionByUserIdCache.containsKey(userId)) {
      return _delegacionByUserIdCache[userId];
    }

    try {
      final token = await AuthService.getToken();
      if (token == null || token.trim().isEmpty) {
        _delegacionByUserIdCache[userId] = null;
        return null;
      }

      final resp = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/settings/users/$userId'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        _delegacionByUserIdCache[userId] = null;
        return null;
      }

      final decoded = json.decode(resp.body);
      final context = _delegacionContextFromPayload(decoded);
      _delegacionByUserIdCache[userId] = context;
      return context;
    } catch (_) {
      _delegacionByUserIdCache[userId] = null;
      return null;
    }
  }

  static _FeedDelegacionContext? _delegacionContextFromPayload(dynamic raw) {
    if (raw == null) return null;

    if (raw is Map) {
      final id = _readPositiveInt(
        raw['delegacion_id'] ??
            raw['delegacionId'] ??
            raw['delegacion_org_id'] ??
            raw['delegacionOrgId'],
      );
      final nombre =
          _readText(
            raw['delegacion_nombre_con_clave'] ??
                raw['delegacionNombreConClave'] ??
                raw['delegacion_nombre'] ??
                raw['delegacionNombre'] ??
                raw['nombre_delegacion'] ??
                raw['nombreDelegacion'],
          ) ??
          _delegacionNameFromObject(raw['delegacion']) ??
          _delegacionNameFromObject(raw['delegacion_meta']) ??
          _delegacionNameFromObject(raw['delegacionMeta']);

      if (id != null || nombre != null) {
        return _FeedDelegacionContext(id: id, nombre: nombre);
      }

      for (final key in const <String>[
        'data',
        'user',
        'user_meta',
        'usuario',
        'created_by_user',
      ]) {
        final nested = _delegacionContextFromPayload(raw[key]);
        if (nested != null && !nested.isEmpty) return nested;
      }
    }

    return null;
  }

  static String? _delegacionNameFromObject(dynamic raw) {
    if (raw is Map) {
      return _readText(
        raw['nombre_con_clave'] ??
            raw['nombreConClave'] ??
            raw['nombre'] ??
            raw['name'] ??
            raw['label'],
      );
    }

    return _readText(raw);
  }

  static int? _readPositiveInt(dynamic value) {
    final parsed = int.tryParse('${value ?? ''}');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static String? _readText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static List<FeedUnidad> _parseUnidadesFiltrables(
    dynamic raw, {
    required List<int> fallbackIds,
  }) {
    final unidades = <FeedUnidad>[];

    if (raw is List) {
      for (final value in raw) {
        if (value is Map) {
          final id = int.tryParse('${value['id'] ?? ''}');
          if (id == null || id <= 0) continue;

          final nombre = (value['nombre'] ?? '').toString().trim();
          final slug = (value['slug'] ?? '').toString().trim();
          unidades.add(
            FeedUnidad(
              id: id,
              nombre: nombre.isEmpty ? _fallbackUnidadNombre(id) : nombre,
              slug: slug,
            ),
          );
        }
      }
    }

    if (unidades.isEmpty) {
      for (final id in fallbackIds.toSet()) {
        unidades.add(
          FeedUnidad(id: id, nombre: _fallbackUnidadNombre(id), slug: ''),
        );
      }
    }

    unidades.sort((a, b) => a.id.compareTo(b.id));
    return unidades;
  }

  static String _fallbackUnidadNombre(int id) {
    switch (id) {
      case 1:
        return 'SINIESTROS';
      case 2:
        return 'DELEGACIONES';
      case 3:
        return 'SEGURIDAD VIAL';
      case 4:
        return 'PROTECCION A CARRETERAS';
      case 5:
        return 'PROTECCION A VIALIDADES URBANAS';
      case 6:
        return 'FOMENTO A LA CULTURA VIAL';
      default:
        return 'UNIDAD $id';
    }
  }
}
