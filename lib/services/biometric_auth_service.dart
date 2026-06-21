import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

class BiometricAuthResult {
  final bool allowed;
  final String message;

  const BiometricAuthResult.allowed() : allowed = true, message = '';

  const BiometricAuthResult.denied(this.message) : allowed = false;
}

class BiometricAuthService {
  final LocalAuthentication _auth;

  BiometricAuthService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  Future<BiometricAuthResult> verify({required String localizedReason}) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: false,
        ),
      );

      if (authenticated) return const BiometricAuthResult.allowed();
      return const BiometricAuthResult.denied(
        'Verificación biométrica cancelada. No se puede continuar.',
      );
    } on PlatformException catch (e) {
      return BiometricAuthResult.denied(messageForErrorCode(e.code));
    } catch (_) {
      return const BiometricAuthResult.denied(
        'No se pudo iniciar la verificación biométrica en este dispositivo.',
      );
    }
  }

  static String messageForErrorCode(String code) {
    switch (code) {
      case auth_error.notAvailable:
        return 'Este dispositivo no tiene huella o reconocimiento facial disponible. No se puede usar el módulo de puntos de licencia.';
      case auth_error.notEnrolled:
        return 'Este dispositivo no tiene huella o rostro registrado. Registra biometría en el dispositivo para usar puntos de licencia.';
      case auth_error.passcodeNotSet:
        return 'El dispositivo no tiene bloqueo seguro configurado. Activa bloqueo y biometría para usar puntos de licencia.';
      case auth_error.lockedOut:
        return 'La verificación biométrica está bloqueada temporalmente. Intenta de nuevo más tarde.';
      case auth_error.permanentlyLockedOut:
        return 'La verificación biométrica quedó bloqueada. Desbloquéala desde la configuración del dispositivo.';
      case auth_error.otherOperatingSystem:
        return 'Este sistema no permite verificación biométrica compatible. No se puede usar puntos de licencia.';
      default:
        return 'No se pudo completar la verificación biométrica. No se puede continuar.';
    }
  }
}
