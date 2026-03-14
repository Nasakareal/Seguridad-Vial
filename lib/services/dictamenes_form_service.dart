import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/dictamen_item.dart';
import 'dictamenes_service.dart';

class DictamenesFormService {
  DictamenesFormService(this.api);

  final DictamenesService api;

  static const String _cachePrefix = 'dictamenes_form_cache_v1';

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String _label(Map<String, dynamic> m) {
    final num = _asString(
      m['numero_dictamen'] ?? m['numero'] ?? m['no_dictamen'],
    );
    final anio = _asInt(m['anio']);
    final mp = _asString(m['nombre_mp']);

    final parts = <String>[];
    if (num != null && anio != null) {
      parts.add('$num/$anio');
    } else if (num != null) {
      parts.add(num);
    } else {
      parts.add('SIN NÚMERO');
    }

    if (mp != null) parts.add(mp);
    return parts.join(' ');
  }

  DictamenItem? _map(Map<String, dynamic> m) {
    final id = _asInt(m['id']);
    if (id == null) return null;

    return DictamenItem(
      id: id,
      label: _label(m),
      numeroDictamen: _asString(
        m['numero_dictamen'] ?? m['numero'] ?? m['no_dictamen'],
      ),
      anio: _asInt(m['anio']),
      nombrePolicia: _asString(m['nombre_policia']),
      nombreMp: _asString(m['nombre_mp']),
      area: _asString(m['area']),
      archivoDictamen: _asString(m['archivo_dictamen']),
      createdBy: _asInt(m['created_by']),
      updatedBy: _asInt(m['updated_by']),
    );
  }

  List<dynamic> _extractList(dynamic raw) {
    if (raw is List) return raw;

    if (raw is Map<String, dynamic>) {
      final cands = <dynamic>[raw['data'], raw['dictamenes'], raw['items']];
      for (final c in cands) {
        if (c is List) return c;
        if (c is Map && c['data'] is List) return c['data'] as List;
      }
    }
    return const <dynamic>[];
  }

  Future<List<DictamenItem>> fetchAll({int? anio}) async {
    final cacheKey = anio == null ? _cachePrefix : '${_cachePrefix}_$anio';

    try {
      final raw = await api.index(anio: anio);
      final list = _extractList(
        raw,
      ).whereType<Map>().map((it) => Map<String, dynamic>.from(it)).toList();
      await _saveCache(cacheKey, list);
      return _mapItems(list);
    } catch (e) {
      final cached = await _loadCache(cacheKey);
      if (cached.isNotEmpty) {
        return _mapItems(cached);
      }
      rethrow;
    }
  }

  List<DictamenItem> _mapItems(List<Map<String, dynamic>> list) {
    final out = <DictamenItem>[];
    for (final it in list) {
      final item = _map(it);
      if (item != null) out.add(item);
    }

    out.sort((a, b) => a.label.compareTo(b.label));
    return out;
  }

  Future<void> _saveCache(String key, List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(items));
  }

  Future<List<Map<String, dynamic>>> _loadCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty)
      return const <Map<String, dynamic>>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }
}
