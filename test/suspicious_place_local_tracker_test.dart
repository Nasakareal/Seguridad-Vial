import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/offline_sync_service.dart';
import 'package:seguridad_vial_app/services/suspicious_place_local_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_token': 'test-token',
      'auth_user_id': 99,
      'auth_user_payload': '{"id":99,"unidad_id":1}',
    });
  });

  test(
    'queues dwell and exit events even when network is unavailable',
    () async {
      final events = <Map<String, dynamic>>[];
      final dependencies = <String?>[];
      final start = DateTime.utc(2026, 7, 18, 12);

      Future<OfflineActionResult> sender(
        Map<String, dynamic> body,
        String requestId,
        String? dependency,
      ) async {
        events.add(<String, dynamic>{...body, 'request_id': requestId});
        dependencies.add(dependency);
        return const OfflineActionResult.queued();
      }

      expect(
        await SuspiciousPlaceLocalTracker.processPosition(
          lat: SuspiciousPlaceLocalTracker.latitude,
          lng: SuspiciousPlaceLocalTracker.longitude,
          accuracyMeters: 10,
          capturedAt: start,
          apiBase: 'https://example.test/api',
          eventSender: sender,
        ),
        'entered',
      );
      await SuspiciousPlaceLocalTracker.processPosition(
        lat: SuspiciousPlaceLocalTracker.latitude,
        lng: SuspiciousPlaceLocalTracker.longitude,
        accuracyMeters: 10,
        capturedAt: start.add(const Duration(minutes: 2)),
        apiBase: 'https://example.test/api',
        eventSender: sender,
      );
      expect(
        await SuspiciousPlaceLocalTracker.processPosition(
          lat: SuspiciousPlaceLocalTracker.latitude,
          lng: SuspiciousPlaceLocalTracker.longitude,
          accuracyMeters: 10,
          capturedAt: start.add(const Duration(minutes: 5)),
          apiBase: 'https://example.test/api',
          eventSender: sender,
        ),
        'dwell_submitted',
      );
      for (var minute = 7; minute <= 34; minute += 2) {
        await SuspiciousPlaceLocalTracker.processPosition(
          lat: SuspiciousPlaceLocalTracker.latitude,
          lng: SuspiciousPlaceLocalTracker.longitude,
          accuracyMeters: 10,
          capturedAt: start.add(Duration(minutes: minute)),
          apiBase: 'https://example.test/api',
          eventSender: sender,
        );
      }
      expect(
        await SuspiciousPlaceLocalTracker.processPosition(
          lat: SuspiciousPlaceLocalTracker.latitude + 0.003,
          lng: SuspiciousPlaceLocalTracker.longitude,
          accuracyMeters: 10,
          capturedAt: start.add(const Duration(minutes: 35)),
          apiBase: 'https://example.test/api',
          eventSender: sender,
        ),
        'exit_queued',
      );

      expect(events.map((event) => event['event_type']), <String>[
        'dwell',
        'exit',
      ]);
      expect(events.last['duration_seconds'], 2100);
      expect(events.last['place_key'], 'gruas-munoz');
      expect(dependencies.first, isNull);
      expect(dependencies.last, events.first['request_id']);
    },
  );

  test('does not queue an event for a pass through', () async {
    var calls = 0;
    final start = DateTime.utc(2026, 7, 18, 13);

    Future<OfflineActionResult> sender(
      Map<String, dynamic> body,
      String requestId,
      String? dependency,
    ) async {
      calls++;
      return const OfflineActionResult.queued();
    }

    await SuspiciousPlaceLocalTracker.processPosition(
      lat: SuspiciousPlaceLocalTracker.latitude,
      lng: SuspiciousPlaceLocalTracker.longitude,
      accuracyMeters: 10,
      capturedAt: start,
      apiBase: 'https://example.test/api',
      eventSender: sender,
    );
    final result = await SuspiciousPlaceLocalTracker.processPosition(
      lat: SuspiciousPlaceLocalTracker.latitude + 0.003,
      lng: SuspiciousPlaceLocalTracker.longitude,
      accuracyMeters: 10,
      capturedAt: start.add(const Duration(minutes: 2)),
      apiBase: 'https://example.test/api',
      eventSender: sender,
    );

    expect(result, 'passed_without_dwell');
    expect(calls, 0);
  });
}
