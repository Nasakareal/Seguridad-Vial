import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/actividad.dart';
import 'package:seguridad_vial_app/screens/actividades/widgets/actividad_vehiculo_modal.dart';

void main() {
  testWidgets('la tarjeta de actividad expone la acción para editar', (
    tester,
  ) async {
    var edits = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActividadVehiculoCard(
            vehiculo: const ActividadVehiculo(
              id: 8,
              marca: 'HONDA',
              tipo: 'Trabajo',
              linea: 'CARGO',
              color: 'ROJO',
              capacidadPersonas: 2,
              tipoServicio: 'PARTICULAR',
              antecedenteVehiculo: false,
            ),
            onEdit: () => edits += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Editar vehículo'));

    expect(edits, 1);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });
}
