import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/actividades_service.dart';
import 'normalized_integer_input_formatter.dart';

class ActividadDetenidosField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const ActividadDetenidosField({
    super.key,
    required this.controller,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final warning = Colors.deepOrange.shade700;
    final fill = Colors.orange.shade50;

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      inputFormatters: const <TextInputFormatter>[
        NormalizedIntegerInputFormatter(
          max: ActividadesService.maxDetainedCount,
        ),
      ],
      decoration: InputDecoration(
        labelText: 'Personas detenidas',
        helperText: 'Maximo 3 por actividad',
        errorText: errorText,
        errorMaxLines: 3,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 3),
        ),
      ),
    );
  }
}
