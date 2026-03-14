import 'package:flutter/material.dart';

import '../../app/routes.dart';

class PendingHechoCaptureScreen extends StatelessWidget {
  const PendingHechoCaptureScreen({super.key});

  String? _hechoClientUuid(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['hechoClientUuid'] != null) {
      final value = args['hechoClientUuid'].toString().trim();
      return value.isEmpty ? null : value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hechoClientUuid = _hechoClientUuid(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Hecho pendiente')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: hechoClientUuid == null
              ? const Center(
                  child: Text(
                    'No se encontró el UUID local del hecho para seguir capturando.',
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.2),
                        ),
                      ),
                      child: const Text(
                        'Este hecho todavía no existe en el servidor. Desde aquí puedes seguir capturando vehículos y lesionados offline usando el UUID local. Los registros aparecerán en listados normales cuando termine la sincronización.',
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.vehiculosCreate,
                          arguments: {'hechoClientUuid': hechoClientUuid},
                        );
                      },
                      icon: const Icon(Icons.directions_car),
                      label: const Text('Nuevo vehículo'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.lesionadoCreate,
                          arguments: {'hechoClientUuid': hechoClientUuid},
                        );
                      },
                      icon: const Icon(Icons.personal_injury),
                      label: const Text('Nuevo lesionado'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Volver'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
