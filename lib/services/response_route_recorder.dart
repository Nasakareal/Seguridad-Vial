import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'auth_service.dart';

/// Durable, account-scoped GPS outbox. Each sample is independent so foreground
/// and background isolates cannot overwrite each other's pending samples.
class ResponseRouteRecorder {
  static bool _flushing = false;
  static DateTime? _lastAttempt;
  static String? _lastBucket;
  static Future<void>? _activeFlush;

  static Future<void> record(
    Position position, {
    required String apiBase,
  }) async {
    if (await AuthService.getUnidadId() != 1) return;
    final userId = await AuthService.getUserId();
    if (userId == null ||
        !position.accuracy.isFinite ||
        position.accuracy < 0 ||
        position.accuracy > 100) {
      return;
    }
    final age = DateTime.now().difference(position.timestamp);
    if (age.isNegative || age >= const Duration(minutes: 2)) return;
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/response_routes/$userId');
    await directory.create(recursive: true);
    // Limit stream volume; immutable files make uploads safe across isolates.
    final bucket = position.timestamp.millisecondsSinceEpoch ~/ 15000;
    final bucketKey = '$userId:$bucket';
    if (_lastBucket != bucketKey) {
      final name =
          '${position.timestamp.microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
      final file = File('${directory.path}/$name.pending');
      final payload = await AuthService.getStoredUserPayload();
      final personal = payload?['personal'];
      final patrolId = personal is Map && personal['patrulla_id'] != null
          ? personal['patrulla_id']
          : payload?['patrulla_id'];
      await file.writeAsString(
        jsonEncode({
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy': position.accuracy,
          'captured_at': position.timestamp.toUtc().toIso8601String(),
          if (patrolId != null) 'patrulla_id': patrolId,
        }),
        flush: true,
      );
      await file.rename('${directory.path}/$name.json');
      _lastBucket = bucketKey;
    }
    // Saving never waits for the network; a slow request cannot stop GPS capture.
    if (!_flushing &&
        (_lastAttempt == null ||
            DateTime.now().difference(_lastAttempt!) >=
                const Duration(seconds: 40))) {
      _activeFlush = _flush(directory, apiBase, userId);
    }
  }

  static Future<void> flushPending({required String apiBase}) async {
    if (_flushing) {
      await _activeFlush;
      return;
    }
    if (await AuthService.getUnidadId() != 1) return;
    final userId = await AuthService.getUserId();
    if (userId == null) return;
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/response_routes/$userId');
    if (!await directory.exists()) return;
    _activeFlush = _flush(directory, apiBase, userId);
    await _activeFlush;
  }

  static Future<void> _flush(
    Directory directory,
    String apiBase,
    int userId,
  ) async {
    _flushing = true;
    _lastAttempt = DateTime.now();
    try {
      final token = await AuthService.getToken();
      if (token == null || await AuthService.getUserId() != userId) return;
      final files = await directory
          .list()
          .where((entry) => entry is File && entry.path.endsWith('.json'))
          .cast<File>()
          .toList();
      files.sort((a, b) => a.path.compareTo(b.path));
      final batch = files.take(200).toList();
      if (batch.isEmpty) return;
      final points = <dynamic>[];
      for (final file in batch) {
        points.add(jsonDecode(await file.readAsString()));
      }
      final response = await http
          .post(
            Uri.parse('$apiBase/location/response-route'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'points': points}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return;
      final result = jsonDecode(response.body);
      if (result is! Map || result['acknowledged'] != points.length) return;
      for (final file in batch) {
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      // Keep every unacknowledged sample for the next attempt or app restart.
    } finally {
      _flushing = false;
    }
  }
}
