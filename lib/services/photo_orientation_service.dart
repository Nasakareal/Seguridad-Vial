import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PhotoOrientationService {
  static const Set<String> acceptedInputExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
    'avif',
  };
  static const Set<String> _modernExtensions = <String>{'heic', 'heif', 'avif'};
  static const Set<String> rawExtensions = <String>{
    'dng',
    'raw',
    'cr2',
    'cr3',
    'nef',
    'arw',
    'rw2',
    'orf',
  };
  static const double _landscapeAspect = 16 / 9;
  static const int _maxWidth = 1600;
  static const int _jpegQuality = 85;

  static String extensionOf(File file) {
    return p.extension(file.path).replaceFirst('.', '').toLowerCase();
  }

  static bool isAcceptedInput(File file) {
    return acceptedInputExtensions.contains(extensionOf(file));
  }

  static bool isRawInput(File file) {
    return rawExtensions.contains(extensionOf(file));
  }

  /// Converts modern phone formats to JPEG so previews, offline storage and
  /// the API all receive the same broadly compatible format.
  static Future<File> normalizeForUpload(File file) async {
    final extension = extensionOf(file);
    if (!_modernExtensions.contains(extension)) return file;

    try {
      final dir = await getTemporaryDirectory();
      final basename = p.basenameWithoutExtension(file.path);
      final targetPath = p.join(
        dir.path,
        'upload_${DateTime.now().microsecondsSinceEpoch}_$basename.jpg',
      );
      final converted = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: _maxWidth,
        minHeight: _maxWidth,
        quality: _jpegQuality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (converted == null) {
        throw const PhotoFormatException(
          'No se pudo convertir la foto HEIC/HEIF/AVIF. '
          'Expórtala como JPG desde la galería e inténtalo otra vez.',
        );
      }

      final output = File(converted.path);
      if (!await output.exists() || await output.length() == 0) {
        throw const PhotoFormatException(
          'La conversión de la foto no produjo un archivo válido. '
          'Expórtala como JPG e inténtalo otra vez.',
        );
      }
      return output;
    } on PhotoFormatException {
      rethrow;
    } catch (_) {
      throw const PhotoFormatException(
        'Este dispositivo no pudo procesar la foto HEIC/HEIF/AVIF. '
        'Expórtala como JPG desde la galería e inténtalo otra vez.',
      );
    }
  }

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
    final normalized = await normalizeForUpload(file);
    return cropLandscape(normalized, yFraction: 0.5);
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

class PhotoFormatException implements Exception {
  final String message;

  const PhotoFormatException(this.message);

  @override
  String toString() => message;
}

class PhotoDimensions {
  final int width;
  final int height;

  const PhotoDimensions({required this.width, required this.height});
}
