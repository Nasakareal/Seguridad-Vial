import 'package:flutter/foundation.dart';

class NetworkStatusService {
  static const String defaultOfflineMessage =
      'Estás sin conexión. Puedes seguir capturando; lo pendiente se enviará cuando vuelva la señal.';

  static final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);
  static final ValueNotifier<String> offlineMessage = ValueNotifier<String>(
    defaultOfflineMessage,
  );

  static void markOffline([String? message]) {
    final trimmed = message?.trim() ?? '';
    offlineMessage.value = trimmed.isEmpty ? defaultOfflineMessage : trimmed;
    if (!isOffline.value) {
      isOffline.value = true;
    }
  }

  static void markOnline() {
    offlineMessage.value = defaultOfflineMessage;
    if (isOffline.value) {
      isOffline.value = false;
    }
  }
}
