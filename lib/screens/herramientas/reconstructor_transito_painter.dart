import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/reconstructor_transito_project.dart';

class ReconstructorTransitoPainter extends CustomPainter {
  const ReconstructorTransitoPainter({
    required this.project,
    required this.currentTime,
    this.selectedKind,
    this.selectedId,
    this.showSelection = true,
  });

  final ReconstructorProject project;
  final double currentTime;
  final String? selectedKind;
  final String? selectedId;
  final bool showSelection;

  static const Size canvasSize = Size(1200, 700);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF4F7FA),
    );
    if (project.layers['grid'] != false) _drawGrid(canvas, size);
    if (project.layers['road'] != false) {
      for (final road in project.roads) {
        _drawRoad(canvas, road);
      }
    }
    if (project.layers['paths'] != false) {
      for (final actor in project.actors) {
        _drawPath(canvas, actor);
      }
    }
    if (project.layers['events'] != false) {
      for (final event in project.events) {
        _drawEvent(canvas, event);
      }
    }
    if (project.layers['actors'] != false) {
      for (final actor in project.actors) {
        _drawActor(canvas, actor);
      }
    }
    _drawLegend(canvas);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = const Color(0xFFDCE5ED)
      ..strokeWidth = .65;
    final major = Paint()
      ..color = const Color(0xFFC4D1DC)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 20) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        x % 100 == 0 ? major : minor,
      );
    }
    for (var y = 0.0; y <= size.height; y += 20) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        y % 100 == 0 ? major : minor,
      );
    }
  }

  void _drawRoad(Canvas canvas, ReconstructorRoad road) {
    canvas.save();
    canvas.translate(road.x, road.y);
    canvas.rotate(road.rotation * math.pi / 180);
    if (road.type == 'curve') {
      _drawCurveRoad(canvas, road);
    } else {
      _drawStraightRoad(canvas, road);
    }
    canvas.restore();
  }

  double _roadWidth(ReconstructorRoad road) =>
      road.lanes * road.laneWidthMeters * project.metadata.pixelsPerMeter;

  double _roadLength(ReconstructorRoad road) =>
      road.lengthMeters * project.metadata.pixelsPerMeter;

  Color _surfaceColor(String surface) => switch (surface) {
    'concrete' => const Color(0xFF777D82),
    'pavers' => const Color(0xFF706C68),
    'cobblestone' => const Color(0xFF615E5A),
    'dirt' => const Color(0xFF997752),
    'gravel' => const Color(0xFF837C71),
    'natural' => const Color(0xFF806C4C),
    _ => const Color(0xFF30343A),
  };

  void _drawStraightRoad(Canvas canvas, ReconstructorRoad road) {
    final length = _roadLength(road);
    final width = _roadWidth(road);
    _drawEdge(
      canvas,
      road.leftEdge,
      Rect.fromLTWH(-length / 2, -width / 2 - 18, length, 18),
    );
    _drawEdge(
      canvas,
      road.rightEdge,
      Rect.fromLTWH(-length / 2, width / 2, length, 18),
    );
    final body = Rect.fromCenter(
      center: Offset.zero,
      width: length,
      height: width,
    );
    canvas.drawRect(body, Paint()..color = _surfaceColor(road.surface));
    _drawSurfacePattern(canvas, body, road.surface);
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: .9)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(-length / 2, -width / 2),
      Offset(length / 2, -width / 2),
      edgePaint,
    );
    canvas.drawLine(
      Offset(-length / 2, width / 2),
      Offset(length / 2, width / 2),
      edgePaint,
    );
    final laneWidth = road.laneWidthMeters * project.metadata.pixelsPerMeter;
    for (var lane = 1; lane < road.lanes; lane++) {
      final y = (-width / 2) + (lane * laneWidth);
      final center = road.direction == 'two_way' && lane == road.lanes ~/ 2;
      _drawLaneLine(
        canvas,
        -length / 2,
        length / 2,
        y,
        center ? const Color(0xFFFACC15) : Colors.white,
        center ? road.centerLine : 'dashed',
      );
    }
    _drawDirectionArrows(canvas, road, length, width);
    if (_selected('road', road.id)) {
      canvas.drawRect(
        body.inflate(5),
        Paint()
          ..color = const Color(0xFF8B5CF6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      _label(
        canvas,
        road.name,
        Offset(-length / 2, -width / 2 - 36),
        const Color(0xFF6D28D9),
      );
      _drawRotationHandle(canvas, Offset(0, -width / 2 - 35));
    }
  }

  void _drawCurveRoad(Canvas canvas, ReconstructorRoad road) {
    final halfWidth = _roadWidth(road) / 2;
    final body = _curvePath(road, halfWidth);
    canvas.drawPath(body, Paint()..color = _surfaceColor(road.surface));
    canvas.save();
    canvas.clipPath(body);
    _drawSurfacePattern(canvas, body.getBounds().inflate(20), road.surface);
    canvas.restore();
    _strokeCurve(canvas, road, -halfWidth, Colors.white, 2);
    _strokeCurve(canvas, road, halfWidth, Colors.white, 2);
    final laneWidth = road.laneWidthMeters * project.metadata.pixelsPerMeter;
    for (var lane = 1; lane < road.lanes; lane++) {
      final offset = -halfWidth + (lane * laneWidth);
      final center = road.direction == 'two_way' && lane == road.lanes ~/ 2;
      _strokeCurve(
        canvas,
        road,
        offset,
        center ? const Color(0xFFFACC15) : Colors.white,
        1.8,
        dashed: !center || road.centerLine == 'dashed',
      );
    }
    if (_selected('road', road.id)) {
      canvas.drawPath(
        body,
        Paint()
          ..color = const Color(0xFF8B5CF6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      _drawCurveHandles(canvas, road);
      final bounds = body.getBounds();
      _label(
        canvas,
        road.name,
        bounds.topLeft - const Offset(0, 28),
        const Color(0xFF6D28D9),
      );
    }
  }

  void _drawEdge(Canvas canvas, String edge, Rect rect) {
    if (edge == 'none') return;
    canvas.drawRect(
      rect,
      Paint()
        ..color = edge == 'median'
            ? const Color(0xFF78A95B)
            : const Color(0xFFCACFD3),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFFEEF1F3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawSurfacePattern(Canvas canvas, Rect bounds, String surface) {
    if (surface == 'asphalt') return;
    final paint = Paint()..strokeWidth = 1;
    if (surface == 'concrete') {
      paint.color = Colors.white.withValues(alpha: .12);
      for (var x = bounds.left; x < bounds.right; x += 65) {
        canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), paint);
      }
      return;
    }
    if (surface == 'pavers' || surface == 'cobblestone') {
      paint.color = Colors.white.withValues(alpha: .13);
      final step = surface == 'pavers' ? 18.0 : 13.0;
      for (var y = bounds.top; y < bounds.bottom; y += step) {
        for (var x = bounds.left; x < bounds.right; x += step * 1.5) {
          canvas.drawCircle(
            Offset(x + ((y ~/ step).isOdd ? step / 2 : 0), y),
            surface == 'pavers' ? 2 : 3,
            paint,
          );
        }
      }
      return;
    }
    paint.color = Colors.white.withValues(alpha: .16);
    for (var y = bounds.top; y < bounds.bottom; y += 15) {
      for (var x = bounds.left; x < bounds.right; x += 19) {
        final seed = ((x + y).round() % 7).toDouble();
        canvas.drawCircle(
          Offset(x + seed, y + seed / 2),
          surface == 'gravel' ? 2.2 : 1.4,
          paint,
        );
      }
    }
  }

  void _drawLaneLine(
    Canvas canvas,
    double start,
    double end,
    double y,
    Color color,
    String style,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    if (style == 'solid') {
      canvas.drawLine(Offset(start, y), Offset(end, y), paint);
    } else if (style == 'double_solid') {
      canvas.drawLine(Offset(start, y - 3), Offset(end, y - 3), paint);
      canvas.drawLine(Offset(start, y + 3), Offset(end, y + 3), paint);
    } else {
      for (var x = start; x < end; x += 28) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 14, end), y), paint);
      }
    }
  }

  void _drawDirectionArrows(
    Canvas canvas,
    ReconstructorRoad road,
    double length,
    double width,
  ) {
    final laneWidth = width / road.lanes;
    for (var lane = 0; lane < road.lanes; lane++) {
      final y = -width / 2 + laneWidth * (lane + .5);
      final reverse = road.direction == 'two_way' && lane < road.lanes / 2;
      _arrow(
        canvas,
        Offset(reverse ? length * .18 : -length * .18, y),
        reverse ? math.pi : 0,
        Colors.white.withValues(alpha: .55),
      );
    }
  }

  Path _curvePath(ReconstructorRoad road, double halfWidth) {
    final left = _curvePoints(road, -halfWidth);
    final right = _curvePoints(road, halfWidth).reversed.toList();
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final point in left.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    for (final point in right) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  List<Offset> _curvePoints(ReconstructorRoad road, double offset) =>
      List<Offset>.generate(
        61,
        (index) => curvePoint(road, index / 60, offset),
      );

  Offset curvePoint(ReconstructorRoad road, double t, [double offset = 0]) {
    final scale = project.metadata.pixelsPerMeter;
    final c = road.curve;
    final p0 = Offset(c.startX * scale, c.startY * scale);
    final p1 = Offset(c.control1X * scale, c.control1Y * scale);
    final p2 = Offset(c.control2X * scale, c.control2Y * scale);
    final p3 = Offset(c.endX * scale, c.endY * scale);
    final u = 1 - t;
    final point =
        (p0 * (u * u * u)) +
        (p1 * (3 * u * u * t)) +
        (p2 * (3 * u * t * t)) +
        (p3 * (t * t * t));
    final tangent =
        (p1 - p0) * (3 * u * u) +
        (p2 - p1) * (6 * u * t) +
        (p3 - p2) * (3 * t * t);
    final length = math.max(.001, tangent.distance);
    return point +
        Offset(-tangent.dy / length * offset, tangent.dx / length * offset);
  }

  void _strokeCurve(
    Canvas canvas,
    ReconstructorRoad road,
    double offset,
    Color color,
    double width, {
    bool dashed = false,
  }) {
    final points = _curvePoints(road, offset);
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    if (!dashed) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
      return;
    }
    for (var index = 0; index < points.length - 1; index += 3) {
      canvas.drawLine(
        points[index],
        points[math.min(index + 1, points.length - 1)],
        paint,
      );
    }
  }

  void _drawCurveHandles(Canvas canvas, ReconstructorRoad road) {
    final scale = project.metadata.pixelsPerMeter;
    final points = <Offset>[
      Offset(road.curve.startX * scale, road.curve.startY * scale),
      Offset(road.curve.control1X * scale, road.curve.control1Y * scale),
      Offset(road.curve.control2X * scale, road.curve.control2Y * scale),
      Offset(road.curve.endX * scale, road.curve.endY * scale),
    ];
    final guide = Paint()
      ..color = const Color(0xFF16A085).withValues(alpha: .8)
      ..strokeWidth = 1.5;
    canvas.drawLine(points[0], points[1], guide);
    canvas.drawLine(points[2], points[3], guide);
    for (var index = 0; index < points.length; index++) {
      canvas.drawCircle(
        points[index],
        8,
        Paint()
          ..color = index == 0 || index == 3
              ? const Color(0xFF8B5CF6)
              : const Color(0xFF10B981),
      );
      canvas.drawCircle(
        points[index],
        8,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawPath(Canvas canvas, ReconstructorActor actor) {
    if (actor.keyframes.length < 2) return;
    final frames = [...actor.keyframes]
      ..sort((a, b) => a.time.compareTo(b.time));
    final color = Color(actor.color);
    final impact = project.events
        .where((event) => event.code == 'PI')
        .map((event) => event.time)
        .fold<double?>(
          null,
          (value, item) => value == null ? item : math.min(value, item),
        );
    for (var index = 0; index < frames.length - 1; index++) {
      final from = frames[index];
      final to = frames[index + 1];
      final posterior = impact != null && from.time >= impact;
      final paint = Paint()
        ..color = color.withValues(alpha: posterior ? .62 : .92)
        ..strokeWidth = posterior ? 3 : 4
        ..style = PaintingStyle.stroke;
      if (posterior) {
        for (var progress = 0.0; progress < 1; progress += .18) {
          canvas.drawLine(
            Offset.lerp(Offset(from.x, from.y), Offset(to.x, to.y), progress)!,
            Offset.lerp(
              Offset(from.x, from.y),
              Offset(to.x, to.y),
              math.min(1, progress + .09),
            )!,
            paint,
          );
        }
      } else {
        canvas.drawLine(Offset(from.x, from.y), Offset(to.x, to.y), paint);
      }
      final angle = math.atan2(to.y - from.y, to.x - from.x);
      _arrow(
        canvas,
        Offset.lerp(Offset(from.x, from.y), Offset(to.x, to.y), .72)!,
        angle,
        color,
      );
    }
    _label(
      canvas,
      'TRAYECTORIA INICIAL',
      Offset(frames.first.x, frames.first.y - 28),
      color,
    );
    if (impact != null) {
      final frame = frames.where((item) => item.time >= impact).firstOrNull;
      if (frame != null) {
        _label(
          canvas,
          'POSTERIOR AL IMPACTO',
          Offset(frame.x, frame.y + 22),
          color,
        );
      }
    }
  }

  void _drawActor(Canvas canvas, ReconstructorActor actor) {
    final position = actor.positionAt(currentTime);
    if (position == null) return;
    canvas.save();
    canvas.translate(position.x, position.y);
    canvas.rotate(position.rotation * math.pi / 180);
    final selected = _selected('actor', actor.id);
    final color = Color(actor.color);
    final size = switch (actor.type) {
      'camion' => const Size(94, 43),
      'camioneta' => const Size(78, 42),
      'motocicleta' => const Size(58, 32),
      'bicicleta' => const Size(48, 30),
      'peaton' => const Size(30, 30),
      _ => const Size(72, 38),
    };
    if (actor.type == 'peaton') {
      canvas.drawCircle(const Offset(0, -8), 7, Paint()..color = color);
      canvas.drawLine(
        const Offset(0, -1),
        const Offset(0, 12),
        Paint()
          ..color = color
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        const Offset(0, 3),
        const Offset(-9, 8),
        Paint()
          ..color = color
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        const Offset(0, 3),
        const Offset(9, 8),
        Paint()
          ..color = color
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    } else if (actor.type == 'bicicleta' || actor.type == 'motocicleta') {
      canvas.drawCircle(
        Offset(-size.width * .32, 5),
        8,
        Paint()
          ..color = const Color(0xFF20242A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawCircle(
        Offset(size.width * .32, 5),
        8,
        Paint()
          ..color = const Color(0xFF20242A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawLine(
        Offset(-size.width * .28, 4),
        Offset(size.width * .12, -7),
        Paint()
          ..color = color
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(size.width * .12, -7),
        Offset(size.width * .30, 4),
        Paint()
          ..color = color
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width,
          height: size.height,
        ),
        const Radius.circular(9),
      );
      canvas.drawRRect(body, Paint()..color = color);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: const Offset(6, 0),
            width: size.width * .42,
            height: size.height * .72,
          ),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFFCDE8F5).withValues(alpha: .85),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(-size.width * .37, -size.height * .38),
          width: 13,
          height: 5,
        ),
        Paint()..color = const Color(0xFF17191C),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(-size.width * .37, size.height * .38),
          width: 13,
          height: 5,
        ),
        Paint()..color = const Color(0xFF17191C),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(size.width * .37, -size.height * .38),
          width: 13,
          height: 5,
        ),
        Paint()..color = const Color(0xFF17191C),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(size.width * .37, size.height * .38),
          width: 13,
          height: 5,
        ),
        Paint()..color = const Color(0xFF17191C),
      );
    }
    if (selected) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width + 12,
          height: size.height + 12,
        ),
        Paint()
          ..color = const Color(0xFF2563EB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      _drawRotationHandle(canvas, Offset(0, -size.height / 2 - 28));
    }
    canvas.restore();
    _label(
      canvas,
      actor.name,
      Offset(position.x - size.width / 2, position.y + size.height / 2 + 8),
      color,
    );
  }

  void _drawEvent(Canvas canvas, ReconstructorEvent event) {
    final color = switch (event.code) {
      'PR' => const Color(0xFF38BDF8),
      'IF' => const Color(0xFFF59E0B),
      'PE' => const Color(0xFFA78BFA),
      'PMC' => const Color(0xFFFB4D63),
      'PF' => const Color(0xFF22C58B),
      _ => const Color(0xFFEF233C),
    };
    canvas.drawCircle(Offset(event.x, event.y), 16, Paint()..color = color);
    canvas.drawCircle(
      Offset(event.x, event.y),
      16,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    _text(
      canvas,
      event.code,
      Offset(event.x, event.y),
      Colors.white,
      10,
      bold: true,
      centered: true,
    );
    if (_selected('event', event.id)) {
      canvas.drawCircle(
        Offset(event.x, event.y),
        22,
        Paint()
          ..color = const Color(0xFF2563EB)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _drawLegend(Canvas canvas) {
    final meters = 5.0;
    final width = meters * project.metadata.pixelsPerMeter;
    final start = Offset(24, canvasSize.height - 28);
    canvas.drawLine(
      start,
      start + Offset(width, 0),
      Paint()
        ..color = const Color(0xFF243341)
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      start - const Offset(0, 5),
      start + const Offset(0, 5),
      Paint()
        ..color = const Color(0xFF243341)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      start + Offset(width, -5),
      start + Offset(width, 5),
      Paint()
        ..color = const Color(0xFF243341)
        ..strokeWidth = 2,
    );
    _text(
      canvas,
      '${meters.toStringAsFixed(0)} m',
      start + Offset(width / 2, -12),
      const Color(0xFF243341),
      11,
      centered: true,
    );
  }

  void _drawRotationHandle(Canvas canvas, Offset point) {
    canvas.drawLine(
      point + const Offset(0, 10),
      point + const Offset(0, 25),
      Paint()
        ..color = const Color(0xFF2563EB)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(point, 9, Paint()..color = const Color(0xFF2563EB));
    _text(canvas, '↻', point, Colors.white, 12, bold: true, centered: true);
  }

  void _arrow(Canvas canvas, Offset point, double angle, Color color) {
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(10, 0)
      ..lineTo(-7, -6)
      ..lineTo(-4, 0)
      ..lineTo(-7, 6)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  void _label(Canvas canvas, String value, Offset point, Color color) {
    final painter = _textPainter(value, Colors.white, 9, bold: true);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(point.dx, point.dy, painter.width + 12, painter.height + 6),
      const Radius.circular(5),
    );
    canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: .9));
    painter.paint(canvas, point + const Offset(6, 3));
  }

  void _text(
    Canvas canvas,
    String value,
    Offset point,
    Color color,
    double size, {
    bool bold = false,
    bool centered = false,
  }) {
    final painter = _textPainter(value, color, size, bold: bold);
    painter.paint(
      canvas,
      centered ? point - Offset(painter.width / 2, painter.height / 2) : point,
    );
  }

  TextPainter _textPainter(
    String value,
    Color color,
    double size, {
    bool bold = false,
  }) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  bool _selected(String kind, String id) =>
      showSelection && selectedKind == kind && selectedId == id;

  @override
  bool shouldRepaint(covariant ReconstructorTransitoPainter oldDelegate) =>
      true;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
