import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/feed_item.dart';
import 'auth_service.dart';

class FeedService {
  static Future<List<FeedItem>> fetchFeed({
    required int limit,
    DateTime? date,
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
    if (decoded is! Map<String, dynamic>) return [];

    final data = decoded['data'];
    if (data is! List) return [];

    final out = <FeedItem>[];
    for (final e in data) {
      if (e is Map<String, dynamic>) {
        out.add(FeedItem.fromJson(e));
      }
    }
    return out;
  }
}
