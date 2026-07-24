import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/widgets/screen_size_text_scale.dart';

void main() {
  test('mantiene escala normal en telefonos', () {
    expect(appTextScaleForSize(const Size(360, 800)), 1);
    expect(appTextScaleForSize(const Size(430, 932)), 1);
  });

  test('aumenta moderadamente solo en pantallas grandes', () {
    expect(appTextScaleForSize(const Size(600, 960)), 1.06);
    expect(appTextScaleForSize(const Size(900, 1440)), 1.12);
  });

  testWidgets('ignora la escala de texto configurada en el telefono', (
    tester,
  ) async {
    late double effectiveScale;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2),
        ),
        child: ScreenSizeTextScale(
          child: Builder(
            builder: (context) {
              effectiveScale = MediaQuery.textScalerOf(context).scale(16) / 16;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(effectiveScale, 1);
  });
}
