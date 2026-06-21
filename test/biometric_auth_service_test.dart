import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:seguridad_vial_app/services/biometric_auth_service.dart';

void main() {
  group('BiometricAuthService', () {
    test('bloquea dispositivos sin biometria disponible', () {
      final message = BiometricAuthService.messageForErrorCode(
        auth_error.notAvailable,
      );

      expect(message, contains('no tiene huella'));
      expect(message, contains('No se puede usar'));
    });

    test('bloquea dispositivos sin biometria registrada', () {
      final message = BiometricAuthService.messageForErrorCode(
        auth_error.notEnrolled,
      );

      expect(message, contains('no tiene huella o rostro registrado'));
      expect(message, contains('Registra biometría'));
    });

    test('bloquea cancelaciones o errores desconocidos', () {
      final message = BiometricAuthService.messageForErrorCode('cancelled');

      expect(message, contains('No se pudo completar'));
      expect(message, contains('No se puede continuar'));
    });
  });
}
