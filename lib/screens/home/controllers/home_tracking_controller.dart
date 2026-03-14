import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/location_flag_service.dart';
import '../../../services/tracking_service.dart';

class HomeTrackingController {
  final ValueNotifier<bool> trackingOn = ValueNotifier<bool>(false);

  bool _askingDisclosure = false;
  bool _disclosureAcceptedThisSession = false;

  Future<bool> _showProminentDisclosureDialog(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Permiso de ubicacion en segundo plano'),
          content: const Text(
            'Esta app recopila y transmite datos de ubicacion para habilitar el monitoreo de unidades y el mapa de patrullas, incluso cuando la app esta cerrada o no esta en uso.\n\n'
            'Si aceptas, se solicitara el permiso de ubicacion necesario para activar esta funcion.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No aceptar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );

    return res == true;
  }

  Future<bool> _ensureDisclosureAcceptedBeforeStart(
    BuildContext context,
  ) async {
    if (_disclosureAcceptedThisSession) return true;
    if (_askingDisclosure) return false;

    _askingDisclosure = true;
    try {
      final ok = await _showProminentDisclosureDialog(context);
      if (ok) {
        _disclosureAcceptedThisSession = true;
        return true;
      }
      return false;
    } finally {
      _askingDisclosure = false;
    }
  }

  Future<void> syncFromCommanderFlag(BuildContext context) async {
    try {
      final askLocation = await AuthService.shouldAskLocation();
      final running = await TrackingService.isRunning();

      if (!askLocation) {
        if (running) {
          try {
            await TrackingService.stop();
          } catch (_) {}
        }
        trackingOn.value = false;
        return;
      }

      final enabledByCommander = await LocationFlagService.isEnabledForMe();
      if (!context.mounted) return;

      if (!enabledByCommander) {
        if (running) {
          try {
            await TrackingService.stop();
          } catch (_) {}
        }
        trackingOn.value = false;
        return;
      }

      if (!running) {
        final ok = await _ensureDisclosureAcceptedBeforeStart(context);
        if (!context.mounted || !ok) {
          trackingOn.value = false;
          return;
        }

        bool started = false;
        try {
          started = await TrackingService.startWithDisclosure(context);
        } catch (_) {
          started = false;
        }
        if (!context.mounted) return;
        trackingOn.value = started;
      } else {
        trackingOn.value = true;
      }
    } catch (_) {
      trackingOn.value = false;
    }
  }

  Future<void> stop() async {
    try {
      await TrackingService.stop();
    } catch (_) {}
    trackingOn.value = false;
  }

  void dispose() {
    trackingOn.dispose();
  }
}
