import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationDisclosure {
  static const String _kKey = 'bg_location_disclosure_accepted_v1';

  static Future<bool> isAccepted() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kKey) ?? false;
  }

  static Future<void> setAccepted(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kKey, v);
  }

  /// Aviso destacado requerido por Google Play.
  /// Debe mostrarse ANTES de pedir/usar ubicación en segundo plano.
  static Future<bool> show(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubicación en segundo plano'),
        content: const SingleChildScrollView(
          child: Text(
            'Seguridad Vial recopila tu ubicación para mostrar las patrullas/unidades en tiempo real, '
            'incluso cuando la app está cerrada o no está en uso.\n\n'
            'Esto permite:\n'
            '• monitoreo operativo continuo\n'
            '• registro de recorridos\n'
            '• alertas y respuesta ante incidentes\n\n'
            'Puedes desactivarlo en cualquier momento en:\n'
            'Ajustes > Aplicaciones > Seguridad Vial > Permisos > Ubicación.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
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
