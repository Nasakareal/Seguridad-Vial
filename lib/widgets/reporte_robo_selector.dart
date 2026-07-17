import 'package:flutter/material.dart';

class ReporteRoboSelector extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool?>? onChanged;

  const ReporteRoboSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade700, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_car_filled_rounded,
                color: Colors.red.shade800,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '¿Este vehículo tiene reporte de robo?',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Selecciona Sí sólo cuando el reporte esté confirmado.'),
          const SizedBox(height: 12),
          DropdownButtonFormField<bool>(
            key: const Key('reporte_robo_selector'),
            value: value,
            decoration: const InputDecoration(
              labelText: 'Reporte de robo *',
              prefixIcon: Icon(Icons.gpp_maybe_rounded),
            ),
            hint: const Text('Seleccione una opción'),
            items: const [
              DropdownMenuItem<bool>(value: false, child: Text('No')),
              DropdownMenuItem<bool>(value: true, child: Text('Sí')),
            ],
            onChanged: onChanged,
            validator: (selection) => selection == null
                ? 'Selecciona Sí o No antes de guardar.'
                : null,
          ),
        ],
      ),
    );
  }
}
