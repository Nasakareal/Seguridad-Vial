import 'package:flutter/widgets.dart';
import '../services/push_service.dart';

class AppLifecycleObserver with WidgetsBindingObserver {
  static bool _installed = false;

  static void ensureInstalled() {
    if (_installed) return;
    _installed = true;
    WidgetsBinding.instance.addObserver(AppLifecycleObserver());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        PushService.registerDeviceToken(reason: 'app_resumed');
      } catch (_) {}
    }
  }
}
