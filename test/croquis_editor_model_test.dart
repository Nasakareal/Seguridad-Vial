import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:seguridad_vial_app/models/croquis_element.dart';
import 'package:seguridad_vial_app/screens/accidentes/croquis/croquis_canvas_painter.dart';

void main() {
  group('CroquisModels', () {
    test('convierte curvas antiguas al formato Bezier del backend', () {
      final curve = CroquisModels.normalize(<String, dynamic>{
        'id': 'croquis_8',
        'tipo': 'curva',
        'x': 100,
        'y': 120,
        'radioInterno': 45,
        'anchoCarril': 28,
        'carriles': 1,
        'angulo': 90,
      })!;

      expect(curve.inicioX, closeTo(59, .001));
      expect(curve.inicioY, closeTo(0, .001));
      expect(curve.finX, closeTo(0, .001));
      expect(curve.finY, closeTo(59, .001));
      expect(curve.control1X, closeTo(59, .001));
      expect(curve.control2Y, closeTo(59, .001));
    });

    test('conserva curva deformada y laterales al serializar', () {
      final curve = CroquisModels.curva()
        ..inicioX = -170
        ..control1Y = -120
        ..control2X = 115
        ..finY = 90
        ..bordeIzquierdo = 'banqueta'
        ..bordeDerecho = 'camellon';

      final decoded =
          jsonDecode(CroquisElement.serialize(<CroquisElement>[curve]))
              as List<dynamic>;
      final restored = CroquisModels.deserialize(decoded).single;

      expect(restored.inicioX, -170);
      expect(restored.control1Y, -120);
      expect(restored.control2X, 115);
      expect(restored.finY, 90);
      expect(restored.bordeIzquierdo, 'banqueta');
      expect(restored.bordeDerecho, 'camellon');
    });

    test('crea y duplica banquetas y camellones libres', () {
      final sidewalk = CroquisModels.banqueta(x: 40, y: 50)
        ..largo = 315
        ..ancho = 41
        ..rotacion = 18;
      final duplicate = CroquisModels.duplicate(sidewalk);
      final median = CroquisModels.camellon();

      expect(duplicate.id, isNot(sidewalk.id));
      expect(duplicate.x, 64);
      expect(duplicate.y, 74);
      expect(duplicate.largo, 315);
      expect(duplicate.ancho, 41);
      expect(duplicate.rotacion, 18);
      expect(median.tipo, 'camellon');
      expect(median.ancho, 34);
    });
  });

  group('CroquisGeometry', () {
    test('la polilinea Bezier conserva extremos y admite laterales', () {
      final curve = CroquisModels.curva()
        ..bordeIzquierdo = 'banqueta'
        ..bordeDerecho = 'camellon';
      final center = CroquisGeometry.curvePolyline(curve, steps: 16);
      final lateral = CroquisGeometry.curvePolyline(
        curve,
        offset: 25,
        steps: 16,
      );

      expect(center.first.dx, curve.inicioX);
      expect(center.first.dy, curve.inicioY);
      expect(center.last.dx, curve.finX);
      expect(center.last.dy, curve.finY);
      expect(lateral.first, isNot(center.first));
      expect(CroquisGeometry.maxAttachedWidth(curve), 34);
    });

    test('renderiza vías con laterales y piezas libres sin errores', () {
      final elements = <CroquisElement>[
        CroquisModels.curva()
          ..bordeIzquierdo = 'banqueta'
          ..bordeDerecho = 'camellon',
        CroquisModels.calle()
          ..bordeIzquierdo = 'camellon'
          ..bordeDerecho = 'banqueta',
        CroquisModels.cruce()..bordeDerecho = 'camellon',
        CroquisModels.entronque()..bordeIzquierdo = 'banqueta',
        CroquisModels.glorieta()
          ..bordeIzquierdo = 'camellon'
          ..bordeDerecho = 'banqueta',
        CroquisModels.camellon(),
        CroquisModels.banqueta(),
      ];
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      CroquisCanvasPainter(
        elementos: elements,
        images: const <String, ui.Image>{},
      ).paint(canvas, const ui.Size(1200, 700));

      expect(recorder.endRecording(), isA<ui.Picture>());
    });

    test(
      'los divisores curvos son visibles y no crean círculos blancos',
      () async {
        final curve = CroquisModels.curva(x: 220, y: 180)
          ..carriles = 2
          ..anchoCarril = 28;
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        CroquisCanvasPainter(
          elementos: <CroquisElement>[curve],
          images: const <String, ui.Image>{},
          showSelection: false,
        ).paint(canvas, const ui.Size(500, 360));
        final picture = recorder.endRecording();
        final image = await picture.toImage(500, 360);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(bytes, isNotNull);

        bool isWhite(int x, int y) {
          final offset = ((y * 500) + x) * 4;
          return bytes!.getUint8(offset) > 220 &&
              bytes.getUint8(offset + 1) > 220 &&
              bytes.getUint8(offset + 2) > 220 &&
              bytes.getUint8(offset + 3) > 220;
        }

        final centerline = CroquisGeometry.curvePolyline(curve, steps: 120);
        final visibleSamples = centerline.where((point) {
          final x = (curve.x + point.dx).round();
          final y = (curve.y + point.dy).round();
          return isWhite(x, y);
        }).length;
        expect(visibleSamples, greaterThan(25));

        final startX = (curve.x + (curve.inicioX ?? 0)).round();
        final startY = (curve.y + (curve.inicioY ?? 0)).round();
        var whitePixelsAtEndpoint = 0;
        for (var dy = -14; dy <= 14; dy += 1) {
          for (var dx = -14; dx <= 14; dx += 1) {
            if ((dx * dx) + (dy * dy) > 14 * 14) continue;
            if (isWhite(startX + dx, startY + dy)) {
              whitePixelsAtEndpoint += 1;
            }
          }
        }
        expect(whitePixelsAtEndpoint, lessThan(180));

        image.dispose();
        picture.dispose();
      },
    );
  });
}
