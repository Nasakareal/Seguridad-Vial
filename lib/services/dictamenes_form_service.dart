import '../models/dictamen_item.dart';
import 'dictamenes_service.dart';

class DictamenesFormService {
  final DictamenesService api;
  DictamenesFormService(this.api);

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
    if (num != null && anio != null)
      parts.add('$num/$anio');
    else if (num != null)
      parts.add(num);
    else
      parts.add('SIN NÚMERO');

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
      final cands = [raw['data'], raw['dictamenes'], raw['items']];
      for (final c in cands) {
        if (c is List) return c;
        if (c is Map && c['data'] is List) return (c['data'] as List);
      }
    }
    return const [];
  }

  Future<List<DictamenItem>> fetchAll({int? anio}) async {
    final raw = await api.index(anio: anio);
    final list = _extractList(raw);

    final out = <DictamenItem>[];
    for (final it in list) {
      if (it is! Map) continue;
      final item = _map(Map<String, dynamic>.from(it as Map));
      if (item != null) out.add(item);
    }

    out.sort((a, b) => a.label.compareTo(b.label));
    return out;
  }
}
