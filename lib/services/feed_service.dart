import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/feed_item.dart';
import 'auth_service.dart';

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
          out.add(FeedItem.fromJson(e));
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

    return FeedResponse(
      items: out,
      puedeFiltrarUnidades: decoded['puede_filtrar_unidades'] == true,
      unidadIdsAplicadas: unidadIds.toSet().toList()..sort(),
      unidadesFiltrables: unidadesFiltrables,
    );
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
