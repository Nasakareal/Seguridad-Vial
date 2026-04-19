import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../models/croquis_element.dart';

class CroquisBounds {
  const CroquisBounds(this.w, this.h);

  final double w;
  final double h;
}

class CroquisHandles {
  const CroquisHandles({
    required this.rotate,
    required this.resize,
    this.curve,
  });

  final Offset rotate;
  final Offset resize;
  final Offset? curve;
}

class CroquisGeometry {
  static double totalRoadWidth(CroquisElement el) {
    final carriles = math.max(1, el.carriles ?? 1);
    final anchoCarril = math.max(1.0, el.anchoCarril ?? 1);
    return carriles * anchoCarril;
  }

  static double crossHorizontalLength(CroquisElement el) {
    return el.largoHorizontal ?? el.largo ?? 220;
  }

  static double crossVerticalLength(CroquisElement el) {
    return el.largoVertical ?? el.largo ?? 220;
  }

  static CroquisBounds getBounds(CroquisElement el) {
    if (el.tipo == 'carro') {
      return CroquisBounds(el.ancho ?? 60, el.alto ?? 30);
    }

    if (el.tipo == 'vehiculo') {
      return CroquisBounds(el.ancho ?? 90, el.alto ?? 50);
    }

    if (el.tipo == 'icono') {
      return CroquisBounds(el.ancho ?? 36, el.alto ?? 36);
    }

    if (el.tipo == 'texto') {
      return CroquisBounds(el.ancho ?? 120, el.alto ?? 24);
    }

    if (el.tipo == 'calle') {
      return CroquisBounds(el.largo ?? 260, totalRoadWidth(el));
    }

    if (el.tipo == 'curva') {
      final outer = (el.radioInterno ?? 45) + totalRoadWidth(el);
      return CroquisBounds(outer * 2, outer * 2);
    }

    if (el.tipo == 'cruce') {
      final roadW = totalRoadWidth(el);
      return CroquisBounds(
        math.max(crossHorizontalLength(el), roadW),
        math.max(crossVerticalLength(el), roadW),
      );
    }

    if (el.tipo == 'entronque') {
      final roadW = totalRoadWidth(el);
      return CroquisBounds(
        math.max(el.largoBase ?? 220, roadW),
        roadW + (el.largoBrazo ?? 140),
      );
    }

    if (el.tipo == 'glorieta') {
      final outer = (el.radioIsla ?? 40) + totalRoadWidth(el);
      return CroquisBounds(outer * 2, outer * 2);
    }

    return const CroquisBounds(100, 100);
  }

  static CroquisHandles getHandles(CroquisElement el) {
    final bounds = getBounds(el);
    final rotate = Offset(0, -(bounds.h / 2) - 28);
    final resize = Offset((bounds.w / 2) + 16, (bounds.h / 2) + 16);

    if (el.tipo == 'curva') {
      final outer = (el.radioInterno ?? 45) + totalRoadWidth(el);
      final angle = ((el.angulo ?? 90) * math.pi) / 180;
      return CroquisHandles(
        rotate: rotate,
        resize: resize,
        curve: Offset(
          math.cos(angle) * (outer + 18),
          math.sin(angle) * (outer + 18),
        ),
      );
    }

    return CroquisHandles(rotate: rotate, resize: resize);
  }
}

class CroquisCanvasPainter extends CustomPainter {
  CroquisCanvasPainter({
    required this.elementos,
    required this.images,
    this.showSelection = true,
  });

  final List<CroquisElement> elementos;
  final Map<String, ui.Image> images;
  final bool showSelection;

  static const Color roadFill = Color(0xFF2F2F2F);
  static const Color roadLine = Colors.white;
  static const Color islandFill = Color(0xFF5CB85C);
  static const Color selectColor = Color(0xFF0D6EFD);
  static const Color rotateColor = Color(0xFFDC3545);
  static const Color resizeColor = Color(0xFFFD7E14);
  static const Color curveColor = Color(0xFF6F42C1);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, bg);

    final gridPaint = Paint()
      ..color = const Color(0xFFE9EDF3)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (final el in elementos) {
      _drawElement(canvas, el);
    }
  }

  void _drawElement(Canvas canvas, CroquisElement el) {
    canvas.save();
    canvas.translate(el.x, el.y);
    canvas.rotate((el.rotacion * math.pi) / 180);

    switch (el.tipo) {
      case 'carro':
        _drawCar(canvas, el);
        break;
      case 'vehiculo':
        _drawVehicle(canvas, el);
        break;
      case 'icono':
        _drawIcon(canvas, el);
        break;
      case 'texto':
        _drawText(canvas, el);
        break;
      case 'calle':
        _drawStreet(canvas, el);
        break;
      case 'curva':
        _drawCurve(canvas, el);
        break;
      case 'cruce':
        _drawCross(canvas, el);
        break;
      case 'entronque':
        _drawTJunction(canvas, el);
        break;
      case 'glorieta':
        _drawRoundabout(canvas, el);
        break;
    }

    if (showSelection && el.seleccionado) {
      _drawSelection(canvas, el);
    }

    canvas.restore();
  }

  void _drawCar(Canvas canvas, CroquisElement el) {
    final w = el.ancho ?? 60;
    final h = el.alto ?? 30;
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = const Color(0xFFD9534F),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * .5, height: h * .55),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF202020),
    );
  }

  void _drawVehicle(Canvas canvas, CroquisElement el) {
    final image = _imageFor(el.src);
    if (image != null) {
      _drawImage(canvas, el, image);
      return;
    }

    _drawImageFallback(
      canvas,
      el,
      const Color(0xFF6C757D),
      Icons.directions_car,
    );
  }

  void _drawIcon(Canvas canvas, CroquisElement el) {
    final image = _imageFor(el.src);
    if (image != null) {
      _drawImage(canvas, el, image);
      return;
    }

    _drawImageFallback(canvas, el, const Color(0xFF17A2B8), Icons.place);
  }

  ui.Image? _imageFor(String? src) {
    final key = src?.trim() ?? '';
    if (key.isEmpty) return null;
    return images[key];
  }

  void _drawImage(Canvas canvas, CroquisElement el, ui.Image image) {
    final w = el.ancho ?? 40;
    final h = el.alto ?? 40;
    paintImage(
      canvas: canvas,
      rect: Rect.fromCenter(center: Offset.zero, width: w, height: h),
      image: image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
    );
  }

  void _drawImageFallback(
    Canvas canvas,
    CroquisElement el,
    Color color,
    IconData icon,
  ) {
    final w = el.ancho ?? 40;
    final h = el.alto ?? 40;
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = color.withValues(alpha: .78),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF222222),
    );

    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: math.min(w, h) * .48,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
  }

  void _drawText(Canvas canvas, CroquisElement el) {
    final text = (el.contenido ?? 'Texto').trim().isEmpty
        ? 'Texto'
        : el.contenido!.trim();
    final fontSize = el.fontSize ?? 20;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF111111),
          fontSize: fontSize,
          fontFamily: el.fontFamily,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(40, el.ancho ?? 120));

    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
  }

  void _drawStreet(Canvas canvas, CroquisElement el) {
    final width = el.largo ?? 260;
    final height = CroquisGeometry.totalRoadWidth(el);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      Paint()..color = roadFill,
    );

    final dividers = _laneDividers(el);
    for (final y in dividers) {
      _drawDashedLine(
        canvas,
        Offset(-width / 2, y),
        Offset(width / 2, y),
        Paint()
          ..color = roadLine
          ..strokeWidth = 2,
      );
    }
  }

  void _drawCurve(Canvas canvas, CroquisElement el) {
    final inner = el.radioInterno ?? 45;
    final outer = inner + CroquisGeometry.totalRoadWidth(el);
    final angle = ((el.angulo ?? 90) * math.pi) / 180;
    final path = Path()
      ..moveTo(outer, 0)
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: outer),
        0,
        angle,
        false,
      )
      ..lineTo(math.cos(angle) * inner, math.sin(angle) * inner)
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: inner),
        angle,
        -angle,
        false,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = roadFill);

    final carriles = math.max(1, el.carriles ?? 1);
    for (var i = 1; i < carriles; i += 1) {
      final radius = inner + (i * (el.anchoCarril ?? 28));
      _drawDashedArc(canvas, radius, 0, angle);
    }
  }

  void _drawCross(Canvas canvas, CroquisElement el) {
    final roadW = CroquisGeometry.totalRoadWidth(el);
    final armH = CroquisGeometry.crossHorizontalLength(el);
    final armV = CroquisGeometry.crossVerticalLength(el);
    final paint = Paint()..color = roadFill;

    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: armH, height: roadW),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: roadW, height: armV),
      paint,
    );

    for (final y in _laneDividers(el)) {
      _drawDashedLine(
        canvas,
        Offset(-armH / 2, y),
        Offset(armH / 2, y),
        _lanePaint(),
      );
      canvas.save();
      canvas.rotate(math.pi / 2);
      _drawDashedLine(
        canvas,
        Offset(-armV / 2, y),
        Offset(armV / 2, y),
        _lanePaint(),
      );
      canvas.restore();
    }
  }

  void _drawTJunction(Canvas canvas, CroquisElement el) {
    final roadW = CroquisGeometry.totalRoadWidth(el);
    final base = el.largoBase ?? 220;
    final arm = el.largoBrazo ?? 140;
    final paint = Paint()..color = roadFill;

    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: base, height: roadW),
      paint,
    );
    canvas.drawRect(Rect.fromLTWH(-roadW / 2, -arm, roadW, arm), paint);

    for (final y in _laneDividers(el)) {
      _drawDashedLine(
        canvas,
        Offset(-base / 2, y),
        Offset(base / 2, y),
        _lanePaint(),
      );
      canvas.save();
      canvas.rotate(math.pi / 2);
      _drawDashedLine(canvas, Offset(0, y), Offset(arm, y), _lanePaint());
      canvas.restore();
    }
  }

  void _drawRoundabout(Canvas canvas, CroquisElement el) {
    final ringWidth = CroquisGeometry.totalRoadWidth(el);
    final inner = el.radioIsla ?? 40;
    final outer = inner + ringWidth;
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: outer))
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: inner));
    canvas.drawPath(ring, Paint()..color = roadFill);

    canvas.drawCircle(
      Offset.zero,
      math.max(6, inner - 4),
      Paint()..color = islandFill,
    );

    final carriles = math.max(1, el.carriles ?? 1);
    for (var i = 1; i < carriles; i += 1) {
      final radius = inner + (i * (el.anchoCarril ?? 24));
      _drawDashedArc(canvas, radius, 0, math.pi * 2);
    }
  }

  void _drawSelection(Canvas canvas, CroquisElement el) {
    final bounds = CroquisGeometry.getBounds(el);
    final handles = CroquisGeometry.getHandles(el);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: bounds.w,
      height: bounds.h,
    );
    final selectPaint = Paint()
      ..color = selectColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    _drawDashedRect(canvas, rect, selectPaint);
    canvas.drawLine(Offset(0, -bounds.h / 2), handles.rotate, selectPaint);

    _drawHandle(canvas, handles.rotate, rotateColor);
    _drawHandle(canvas, handles.resize, resizeColor);

    final curve = handles.curve;
    if (curve != null) {
      _drawHandle(canvas, curve, curveColor, radius: 18);
    }
  }

  void _drawHandle(
    Canvas canvas,
    Offset center,
    Color color, {
    double radius = 19,
  }) {
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()..color = Colors.white.withValues(alpha: .92),
    );
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF111827),
    );
  }

  List<double> _laneDividers(CroquisElement el) {
    final carriles = math.max(1, el.carriles ?? 1);
    final ancho = math.max(1.0, el.anchoCarril ?? 1);
    final total = carriles * ancho;
    final start = -total / 2;
    return <double>[for (var i = 1; i < carriles; i += 1) start + (i * ancho)];
  }

  Paint _lanePaint() {
    return Paint()
      ..color = roadLine
      ..strokeWidth = 2;
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 12.0;
    const gap = 10.0;
    final total = (to - from).distance;
    if (total <= 0) return;
    final direction = (to - from) / total;
    var distance = 0.0;

    while (distance < total) {
      final start = from + direction * distance;
      final end = from + direction * math.min(distance + dash, total);
      canvas.drawLine(start, end, paint);
      distance += dash + gap;
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint);
  }

  void _drawDashedArc(
    Canvas canvas,
    double radius,
    double startAngle,
    double sweepAngle,
  ) {
    const dash = .12;
    const gap = .10;
    var current = startAngle;
    final end = startAngle + sweepAngle;
    final paint = _lanePaint()..style = PaintingStyle.stroke;
    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);

    while (current < end) {
      final segment = math.min(dash, end - current);
      canvas.drawArc(rect, current, segment, false, paint);
      current += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CroquisCanvasPainter oldDelegate) {
    return true;
  }
}
