import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// Test-only replacement of path_provider's existing platform interface.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seguridad_vial_app/services/response_route_recorder.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'persists offline samples, isolates accounts and deletes only acknowledged uploads',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'response-route-test-',
      );
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      try {
        SharedPreferences.setMockInitialValues({
          'auth_token': 'test-token',
          'auth_user_id': 7,
          'auth_unidad_id': 1,
          'auth_user_payload': '{"id":7,"unidad_id":1,"patrulla_id":174}',
        });
        var status = 503;
        final received = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          received.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            status == 200
                ? jsonEncode({
                    'acknowledged': (received.last['points'] as List).length,
                  })
                : '{}',
            status,
          );
        });
        await http.runWithClient(() async {
          final capture = DateTime.now().toUtc().subtract(
            const Duration(seconds: 2),
          );
          await ResponseRouteRecorder.record(
            Position(
              latitude: 19.706,
              longitude: -101.191,
              timestamp: capture,
              accuracy: 8,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            ),
            apiBase: 'https://example.test/api',
          );
          await ResponseRouteRecorder.flushPending(
            apiBase: 'https://example.test/api',
          );
          final pending = Directory('${directory.path}/response_routes/7');
          expect(await pending.list().length, 1);
          expect(
            (received.first['points'] as List).first['captured_at'],
            capture.toIso8601String(),
          );
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('auth_user_id', 8);
          final before = received.length;
          status = 200;
          await ResponseRouteRecorder.flushPending(
            apiBase: 'https://example.test/api',
          );
          expect(received.length, before);
          expect(await pending.list().length, 1);
          await prefs.setInt('auth_user_id', 7);
          await ResponseRouteRecorder.flushPending(
            apiBase: 'https://example.test/api',
          );
          expect(await pending.list().length, 0);
          await prefs.setInt('auth_unidad_id', 2);
          await ResponseRouteRecorder.record(
            Position(
              latitude: 19.706,
              longitude: -101.191,
              timestamp: DateTime.now().toUtc(),
              accuracy: 8,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            ),
            apiBase: 'https://example.test/api',
          );
          expect(await pending.list().length, 0);
        }, () => client);
      } finally {
        PathProviderPlatform.instance = original;
        await directory.delete(recursive: true);
      }
    },
  );
}
