import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/actividades_service.dart';
import 'normalized_integer_input_formatter.dart';

class ActividadDetenidosField extends StatelessWidget {
  final TextEditingController controller;

  const ActividadDetenidosField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final warning = Colors.deepOrange.shade700;
    final fill = Colors.orange.shade50;

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: const <TextInputFormatter>[
        NormalizedIntegerInputFormatter(
          max: ActividadesService.maxDetainedCount,
        ),
      ],
      decoration: InputDecoration(
        labelText: 'Personas detenidas',
        helperText: 'Maximo 3 por actividad',
        prefixIcon: Icon(Icons.warning_amber_rounded, color: warning),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            widthFactor: 1,
            child: Text(
              'MAX 3',
              style: TextStyle(color: warning, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: warning, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: warning, width: 3),
        ),
      ),
    );
  }
}
