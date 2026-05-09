import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:path_provider/path_provider.dart';

final Uint8List _transparentTileBytes = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x03,
  0x01,
  0x01,
  0x00,
  0xC9,
  0xFE,
  0x92,
  0xEF,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

final MemoryImage _transparentTileImage = MemoryImage(_transparentTileBytes);

class SafeOpenStreetMapHttpClient extends http.BaseClient {
  SafeOpenStreetMapHttpClient({http.BaseClient? inner})
    : _inner = inner ?? RetryClient(http.Client());

  final http.BaseClient _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_isOpenStreetMapTileRequest(request.url)) {
      return _inner.send(request);
    }

    final cacheFile = await _cacheFileFor(request.url);
    final cached = await _cachedTileResponse(request, cacheFile);
    if (cached != null) return cached;

    try {
      final response = await _inner.send(request);
      if (response.statusCode >= 400) {
        return _blankTileResponse(request);
      }

      final bytes = await response.stream.toBytes();
      await _storeTile(cacheFile, bytes);

      return _bytesTileResponse(
        request: request,
        bytes: bytes,
        statusCode: response.statusCode,
        headers: response.headers,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'OSM tile request failed, using transparent tile: ${request.url} | $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return _blankTileResponse(request);
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }

  static bool _isOpenStreetMapTileRequest(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'tile.openstreetmap.org' ||
        host.endsWith('.tile.openstreetmap.org');
  }

  static Future<File?> _cacheFileFor(Uri uri) async {
    if (kIsWeb) return null;

    final segments = uri.pathSegments;
    if (segments.length < 3) return null;

    try {
      final root = await getApplicationSupportDirectory();
      final z = segments[segments.length - 3];
      final x = segments[segments.length - 2];
      final y = segments.last.replaceAll(RegExp(r'[^0-9a-zA-Z_.-]'), '');
      return File(
        '${root.path}${Platform.pathSeparator}osm_tiles'
        '${Platform.pathSeparator}$z'
        '${Platform.pathSeparator}$x'
        '${Platform.pathSeparator}$y',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<http.StreamedResponse?> _cachedTileResponse(
    http.BaseRequest request,
    File? file,
  ) async {
    if (file == null) return null;

    try {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      return _bytesTileResponse(
        request: request,
        bytes: bytes,
        headers: const <String, String>{'content-type': 'image/png'},
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _storeTile(File? file, Uint8List bytes) async {
    if (file == null || bytes.isEmpty) return;

    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: false);
    } catch (_) {}
  }

  static http.StreamedResponse _bytesTileResponse({
    required http.BaseRequest request,
    required Uint8List bytes,
    int statusCode = 200,
    Map<String, String> headers = const <String, String>{},
  }) {
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      statusCode,
      request: request,
      headers: <String, String>{
        ...headers,
        'content-type': headers['content-type'] ?? 'image/png',
        'content-length': bytes.length.toString(),
      },
    );
  }

  static http.StreamedResponse _blankTileResponse(http.BaseRequest request) {
    return _bytesTileResponse(request: request, bytes: _transparentTileBytes);
  }
}

TileLayer buildSafeOpenStreetMapTileLayer({
  required String userAgentPackageName,
  double maxZoom = 19,
}) {
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: userAgentPackageName,
    maxZoom: maxZoom,
    panBuffer: 0,
    keepBuffer: 1,
    tileProvider: NetworkTileProvider(
      httpClient: SafeOpenStreetMapHttpClient(),
    ),
    errorImage: _transparentTileImage,
    errorTileCallback: (tile, error, stackTrace) {
      debugPrint('OSM tile render error ignored: $error');
    },
  );
}
