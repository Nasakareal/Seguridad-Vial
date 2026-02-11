import 'dart:async';
import 'package:flutter/widgets.dart';
import 'push_service.dart';

class PushBootstrap with WidgetsBindingObserver {
  static final PushBootstrap _i = PushBootstrap._();
  PushBootstrap._();

  static Future<void> init() async {
    WidgetsBinding.instance.addObserver(_i);

    // 1) Permisos (Android 13+ / iOS)
    await PushService.ensurePermissions();

    // 2) Registrar token al arrancar
    await PushService.registerDeviceToken(reason: 'app_start');

    // 3) Escuchar refresh de token (Firebase lo cambia solo)
    PushService.listenTokenRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Cada vez que la app vuelve al frente: re-registrar/actualizar
      PushService.registerDeviceToken(reason: 'app_resumed');
    }
  }
}
