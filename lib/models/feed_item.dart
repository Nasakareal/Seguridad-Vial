enum FeedItemType { hecho, actividad, carreteras, vialidades }

class FeedItem {
  final FeedItemType type;
  final int id;
  final int userId;
  final String userName;
  final String resumen;
  final String? categoriaNombre;
  final String? subcategoriaNombre;
  final String? fotoUrl;
  final DateTime? createdAt;
  final String? showUrl;
  final int? unidadId;

  const FeedItem({
    required this.type,
    required this.id,
    required this.userId,
    required this.userName,
    required this.resumen,
    required this.categoriaNombre,
    required this.subcategoriaNombre,
    required this.fotoUrl,
    required this.createdAt,
    required this.showUrl,
    required this.unidadId,
  });

  FeedItem copyWith({String? fotoUrl}) {
    return FeedItem(
      type: type,
      id: id,
      userId: userId,
      userName: userName,
      resumen: resumen,
      categoriaNombre: categoriaNombre,
      subcategoriaNombre: subcategoriaNombre,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      createdAt: createdAt,
      showUrl: showUrl,
      unidadId: unidadId,
    );
  }

  static FeedItemType _parseType(dynamic v) {
    final s = (v ?? '').toString().trim().toUpperCase();
    if (s == 'HECHO') return FeedItemType.hecho;
    if (s == 'CARRETERAS') return FeedItemType.carreteras;
    if (s == 'VIALIDADES') return FeedItemType.vialidades;
    return FeedItemType.actividad;
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static String? _asNullableString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      type: _parseType(json['type']),
      id: _asInt(json['id']),
      userId: _asInt(json['user_id']),
      userName: (json['user_name'] ?? '').toString(),
      resumen: (json['resumen'] ?? '').toString(),
      categoriaNombre: _asNullableString(
        json['categoria_nombre'] ?? json['categoria'] ?? json['category_name'],
      ),
      subcategoriaNombre: _asNullableString(
        json['subcategoria_nombre'] ??
            json['subcategoria'] ??
            json['subcategory_name'],
      ),
      fotoUrl: _asNullableString(
        json['foto_url'] ??
            json['fotoUrl'] ??
            json['photo_url'] ??
            json['image_url'] ??
            json['foto'] ??
            json['foto_path'],
      ),
      createdAt: _parseDate(json['created_at']),
      showUrl: (json['show_url'] == null) ? null : json['show_url'].toString(),
      unidadId: json['unidad_id'] == null ? null : _asInt(json['unidad_id']),
    );
  }
}
