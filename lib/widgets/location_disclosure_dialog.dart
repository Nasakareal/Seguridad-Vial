import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationDisclosure {
  static const String _kAccepted = 'location_disclosure_accepted_v1';

  static Future<bool> isAccepted() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kAccepted) ?? false;
  }

  static Future<void> setAccepted(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kAccepted, v);
  }

  static Future<bool> show(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubicación en segundo plano'),
        content: const Text(
          'Para mostrar patrullas activas en tiempo real, la app necesita acceder a tu ubicación incluso cuando está en segundo plano.\n\n'
          'Esto se usa únicamente para operación y coordinación del servicio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No acepto'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Acepto'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await setAccepted(true);
      return true;
    }

    return false;
  }
}
