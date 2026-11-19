import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/services/auth_service.dart';
import 'package:seguridad_vial_app/widgets/unit_branding_watermark.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('asigna una marca de agua solamente a las unidades configuradas', () {
    expect(
      unitBrandingAssetForUnitId(1),
      'assets/images/pompella/siniestros.png',
    );
    expect(
      unitBrandingAssetForUnitId(AuthService.unidadVialidadesUrbanasId),
      'assets/images/pompella/vialidades.png',
    );
    expect(
      unitBrandingAssetForUnitId(AuthService.unidadCulturaVialId),
      'assets/images/pompella/fomento.png',
    );
    expect(
      unitBrandingAssetForUnitId(AuthService.unidadDelegacionesId),
      'assets/images/pompella/delegaciones.png',
    );
    expect(unitBrandingAssetForUnitId(null), isNull);
    expect(unitBrandingAssetForUnitId(999), isNull);
  });

  testWidgets('recarga la marca después de navegar sin devolver un Future', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: UnitBrandingBackdrop(child: SizedBox.expand())),
    );
    await tester.pumpAndSettle();

    unitBrandingNavigatorObserver.revision.value++;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
