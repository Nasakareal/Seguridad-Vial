import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/conduce_legalidad.dart';
import 'package:seguridad_vial_app/screens/actividades/widgets/actividad_conduce_legalidad_panel.dart';

void main() {
  testWidgets('filtra por el texto visible puente y por licencia', (
    tester,
  ) async {
    const puente = ConduceLegalidadFundamento(
      id: 1,
      codigo: 'ART440_FVI_MOTO_CARRILES_CENTRALES',
      nombre: 'Motocicleta en carriles centrales de acceso controlado',
      articulo: '440',
      puntos: 3,
      retencionVehiculo: false,
    );
    const licencia = ConduceLegalidadFundamento(
      id: 2,
      codigo: 'OP_CL_SIN_LICENCIA_SIN_HABILITADO',
      nombre: 'Persona sin licencia vigente',
      articulo: '402',
      puntos: 0,
      retencionVehiculo: true,
    );
    const casco = ConduceLegalidadFundamento(
      id: 3,
      codigo: 'ART419_FII_I_MOTO_CASCO_PROTECTOR',
      nombre: 'Motocicleta sin casco protector',
      articulo: '419',
      fundamentoLegal:
          'Sanción: tres puntos de penalización a la licencia para conducir.',
      puntos: 3,
      retencionVehiculo: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActividadConduceLegalidadPanel(
            loading: false,
            error: null,
            catalogo: const [puente, licencia, casco],
            seleccionados: const [null],
            enabled: true,
            onRetry: () {},
            onPrincipalChanged: (_) {},
            onAdicionalChanged: (_, __) {},
            onRemoveAdicional: (_) {},
            onAdd: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buscar por conducta, artículo o código...'));
    await tester.pumpAndSettle();

    final search = find.byKey(const Key('actividad-buscar-fundamento'));
    await tester.enterText(search, 'puente');
    await tester.pump();
    expect(
      find.byKey(
        const Key(
          'actividad-fundamento-opcion-ART440_FVI_MOTO_CARRILES_CENTRALES',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'actividad-fundamento-opcion-OP_CL_SIN_LICENCIA_SIN_HABILITADO',
        ),
      ),
      findsNothing,
    );

    await tester.enterText(search, 'licencia');
    await tester.pump();
    expect(find.text('1 fundamentos disponibles'), findsOneWidget);
    expect(
      find.byKey(
        const Key(
          'actividad-fundamento-opcion-OP_CL_SIN_LICENCIA_SIN_HABILITADO',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'actividad-fundamento-opcion-ART440_FVI_MOTO_CARRILES_CENTRALES',
        ),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const Key(
          'actividad-fundamento-opcion-ART419_FII_I_MOTO_CASCO_PROTECTOR',
        ),
      ),
      findsNothing,
    );
  });
}
