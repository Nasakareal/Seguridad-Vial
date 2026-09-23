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

  test('missing cached files never expose the technical path', () {
    final message = NetworkErrorHelper.friendlyMessage(
      const FileSystemException(
        'Cannot retrieve length of file',
        '/data/user/0/app/cache/scaled_missing.jpg',
        OSError('No such file or directory', 2),
      ),
    );

    expect(message, NetworkErrorHelper.missingLocalFileMessage);
    expect(message, isNot(contains('/data/user/0')));
    expect(message, isNot(contains('PathNotFoundException')));
  });
}
