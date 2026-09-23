import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'network_status_service.dart';

class NetworkErrorHelper {
  static const Duration interactiveRequestTimeout = Duration(seconds: 8);

  static const String offlineCaptureMessage =
      'Sin conexión estable. Puedes seguir capturando; lo que guardes se quedará pendiente y se sincronizará cuando vuelva la señal.';

  static const String missingLocalFileMessage =
      'Una fotografía o archivo seleccionado ya no está disponible en el dispositivo. Vuelve a seleccionarlo e intenta guardar otra vez.';

  static bool isConnectivityIssue(Object error) {
    if (error is TimeoutException ||
        error is SocketException ||
        error is HandshakeException ||
        error is http.ClientException) {
      return true;
    }

    final raw = error.toString().toLowerCase();
    return raw.contains('socketexception') ||
        raw.contains('timeoutexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('host lookup') ||
        raw.contains('connection timed out') ||
        raw.contains('connection timeout') ||
        raw.contains('timed out') ||
        raw.contains('connection reset') ||
        raw.contains('connection refused') ||
        raw.contains('network is unreachable') ||
        raw.contains('software caused connection abort') ||
        raw.contains('no address associated with hostname') ||
        raw.contains('xmlhttprequest error');
  }

  static String friendlyMessage(
    Object error, {
    String fallback = 'Ocurrió un error inesperado.',
  }) {
    final raw = error.toString().trim();
    final lower = raw.toLowerCase();
    final isMissingLocalFile =
        error is FileSystemException && error.osError?.errorCode == 2 ||
        lower.contains('pathnotfoundexception') ||
        lower.contains('no such file or directory') ||
        lower.contains('cannot retrieve length of file');
    if (isMissingLocalFile) return missingLocalFileMessage;

    if (isConnectivityIssue(error)) {
      NetworkStatusService.markOffline();
      return offlineCaptureMessage;
    }

    if (raw.isEmpty) return fallback;

    final cleaned = raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }
}
