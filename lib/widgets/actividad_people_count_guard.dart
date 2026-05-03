import 'package:flutter/material.dart';

import '../services/actividades_service.dart';

class ActividadPeopleCountGuard {
  const ActividadPeopleCountGuard._();

  static Future<bool> confirmIfNeeded(
    BuildContext context,
    ActividadUpsertData data,
  ) async {
    final warnings = ActividadesService.peopleCountWarnings(data);
    if (warnings.isEmpty) return true;
    if (!context.mounted) return false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revisar cantidades'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Antes de guardar, confirma estos datos:'),
            const SizedBox(height: 12),
            ...warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $warning'),
              ),
            ),
            const SizedBox(height: 4),
            const Text('Si los datos son correctos, puedes continuar.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Corregir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, guardar'),
          ),
        ],
      ),
    );

    return ok ?? false;
  }
}
