import 'package:flutter/material.dart';

import 'conduce_legalidad_action_help_sheet.dart';

class ConduceLegalidadShareAlimentacionHelpSheet extends StatelessWidget {
  const ConduceLegalidadShareAlimentacionHelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const ConduceLegalidadActionHelpSheet(
      title: 'Envío automático de la boleta',
      description:
          'Al guardar una alimentación de Conduce con Legalidad, el sistema envía automáticamente al teléfono capturado un PDF con la boleta completa.',
      icon: Icons.mark_chat_read_outlined,
      color: Color(0xFF15803D),
      steps: [
        'Captura correctamente el teléfono de la persona antes de guardar.',
        'Completa los datos del vehículo, inventario, corralón y fundamento.',
        'Pulsa Guardar captura; no necesitas presionar otro botón para el envío.',
        'Lee la confirmación: indicará si la boleta se envió o si quedó guardada pero WhatsApp no pudo entregarla.',
      ],
      note:
          'El icono Compartir sigue disponible para mandar manualmente la tarjeta a otro contacto o grupo; no controla el envío automático al ciudadano.',
    );
  }
}
