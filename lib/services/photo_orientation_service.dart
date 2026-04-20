import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PhotoOrientationService {
  static const double _landscapeAspect = 16 / 9;
  static const int _maxWidth = 1600;
  static const int _jpegQuality = 85;

  static Future<PhotoDimensions?> imageSize(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final oriented = img.bakeOrientation(decoded);
      return PhotoDimensions(width: oriented.width, height: oriented.height);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> needsLandscapeCrop(File file) async {
    final size = await imageSize(file);
    if (size == null) return false;
    return size.width <= size.height;
  }

  static Future<File> forceLandscape(File file) async {
    return cropLandscape(file, yFraction: 0.5);
  }

  static Future<File> cropLandscape(
    File file, {
    required double yFraction,
  }) async {
    final img.Image oriented;
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return file;
      oriented = img.bakeOrientation(decoded);
    } catch (_) {
      return file;
    }

    if (oriented.width > oriented.height) return file;

    final cropWidth = oriented.width;
    final cropHeight = math.min(
      oriented.height,
      math.max(1, (cropWidth / _landscapeAspect).round()),
    );
    final maxCropY = math.max(0, oriented.height - cropHeight);
    final cropY = (maxCropY * yFraction.clamp(0.0, 1.0)).round();

    final cropped = img.copyCrop(
      oriented,
      x: 0,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );
    final output = cropped.width > _maxWidth
        ? img.copyResize(cropped, width: _maxWidth)
        : cropped;
    final jpg = img.encodeJpg(output, quality: _jpegQuality);

    final dir = await getTemporaryDirectory();
    final basename = p.basenameWithoutExtension(file.path);
    final target = File(
      p.join(
        dir.path,
        'landscape_${DateTime.now().microsecondsSinceEpoch}_$basename.jpg',
      ),
    );

    return target.writeAsBytes(jpg, flush: true);
  }

  static Future<List<File>> forceLandscapeAll(Iterable<File> files) async {
    final processed = <File>[];
    for (final file in files) {
      processed.add(await forceLandscape(file));
    }
    return processed;
  }
}

class PhotoDimensions {
  final int width;
  final int height;

  const PhotoDimensions({required this.width, required this.height});
}
