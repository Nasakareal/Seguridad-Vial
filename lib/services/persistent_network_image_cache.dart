import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CachedNetworkImageFile {
  final File file;
  final bool isFresh;

  const CachedNetworkImageFile({required this.file, required this.isFresh});
}

/// Caché en disco para imágenes remotas.
///
/// Vive en el directorio temporal de la app: sobrevive reinicios normales,
/// pero el sistema operativo puede recuperarlo cuando necesita espacio.
class PersistentNetworkImageCache {
  static final PersistentNetworkImageCache instance =
      PersistentNetworkImageCache();

  static const int _maxEntries = 240;
  static const int _maxBytes = 80 * 1024 * 1024;
  static const Duration _retention = Duration(days: 90);
  static const int _maxDownloadBytes = 20 * 1024 * 1024;

  final http.Client _client;
  final Future<Directory> Function() _directoryProvider;
  final Duration _requestTimeout;
  final Map<String, Future<File>> _inFlight = <String, Future<File>>{};

  PersistentNetworkImageCache({
    http.Client? client,
    Future<Directory> Function()? directoryProvider,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _directoryProvider = directoryProvider ?? getTemporaryDirectory,
       _requestTimeout = requestTimeout;

  Future<CachedNetworkImageFile?> lookup(
    String url, {
    required Duration maxAge,
  }) async {
    if (kIsWeb) return null;

    try {
      final entry = await _entryFor(url);
      if (!await entry.image.exists()) return null;

      final length = await entry.image.length();
      if (length <= 0) {
        await remove(url);
        return null;
      }

      final metadata = await _readMetadata(entry.metadata);
      if (metadata != null && metadata.url != url) return null;

      final downloadedAt =
          metadata?.downloadedAt ?? await entry.image.lastModified();
      final now = DateTime.now();
      final age = now.difference(downloadedAt);
      final isFresh = !age.isNegative && age <= maxAge;

      // La fecha del archivo se usa como LRU; la fecha real de descarga vive
      // en el metadata y no cambia al mostrar la imagen.
      await entry.image.setLastModified(now);
      return CachedNetworkImageFile(file: entry.image, isFresh: isFresh);
    } catch (_) {
      return null;
    }
  }

  Future<File> download(String url, {Map<String, String>? headers}) {
    final active = _inFlight[url];
    if (active != null) return active;

    final operation = _download(url, headers: headers);
    _inFlight[url] = operation;
    unawaited(
      operation.then<void>(
        (_) => _removeInFlight(url, operation),
        onError: (_, __) => _removeInFlight(url, operation),
      ),
    );
    return operation;
  }

  void _removeInFlight(String url, Future<File> operation) {
    if (identical(_inFlight[url], operation)) {
      _inFlight.remove(url);
    }
  }

  Future<void> remove(String url) async {
    if (kIsWeb) return;

    try {
      final entry = await _entryFor(url);
      if (await entry.image.exists()) await entry.image.delete();
      if (await entry.metadata.exists()) await entry.metadata.delete();
    } catch (_) {}
  }

  Future<File> _download(String url, {Map<String, String>? headers}) async {
    if (kIsWeb) {
      throw UnsupportedError('La caché persistente no aplica en web.');
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw FormatException('URL de imagen inválida.');
    }

    final response = await _client
        .get(uri, headers: headers)
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'No se pudo descargar la imagen (${response.statusCode}).',
        uri: uri,
      );
    }

    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw const FormatException('La imagen descargada está vacía.');
    }
    if (bytes.length > _maxDownloadBytes) {
      throw const FormatException('La imagen supera el límite de caché.');
    }

    final contentType = response.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (contentType != null &&
        contentType.isNotEmpty &&
        !contentType.startsWith('image/') &&
        contentType != 'application/octet-stream') {
      throw FormatException('El servidor no devolvió una imagen.');
    }

    final entry = await _entryFor(url);
    await entry.image.parent.create(recursive: true);
    final temporary = File(
      '${entry.image.path}.${DateTime.now().microsecondsSinceEpoch}.part',
    );

    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (await entry.image.exists()) await entry.image.delete();
      await temporary.rename(entry.image.path);
      await entry.metadata.writeAsString(
        jsonEncode(<String, Object>{
          'url': url,
          'downloaded_at': DateTime.now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
    } finally {
      if (await temporary.exists()) {
        try {
          await temporary.delete();
        } catch (_) {}
      }
    }

    unawaited(_prune(entry.image.parent));
    return entry.image;
  }

  Future<_CacheEntry> _entryFor(String url) async {
    final root = await _directoryProvider();
    final directory = Directory(p.join(root.path, 'network_images_v1'));
    final key = _stableKey(url);
    return _CacheEntry(
      image: File(p.join(directory.path, '$key.img')),
      metadata: File(p.join(directory.path, '$key.json')),
    );
  }

  Future<_CacheMetadata?> _readMetadata(File file) async {
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;

      final url = decoded['url']?.toString().trim() ?? '';
      final downloadedAt = DateTime.tryParse(
        decoded['downloaded_at']?.toString() ?? '',
      );
      if (url.isEmpty || downloadedAt == null) return null;
      return _CacheMetadata(url: url, downloadedAt: downloadedAt.toLocal());
    } catch (_) {
      return null;
    }
  }

  Future<void> _prune(Directory directory) async {
    try {
      if (!await directory.exists()) return;
      final now = DateTime.now();
      final entries = <_CachedFileStat>[];

      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.img')) continue;
        final stat = await entity.stat();
        if (now.difference(stat.modified) > _retention) {
          await _deletePair(entity);
          continue;
        }
        entries.add(
          _CachedFileStat(
            file: entity,
            bytes: stat.size,
            lastAccessed: stat.modified,
          ),
        );
      }

      entries.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
      var keptBytes = 0;
      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        final fits =
            index < _maxEntries && keptBytes + entry.bytes <= _maxBytes;
        if (fits) {
          keptBytes += entry.bytes;
        } else {
          await _deletePair(entry.file);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('No se pudo depurar la caché de imágenes: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _deletePair(File image) async {
    try {
      if (await image.exists()) await image.delete();
    } catch (_) {}

    final stem = image.path.substring(0, image.path.length - '.img'.length);
    final metadata = File('$stem.json');
    try {
      if (await metadata.exists()) await metadata.delete();
    } catch (_) {}
  }
}

String _stableKey(String value) {
  const offsetBasis = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  const mask = 0xFFFFFFFFFFFFFFFF;

  var hash = offsetBasis;
  for (final byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

class _CacheEntry {
  final File image;
  final File metadata;

  const _CacheEntry({required this.image, required this.metadata});
}

class _CacheMetadata {
  final String url;
  final DateTime downloadedAt;

  const _CacheMetadata({required this.url, required this.downloadedAt});
}

class _CachedFileStat {
  final File file;
  final int bytes;
  final DateTime lastAccessed;

  const _CachedFileStat({
    required this.file,
    required this.bytes,
    required this.lastAccessed,
  });
}
