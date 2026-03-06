import 'dart:convert';

Map<String, dynamic> safeDecodePayload(String? payload) {
  if (payload == null || payload.trim().isEmpty) return {};
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
  } catch (_) {}
  return {};
}

double? parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}
