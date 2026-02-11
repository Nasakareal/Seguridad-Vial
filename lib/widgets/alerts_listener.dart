// lib/widgets/alerts_listener.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';
import '../main.dart' show navigatorKey;

class AlertsListener extends StatefulWidget {
  const AlertsListener({super.key, required this.child});

  final Widget child;

  @override
  State<AlertsListener> createState() => _AlertsListenerState();
}

class _AlertsListenerState extends State<AlertsListener> {
  Timer? _timer;
  bool _busy = false;
  int? _lastShownAlertId;

  @override
  void initState() {
    super.initState();

    // arranca 3s después para dar tiempo a que cargue token/pantalla
    Future.delayed(const Duration(seconds: 3), () {
      _checkOnce();
      _timer = Timer.periodic(const Duration(seconds: 15), (_) => _checkOnce());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkOnce() async {
    if (_busy) return;
    _busy = true;

    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return;

      final alerts = await AlertService.fetchAlerts();

      // Solo no leídas
      final unread = alerts.where((a) => a['read_at'] == null).toList();
      if (unread.isEmpty) return;

      final alert = unread.first;
      final int alertId = (alert['id'] as num).toInt();

      // Evita mostrar la misma una y otra vez
      if (_lastShownAlertId == alertId) return;
      _lastShownAlertId = alertId;

      final title = (alert['title'] ?? 'Alerta').toString();
      final message = (alert['message'] ?? '').toString();

      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;

      if (!mounted) return;

      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () async {
                await AlertService.markRead(alertId);
                if (navigatorKey.currentState?.canPop() == true) {
                  navigatorKey.currentState!.pop();
                }
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } catch (_) {
      // silencioso, para no spamear logs
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
