import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/conduce_legalidad.dart';
import 'package:seguridad_vial_app/screens/conduce_legalidad/conduce_legalidad_captura_screen.dart';

void main() {
  testWidgets(
    'vehicle modal assigns a read-only inventory folio automatically',
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
                    numeroInventario: '00001',
                    partesDanadas: 'RAYÓN EN COSTADO DERECHO',
                    observaciones: 'CASCO BAJO EL ASIENTO',
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
      final inventoryDecorator = find.byWidgetPredicate(
        (widget) =>
            widget is InputDecorator &&
            widget.decoration.labelText == 'Folio de inventario automático *',
      );
      await tester.scrollUntilVisible(
        inventoryDecorator,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      final inventoryField = find.ancestor(
        of: inventoryDecorator,
        matching: find.byType(TextFormField),
      );
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: inventoryField,
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.controller.text, '00001');
      expect(editable.readOnly, isTrue);
      expect(tester.getTopLeft(inventoryField).dy, greaterThan(0));
      expect(tester.getBottomRight(inventoryField).dy, lessThan(650));

      await tester.scrollUntilVisible(
        find.text('Daños o partes afectadas'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Daños o partes afectadas'), findsOneWidget);
      expect(find.text('RAYÓN EN COSTADO DERECHO'), findsOneWidget);
      expect(find.text('Observaciones del inventario'), findsOneWidget);
      expect(find.text('CASCO BAJO EL ASIENTO'), findsOneWidget);
    },
  );
}
