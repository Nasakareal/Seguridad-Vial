import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../services/auth_service.dart';

class HomePermissionsController {
  static const String permBusqueda = 'ver busqueda';
  static const String permHechos = 'ver hechos';
  static const String permGruas = 'ver gruas';
  static const String permMapa = 'ver mapa';
  static const String permSustento = 'ver sustento legal';

  final ValueNotifier<Set<String>> perms = ValueNotifier<Set<String>>(
    <String>{},
  );
  final ValueNotifier<bool> loading = ValueNotifier<bool>(true);

  bool _fetching = false;
  Timer? _timer;

  bool allowed(String requiredPerm) {
    final p = requiredPerm.trim().toLowerCase();
    return perms.value.contains(p);
  }

  Future<void> load({bool force = false}) async {
    if (_fetching) return;
    _fetching = true;

    try {
      final list = await AuthService.refreshPermissions();
      perms.value = list.map((e) => e.trim().toLowerCase()).toSet();
      loading.value = false;
    } catch (_) {
      loading.value = false;
    } finally {
      _fetching = false;
    }
  }

  void startSoftRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      load();
    });
  }

  void stopSoftRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stopSoftRefresh();
    perms.dispose();
    loading.dispose();
  }
}
