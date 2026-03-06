import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';

class HechoShowHelpers {
  static const List<String> sectorOptions = [
    'REVOLUCIÓN',
    'NUEVA ESPAÑA',
    'INDEPENDENCIA',
    'REPÚBLICA',
    'CENTRO',
  ];

  static const List<String> situacionOptions = [
    'RESUELTO',
    'PENDIENTE',
    'TURNADO',
    'REPORTE',
  ];

  static int hechoIdFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    int parse(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    if (args == null) return 0;

    final direct = parse(args);
    if (direct > 0) return direct;

    if (args is Map) {
      final candidates = [
        args['hechoId'],
        args['hecho_id'],
        args['id'],
        args['item_id'],
      ];

      for (final c in candidates) {
        final id = parse(c);
        if (id > 0) return id;
      }
    }

    return 0;
  }

  static String safeText(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '—' : s;
  }

  static String safeBool01(dynamic v) {
    if (v == null) return '—';
    final s = v.toString().trim();
    if (s.isEmpty) return '—';
    if (s == '1' || s.toLowerCase() == 'true') return 'Sí';
    if (s == '0' || s.toLowerCase() == 'false') return 'No';
    return s;
  }

  static String normalizeSector(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    if (sectorOptions.contains(s)) return s;

    final upper = s.toUpperCase();
    for (final opt in sectorOptions) {
      if (upper.contains(opt.toUpperCase())) return opt;
    }
    return s.toUpperCase();
  }

  static String normalizeSituacion(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    if (situacionOptions.contains(s)) return s;

    final upper = s.toUpperCase();
    for (final opt in situacionOptions) {
      if (upper.contains(opt)) return opt;
    }
    return s.toUpperCase();
  }

  static String toPublicUrl(String pathOrUrl) {
    final p = pathOrUrl.trim();
    if (p.isEmpty) return '';

    final lower = p.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return p;

    final root = AuthService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    if (p.startsWith('/storage/')) return '$root$p';
    if (p.startsWith('storage/')) return '$root/$p';
    return '$root/storage/$p';
  }

  static List<Map<String, dynamic>> vehiculosFromHecho(
    Map<String, dynamic>? hecho,
  ) {
    final v = hecho?['vehiculos'];

    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (v is Map) {
      final data = v['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    return const [];
  }

  static List<String> fotosVehiculosFromHecho(Map<String, dynamic>? hecho) {
    final vehs = vehiculosFromHecho(hecho);
    final out = <String>[];

    for (final v in vehs) {
      final fotosUrl = v['fotos_url'];
      if (fotosUrl is String && fotosUrl.trim().isNotEmpty) {
        out.add(fotosUrl.trim());
        continue;
      }

      final fotos = v['fotos'];
      if (fotos == null) continue;

      if (fotos is List) {
        for (final x in fotos) {
          final s = (x ?? '').toString().trim();
          if (s.isNotEmpty) out.add(toPublicUrl(s));
        }
        continue;
      }

      if (fotos is String) {
        final s = fotos.trim();
        if (s.isEmpty) continue;

        if (s.startsWith('[') && s.endsWith(']')) {
          try {
            final decoded = jsonDecode(s);
            if (decoded is List) {
              for (final x in decoded) {
                final ss = (x ?? '').toString().trim();
                if (ss.isNotEmpty) out.add(toPublicUrl(ss));
              }
              continue;
            }
          } catch (_) {}
        }

        out.add(toPublicUrl(s));
      }
    }

    final uniq = <String>{};
    final cleaned = <String>[];
    for (final u in out) {
      final uu = u.trim();
      if (uu.isEmpty) continue;
      if (uniq.add(uu)) cleaned.add(uu);
    }
    return cleaned;
  }

  static String fotoLugarUrl(Map<String, dynamic>? hecho) {
    final h = hecho ?? {};
    final raw =
        (h['foto_lugar_url'] ?? h['foto_lugar_path'] ?? h['foto_lugar'] ?? '')
            .toString()
            .trim();
    return raw.isEmpty ? '' : toPublicUrl(raw);
  }

  static String fotoSituacionUrl(Map<String, dynamic>? hecho) {
    final h = hecho ?? {};
    final raw =
        (h['foto_situacion_url'] ??
                h['foto_situacion_path'] ??
                h['foto_situacion'] ??
                '')
            .toString()
            .trim();
    return raw.isEmpty ? '' : toPublicUrl(raw);
  }
}
