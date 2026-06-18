import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/network_error_helper.dart';
import 'package:seguridad_vial_app/services/network_status_service.dart';

void main() {
  setUp(NetworkStatusService.markOnline);
  tearDown(NetworkStatusService.markOnline);

  test('connectivity failures use the offline capture message', () {
    final message = NetworkErrorHelper.friendlyMessage(
      const SocketException('Failed host lookup'),
    );

    expect(message, NetworkErrorHelper.offlineCaptureMessage);
    expect(NetworkStatusService.isOffline.value, isTrue);
    expect(
      NetworkStatusService.offlineMessage.value,
      NetworkStatusService.defaultOfflineMessage,
    );
  });

  test('non-network errors keep their cleaned message', () {
    final message = NetworkErrorHelper.friendlyMessage(
      Exception('Validación del servidor'),
    );

    expect(message, 'Validación del servidor');
    expect(NetworkStatusService.isOffline.value, isFalse);
  });
}
