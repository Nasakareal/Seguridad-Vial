enum FeedItemType { hecho, actividad }

class FeedItem {
  final FeedItemType type;
  final int id;
  final int userId;
  final String userName;
  final String resumen;
  final String? fotoUrl;
  final DateTime? createdAt;
  final String? showUrl;

  const FeedItem({
    required this.type,
    required this.id,
    required this.userId,
    required this.userName,
    required this.resumen,
    required this.fotoUrl,
    required this.createdAt,
    required this.showUrl,
  });

  static FeedItemType _parseType(dynamic v) {
    final s = (v ?? '').toString().trim().toUpperCase();
    if (s == 'HECHO') return FeedItemType.hecho;
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

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      type: _parseType(json['type']),
      id: _asInt(json['id']),
      userId: _asInt(json['user_id']),
      userName: (json['user_name'] ?? '').toString(),
      resumen: (json['resumen'] ?? '').toString(),
      fotoUrl: (json['foto_url'] == null) ? null : json['foto_url'].toString(),
      createdAt: _parseDate(json['created_at']),
      showUrl: (json['show_url'] == null) ? null : json['show_url'].toString(),
    );
  }
}
