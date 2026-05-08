import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/delegacion_distance_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('extracts delegation coordinates from nested payload', () {
    final coords = DelegacionDistanceService.coordsFromPayload(
      <String, dynamic>{
        'delegacion': <String, dynamic>{
          'id': 7,
          'nombre': 'Morelia',
          'lat': '19.7000000',
          'lng': '-101.2000000',
        },
      },
    );

    expect(coords, isNotNull);
    expect(coords!.lat, 19.7);
    expect(coords.lng, -101.2);
  });

  test('extracts destacamento coordinates from nested payload', () {
    final coords = DelegacionDistanceService.coordsFromPayload(
      <String, dynamic>{
        'destacamento': <String, dynamic>{
          'id': 3,
          'nombre': 'La Piedad',
          'lat': '20.3350000',
          'lng': '-102.0200000',
        },
      },
    );

    expect(coords, isNotNull);
    expect(coords!.lat, 20.335);
    expect(coords.lng, -102.02);
  });

  test('calculates haversine distance in kilometers', () {
    final distance = DelegacionDistanceService.distanceKm(0, 0, 0, 1);

    expect(distance, closeTo(111.2, 0.2));
  });

  test('uses the backend field name for hechos and actividades', () {
    expect(
      DelegacionDistanceService.kilometrosRecorridosField,
      'km_recorridos',
    );
  });

  test('builds kilometers field value from stored user delegation', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_session_owner_key': 'user:22',
      'auth_user_payload': jsonEncode(<String, Object>{
        'delegacion': <String, Object>{
          'lat': '19.7000000',
          'lng': '-101.2000000',
        },
      }),
    });

    final value =
        await DelegacionDistanceService.distanceFromCurrentDelegacionKmField(
          lat: 19.7,
          lng: -101.1,
        );

    expect(value, isNotNull);
    expect(double.parse(value!), greaterThan(8));
  });

  test('uses the last recent capture as the next origin', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_session_owner_key': 'user:22',
      'auth_user_payload': jsonEncode(<String, Object>{
        'delegacion': <String, Object>{'lat': '0', 'lng': '0'},
      }),
    });

    await DelegacionDistanceService.markCaptureSubmitted(
      lat: 0,
      lng: 1,
      capturedAt: DateTime.utc(2026, 1, 1, 8),
    );

    final value = await DelegacionDistanceService.distanceForNextCaptureKmField(
      lat: 0,
      lng: 2,
      now: DateTime.utc(2026, 1, 1, 9),
    );

    expect(value, isNotNull);
    expect(double.parse(value!), closeTo(111.2, 0.3));
  });

  test('accumulates local mileage between accepted GPS points', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_session_owner_key': 'user:22',
    });

    await DelegacionDistanceService.recordLocalMileagePoint(
      lat: 0,
      lng: 0,
      capturedAt: DateTime.utc(2026, 1, 1, 8),
    );
    await DelegacionDistanceService.recordLocalMileagePoint(
      lat: 0,
      lng: 1,
      accuracyMeters: 12,
      capturedAt: DateTime.utc(2026, 1, 1, 9),
    );

    final value = await DelegacionDistanceService.localMileageForCaptureKmField(
      lat: 0,
      lng: 1,
      capturedAt: DateTime.utc(2026, 1, 1, 9, 1),
    );

    expect(value, isNotNull);
    expect(double.parse(value!), closeTo(111.2, 0.3));
  });

  test('ignores local mileage points with poor accuracy', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_session_owner_key': 'user:22',
    });

    await DelegacionDistanceService.recordLocalMileagePoint(
      lat: 0,
      lng: 0,
      capturedAt: DateTime.utc(2026, 1, 1, 8),
    );
    await DelegacionDistanceService.recordLocalMileagePoint(
      lat: 0,
      lng: 1,
      accuracyMeters: 250,
      capturedAt: DateTime.utc(2026, 1, 1, 9),
    );

    final value = await DelegacionDistanceService.localMileageForCaptureKmField(
      lat: 0,
      lng: 0,
      capturedAt: DateTime.utc(2026, 1, 1, 9, 1),
    );

    expect(value, '0.00');
  });

  test(
    'caps excessive local mileage until the next capture resets it',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_session_owner_key': 'user:22',
      });

      for (var lng = 0; lng <= 5; lng += 1) {
        await DelegacionDistanceService.recordLocalMileagePoint(
          lat: 0,
          lng: lng.toDouble(),
          accuracyMeters: 10,
          capturedAt: DateTime.utc(2026, 1, 1, 8 + lng),
        );
      }

      final capped =
          await DelegacionDistanceService.localMileageForCaptureKmField(
            lat: 0,
            lng: 5,
            capturedAt: DateTime.utc(2026, 1, 1, 13, 1),
          );

      expect(capped, '500.00');

      await DelegacionDistanceService.markCaptureSubmitted(
        lat: 0,
        lng: 5,
        capturedAt: DateTime.utc(2026, 1, 1, 13, 2),
      );

      final reset =
          await DelegacionDistanceService.localMileageForCaptureKmField(
            lat: 0,
            lng: 5,
            capturedAt: DateTime.utc(2026, 1, 1, 13, 3),
          );

      expect(reset, '0.00');
    },
  );

  test('keeps direct base distance even with a recent capture', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_session_owner_key': 'user:22',
      'auth_user_payload': jsonEncode(<String, Object>{
        'delegacion': <String, Object>{'lat': '0', 'lng': '0'},
      }),
    });

    await DelegacionDistanceService.markCaptureSubmitted(
      lat: 0,
      lng: 1,
      capturedAt: DateTime.utc(2026, 1, 1, 8),
    );

    final value =
        await DelegacionDistanceService.distanceFromCurrentDelegacionKmField(
          lat: 0,
          lng: 2,
        );

    expect(value, isNotNull);
    expect(double.parse(value!), closeTo(222.4, 0.3));
  });

  test(
    'returns to delegation origin after 24 hours without captures',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_session_owner_key': 'user:22',
        'auth_user_payload': jsonEncode(<String, Object>{
          'delegacion': <String, Object>{'lat': '0', 'lng': '0'},
        }),
      });

      await DelegacionDistanceService.markCaptureSubmitted(
        lat: 0,
        lng: 1,
        capturedAt: DateTime.utc(2026, 1, 1, 8),
      );

      final value =
          await DelegacionDistanceService.distanceForNextCaptureKmField(
            lat: 0,
            lng: 2,
            now: DateTime.utc(2026, 1, 2, 9),
          );

      expect(value, isNotNull);
      expect(double.parse(value!), closeTo(222.4, 0.3));
    },
  );

  test('returns null when target coordinates are missing', () async {
    final value =
        await DelegacionDistanceService.distanceFromCurrentDelegacionKmField(
          lat: null,
          lng: -101.1,
        );

    expect(value, isNull);
  });
}
