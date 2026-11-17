import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/tracking_task.dart';

void main() {
  test('Siniestros keeps the configured tracking intervals', () {
    expect(
      TrackingTaskHandler.normalIntervalForSpeed(0),
      const Duration(minutes: 3),
    );
    expect(
      TrackingTaskHandler.normalIntervalForSpeed(0.5),
      const Duration(minutes: 3),
    );
    expect(
      TrackingTaskHandler.normalIntervalForSpeed(1),
      const Duration(seconds: 90),
    );
    expect(
      TrackingTaskHandler.normalIntervalForSpeed(2),
      const Duration(seconds: 90),
    );
    expect(
      TrackingTaskHandler.normalIntervalForSpeed(3),
      const Duration(seconds: 40),
    );
  });
}
