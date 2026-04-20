import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/photo_orientation_service.dart';

class LandscapePhotoCropScreen extends StatefulWidget {
  final File file;
  final PhotoDimensions size;

  const LandscapePhotoCropScreen({
    super.key,
    required this.file,
    required this.size,
  });

  static Future<File?> cropIfNeeded(BuildContext context, File file) async {
    final size = await PhotoOrientationService.imageSize(file);
    if (!context.mounted) return null;
    if (size == null) return file;
    if (size.width > size.height) return file;

    return Navigator.of(context).push<File>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LandscapePhotoCropScreen(file: file, size: size),
      ),
    );
  }

  @override
  State<LandscapePhotoCropScreen> createState() =>
      _LandscapePhotoCropScreenState();
}

class _LandscapePhotoCropScreenState extends State<LandscapePhotoCropScreen> {
  double _selectionFraction = 0.5;
  bool _cropping = false;

  Future<void> _accept() async {
    if (_cropping) return;

    setState(() => _cropping = true);
    final cropped = await PhotoOrientationService.cropLandscape(
      widget.file,
      yFraction: _selectionFraction,
    );

    if (!mounted) return;
    Navigator.pop(context, cropped);
  }

  Widget _buildPhotoSelector() {
    final size = widget.size;
    final imageAspect = size.width / size.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        var imageWidth = constraints.maxWidth;
        var imageHeight = imageWidth / imageAspect;

        if (imageHeight > constraints.maxHeight) {
          imageHeight = constraints.maxHeight;
          imageWidth = imageHeight * imageAspect;
        }

        final cropHeight = math.min(imageHeight, imageWidth * 9 / 16);
        final maxTop = math.max(0.0, imageHeight - cropHeight);
        final cropTop = maxTop * _selectionFraction;
        final cropRect = Rect.fromLTWH(0, cropTop, imageWidth, cropHeight);

        return Center(
          child: GestureDetector(
            onTapDown: (details) {
              if (maxTop <= 0) return;
              setState(() {
                final nextTop = (details.localPosition.dy - cropHeight / 2)
                    .clamp(0.0, maxTop);
                _selectionFraction = nextTop / maxTop;
              });
            },
            onVerticalDragUpdate: (details) {
              if (maxTop <= 0) return;
              setState(() {
                final nextTop = (cropTop + details.delta.dy).clamp(0.0, maxTop);
                _selectionFraction = nextTop / maxTop;
              });
            },
            child: SizedBox(
              width: imageWidth,
              height: imageHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.file(
                      widget.file,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _LandscapeCropOverlayPainter(cropRect: cropRect),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Elegir recorte'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(child: _buildPhotoSelector()),
              const SizedBox(height: 14),
              const Text(
                'Toca o mueve el recuadro para elegir qué parte se guardará en horizontal.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white30,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                ),
                child: Slider(
                  value: _selectionFraction,
                  onChanged: _cropping
                      ? null
                      : (value) => setState(() {
                          _selectionFraction = value;
                        }),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cropping
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _cropping ? null : _accept,
                      child: _cropping
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Usar recorte'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandscapeCropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  const _LandscapeCropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.38);
    final overlay = Path()
      ..addRect(full)
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(overlay, dimPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(cropRect, borderPaint);

    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final thirdHeight = cropRect.height / 3;
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdHeight),
      Offset(cropRect.right, cropRect.top + thirdHeight),
      guidePaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdHeight * 2),
      Offset(cropRect.right, cropRect.top + thirdHeight * 2),
      guidePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LandscapeCropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
