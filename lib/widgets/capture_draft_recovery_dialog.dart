import 'package:flutter/material.dart';

Future<bool> confirmCaptureDraftRecovery(
  BuildContext context, {
  required Map<String, dynamic> values,
  required String newLabel,
}) async {
  final date = '${values['fecha'] ?? ''} ${values['hora'] ?? ''}'.trim();
  final place = (values['calle'] ?? values['lugar'] ?? '').toString().trim();
  final capturedAt = DateTime.tryParse('${values['fecha'] ?? ''}');
  final old =
      capturedAt != null && DateTime.now().difference(capturedAt).inDays >= 1;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
          title: const Text('¿Continuar una captura anterior?'),
          content: SingleChildScrollView(child: Text(
            [
              if (date.isNotEmpty) 'Fecha de la captura: $date',
              if (place.isNotEmpty) 'Lugar: $place',
              if (old) 'Atención: esta captura es de un día anterior.',
              'Continúa solo si es el mismo evento que dejaste sin terminar. Para otro evento, empieza una captura nueva.',
              'Si ya lo guardaste sin conexión, está pendiente de subir automáticamente: no lo captures otra vez.',
              'Empezar una nueva descarta este borrador local. Los registros enviados o pendientes de subir se conservan.',
            ].join('\n\n'),
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar captura anterior'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(newLabel),
            ),
          ],
          ),
        ),
      ) ??
      false;
}
