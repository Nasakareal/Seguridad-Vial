import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/account_settings_service.dart';

void main() {
  test('account settings decodes backend boolean representations', () {
    expect(
      AccountSettings.fromJson(const {'receive_waze_alerts': true})
          .receiveWazeAlerts,
      isTrue,
    );
    expect(
      AccountSettings.fromJson(const {'receive_waze_alerts': 1})
          .receiveWazeAlerts,
      isTrue,
    );
    expect(
      AccountSettings.fromJson(const {'receive_waze_alerts': false})
          .receiveWazeAlerts,
      isFalse,
    );
  });
}
