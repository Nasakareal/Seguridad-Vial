import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationDisclosure {
  static const String _kAccepted = 'location_disclosure_accepted_v2';

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
          'Esta app recopila y transmite datos de ubicación para mostrar patrullas activas y coordinar el servicio, incluso cuando la app está cerrada o no está en uso.\n\n'
          'Para continuar debes mantener habilitados los permisos de ubicación en segundo plano y, en iPhone, la ubicación precisa.',
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
