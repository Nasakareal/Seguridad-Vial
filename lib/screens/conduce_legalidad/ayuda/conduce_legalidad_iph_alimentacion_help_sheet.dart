import 'package:flutter/material.dart';

import 'conduce_legalidad_action_help_sheet.dart';

class ConduceLegalidadIphAlimentacionHelpSheet extends StatelessWidget {
  const ConduceLegalidadIphAlimentacionHelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const ConduceLegalidadActionHelpSheet(
      title: 'Descargar el IPH',
      description:
          'El IPH se genera para una alimentación específica desde el menú de tres puntos de su tarjeta.',
      icon: Icons.description_outlined,
      color: Color(0xFF7C3AED),
      preview: ConduceLegalidadCaptureCardPreview(
        highlighted: ConduceLegalidadCardControl.menu,
        selectedMenuItem: 'iph',
      ),
      steps: [
        'Ubica la alimentación para la que necesitas el documento.',
        'Pulsa los tres puntos de la tarjeta y selecciona Descargar IPH.',
        'Espera el mensaje IPH guardado o IPH descargado.',
        'La aplicación intentará abrir el archivo Word; si no puede, mostrará las opciones para compartirlo.',
      ],
      note:
          'Revisa el documento generado antes de imprimirlo o enviarlo. La descarga requiere que la captura ya exista en el servidor.',
    );
  }
}
