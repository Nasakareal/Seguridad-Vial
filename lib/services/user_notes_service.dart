import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user_note.dart';
import 'auth_service.dart';

class UserNotesService {
  static const Duration _timeout = Duration(seconds: 15);

  static Future<List<UserNote>> fetchNotes({String? query}) async {
    final uri = Uri.parse('${AuthService.baseUrl}/notes').replace(
      queryParameters: query == null || query.trim().isEmpty
          ? null
          : <String, String>{'q': query.trim()},
    );
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(_timeout);
    final data = _decodeSuccess(response);
    final raw = data is Map ? data['data'] : data;
    if (raw is! List) return const <UserNote>[];

    return raw
        .whereType<Map>()
        .map((item) => UserNote.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static Future<UserNote> save({
    int? id,
    required String title,
    required String content,
    required String color,
    required bool isPinned,
    required List<NoteHighlight> highlights,
  }) async {
    final uri = Uri.parse(
      id == null
          ? '${AuthService.baseUrl}/notes'
          : '${AuthService.baseUrl}/notes/$id',
    );
    final body = jsonEncode(<String, dynamic>{
      'title': title.trim().isEmpty ? null : title.trim(),
      'content': content.isEmpty ? null : content,
      'color': NotePalette.normalizeCardColor(color),
      'is_pinned': isPinned,
      'highlights': highlights.map((item) => item.toJson()).toList(),
    });
    final headers = await _headers(jsonBody: true);
    final response = id == null
        ? await http.post(uri, headers: headers, body: body).timeout(_timeout)
        : await http.put(uri, headers: headers, body: body).timeout(_timeout);
    final data = _decodeSuccess(response);
    final raw = data is Map ? data['data'] : null;
    if (raw is! Map) {
      throw Exception('El servidor no devolvió la nota guardada.');
    }
    return UserNote.fromJson(Map<String, dynamic>.from(raw));
  }

  static Future<void> delete(int id) async {
    final response = await http
        .delete(
          Uri.parse('${AuthService.baseUrl}/notes/$id'),
          headers: await _headers(),
        )
        .timeout(_timeout);
    _decodeSuccess(response);
  }

  static Future<Map<String, String>> _headers({bool jsonBody = false}) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('La sesión terminó. Inicia sesión nuevamente.');
    }
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (jsonBody) 'Content-Type': 'application/json',
    };
  }

  static dynamic _decodeSuccess(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String? message;
    if (decoded is Map) {
      final errors = decoded['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            message = value.first.toString();
            break;
          }
        }
      }
      message ??= decoded['message']?.toString();
    }
    throw Exception(
      message?.trim().isNotEmpty == true
          ? message!.trim()
          : 'No se pudo completar la operación (${response.statusCode}).',
    );
  }
}
