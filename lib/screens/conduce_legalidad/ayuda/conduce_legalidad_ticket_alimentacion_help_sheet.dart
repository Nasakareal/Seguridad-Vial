import 'package:flutter/material.dart';

import 'conduce_legalidad_action_help_sheet.dart';

class ConduceLegalidadTicketAlimentacionHelpSheet extends StatelessWidget {
  const ConduceLegalidadTicketAlimentacionHelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const ConduceLegalidadActionHelpSheet(
      title: 'Abrir e imprimir la boleta',
      description:
          'Cada alimentación tiene su propia boleta. El icono de recibo abre la vista previa antes de imprimir.',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFFEA580C),
      preview: Column(
        children: [
          ConduceLegalidadCaptureCardPreview(
            highlighted: ConduceLegalidadCardControl.ticket,
          ),
          SizedBox(height: 14),
          ConduceLegalidadBoletaToolbarPreview(),
        ],
      ),
      steps: [
        'Ubica la alimentación correcta y pulsa el icono de boleta.',
        'Revisa en la vista previa que los datos correspondan a la persona y al vehículo intervenidos.',
        'Pulsa Imprimir, selecciona papel de 58 mm u 80 mm y elige la impresora Bluetooth emparejada.',
        'Si es la primera impresión, usa Prueba Bluetooth para confirmar la conexión y el ancho del papel.',
      ],
      note:
          'La impresora debe estar encendida y emparejada previamente desde la configuración Bluetooth de Android.',
    );
  }
}
