import 'package:flutter/material.dart';

import '../core/vehiculos/marcas_vehiculo.dart';

class MarcaVehiculoDropdown extends StatelessWidget {
  final TextEditingController controller;
  final String? tipoGeneral;
  final String? carroceria;
  final bool enabled;
  final ValueChanged<String?>? onChanged;
  final InputDecoration decoration;

  const MarcaVehiculoDropdown({
    super.key,
    required this.controller,
    required this.tipoGeneral,
    required this.carroceria,
    this.enabled = true,
    this.onChanged,
    this.decoration = const InputDecoration(
      labelText: 'Marca *',
      prefixIcon: Icon(Icons.local_offer),
    ),
  });

  @override
  Widget build(BuildContext context) {
    final opciones = MarcasVehiculo.opcionesPara(
      tipoGeneral: tipoGeneral,
      carroceria: carroceria,
    );
    final value = MarcasVehiculo.valueFromAny(
      controller.text,
      tipoGeneral: tipoGeneral,
      carroceria: carroceria,
    );

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      decoration: decoration,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(
            opciones.isEmpty
                ? '-- Seleccione tipo y carrocería primero --'
                : '-- Seleccione --',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ...opciones.map(
          (marca) => DropdownMenuItem<String>(
            value: marca,
            child: Text(marca, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: enabled && opciones.isNotEmpty
          ? (value) {
              controller.text = value ?? '';
              onChanged?.call(value);
            }
          : null,
      validator: (value) => MarcasVehiculo.validateSelection(
        value,
        tipoGeneral: tipoGeneral,
        carroceria: carroceria,
      ),
    );
  }
}
