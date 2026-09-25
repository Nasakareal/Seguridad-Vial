import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/conduce_legalidad.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/conduce_legalidad_captura_screen.dart';

void main() {
  testWidgets(
    'vehicle modal keeps error inside, marks field and scrolls to it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 650));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showConduceLegalidadVehiculoModal(
                  context,
                  fundamentos: const [],
                  initialTipoGeneral: 'motocicleta',
                  onlyMotorcycles: true,
                  initialVehiculo: const ConduceLegalidadVehiculo(
                    id: 99,
                    tipoGeneral: 'motocicleta',
                    tipo: 'Scooter',
                    marca: 'ITALIKA',
                    linea: 'WS150',
                    color: 'NEGRO',
                    capacidadPersonas: 2,
                    tipoServicio: 'PARTICULAR',
                  ),
                  gruasLoader: () async => const [
                    {'id': 1, 'nombre': 'DANNYS'},
                  ],
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Editar vehículo'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -1800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Captura el número de inventario'), findsNWidgets(2));

      final invalidInventory = find.byWidgetPredicate((widget) {
        return widget is InputDecorator &&
            widget.decoration.labelText == 'Número de inventario *' &&
            widget.decoration.errorText == 'Captura el número de inventario';
      });
      expect(invalidInventory, findsOneWidget);
      expect(tester.getTopLeft(invalidInventory).dy, greaterThan(0));
      expect(tester.getBottomRight(invalidInventory).dy, lessThan(650));
    },
  );
}
