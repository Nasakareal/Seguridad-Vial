import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/globals.dart';
import '../widgets/landscape_photo_crop_screen.dart';
import 'photo_orientation_service.dart';

class PhotoPickerService {
  static const int defaultImageQuality = 85;
  static const double defaultMaxDimension = 1600;

  static Future<File?> pickAndCropImage(
    BuildContext context,
    ImagePicker picker, {
    required ImageSource source,
    int imageQuality = defaultImageQuality,
    double maxWidth = defaultMaxDimension,
    double maxHeight = defaultMaxDimension,
    bool cropLandscape = true,
  }) async {
    try {
      final picked = await picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
      if (picked == null || !context.mounted) return null;

      final file = await _preparePickedFile(File(picked.path));
      if (!context.mounted) return null;
      if (!cropLandscape) return file;
      return await cropIfNeeded(context, file);
    } on PlatformException catch (e, st) {
      _reportPickerError(e, st);
      if (!context.mounted) return null;
      _showPickerError(context, e, source);
      return null;
    } on MissingPluginException catch (e, st) {
      _reportPickerError(e, st);
      if (!context.mounted) return null;
      _showPickerError(context, e, source);
      return null;
    } catch (e, st) {
      _reportPickerError(e, st);
      if (!context.mounted) return null;
      _showPickerError(context, e, source);
      return null;
    }
  }

  static Future<List<File>> pickAndCropMultiImage(
    BuildContext context,
    ImagePicker picker, {
    int imageQuality = defaultImageQuality,
    double maxWidth = defaultMaxDimension,
    double maxHeight = defaultMaxDimension,
  }) async {
    try {
      final picked = await picker.pickMultiImage(
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
      if (picked.isEmpty || !context.mounted) return const <File>[];

      final files = <File>[];
      for (final item in picked) {
        final prepared = await _preparePickedFile(File(item.path));
        if (!context.mounted) return files;
        final file = await cropIfNeeded(context, prepared);
        if (!context.mounted) return files;
        if (file != null) files.add(file);
      }
      return files;
    } on PlatformException catch (e, st) {
      _reportPickerError(e, st);
      if (!context.mounted) return const <File>[];
      _showPickerError(context, e, ImageSource.gallery);
      return const <File>[];
    } on MissingPluginException catch (e, st) {
      _reportPickerError(e, st);
      if (!context.mounted) return const <File>[];
      _showPickerError(context, e, ImageSource.gallery);
      return const <File>[];
    } catch (e, st) {
      _reportPickerError(e, st);
      if (!context.mounted) return const <File>[];
      _showPickerError(context, e, ImageSource.gallery);
      return const <File>[];
    }
  }

  static Future<File?> cropIfNeeded(BuildContext context, File file) async {
    try {
      return await LandscapePhotoCropScreen.cropIfNeeded(context, file);
    } catch (e, st) {
      _reportPickerError(e, st);
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo procesar la foto. Intenta con otra.'),
        ),
      );
      return null;
    }
  }

  static Future<File> _preparePickedFile(File file) async {
    if (PhotoOrientationService.isRawInput(file)) {
      throw const PhotoFormatException(
        'La foto está en formato RAW/DNG. Expórtala como JPG desde la '
        'galería antes de subirla.',
      );
    }
    if (!PhotoOrientationService.isAcceptedInput(file)) {
      throw const PhotoFormatException(
        'Formato de foto no compatible. Usa JPG, JPEG, PNG, WEBP, HEIC, '
        'HEIF o AVIF.',
      );
    }
    return PhotoOrientationService.normalizeForUpload(file);
  }

  static void _showPickerError(
    BuildContext context,
    Object error,
    ImageSource source,
  ) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_friendlyMessage(error, source))));
  }

  static String _friendlyMessage(Object error, ImageSource source) {
    if (error is PhotoFormatException) return error.message;

    if (error is PlatformException) {
      switch (error.code) {
        case 'camera_access_denied':
          return 'No se otorgó permiso de cámara.';
        case 'no_available_camera':
          return 'No se encontró una cámara disponible en este equipo.';
        case 'already_active':
          return 'Ya hay una selección de foto en curso.';
      }
    }

    return source == ImageSource.camera
        ? 'No se pudo abrir la cámara. Intenta de nuevo.'
        : 'No se pudieron abrir las fotos. Intenta de nuevo.';
  }

  static void _reportPickerError(Object error, StackTrace stack) {
    reportRuntimeIssue('PHOTO PICKER ERROR: $error\n\n$stack');
  }
}
