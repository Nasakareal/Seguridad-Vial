import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/persistent_network_image_cache.dart';

typedef SafeNetworkImageErrorBuilder =
    Widget Function(
      BuildContext context,
      Object? error,
      StackTrace? stackTrace,
    );
typedef SafeNetworkImageLoadingBuilder =
    Widget Function(BuildContext context, ImageChunkEvent progress);

class SafeNetworkImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final SafeNetworkImageErrorBuilder? errorBuilder;
  final SafeNetworkImageLoadingBuilder? loadingBuilder;
  final Map<String, String>? headers;
  final bool cacheFailedUrls;
  final Duration cacheDuration;
  final bool persistToDisk;

  const SafeNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.errorBuilder,
    this.loadingBuilder,
    this.headers,
    this.cacheFailedUrls = true,
    this.cacheDuration = const Duration(days: 1),
    this.persistToDisk = true,
  });

  @override
  State<SafeNetworkImage> createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<SafeNetworkImage> {
  static final Map<String, DateTime> _failedUntil = <String, DateTime>{};
  static const Duration _failureCooldown = Duration(minutes: 1);

  File? _cachedFile;
  Object? _error;
  StackTrace? _stackTrace;
  bool _loading = true;
  bool _downloadAttempted = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  @override
  void didUpdateWidget(covariant SafeNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url.trim() != widget.url.trim() ||
        oldWidget.persistToDisk != widget.persistToDisk ||
        oldWidget.cacheDuration != widget.cacheDuration) {
      unawaited(_resolve());
    }
  }

  Future<void> _resolve() async {
    final generation = ++_generation;
    final normalizedUrl = widget.url.trim();
    _cachedFile = null;
    _error = null;
    _stackTrace = null;
    _loading = true;
    _downloadAttempted = false;

    if (normalizedUrl.isEmpty) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = const FormatException('URL de imagen vacía.');
        });
      }
      return;
    }

    if (kIsWeb || !widget.persistToDisk) {
      if (mounted && generation == _generation) setState(() {});
      return;
    }

    final cached = await PersistentNetworkImageCache.instance.lookup(
      normalizedUrl,
      maxAge: widget.cacheDuration,
    );
    if (!mounted || generation != _generation) return;

    if (cached != null) {
      setState(() {
        _cachedFile = cached.file;
        _loading = false;
      });
      if (cached.isFresh) return;
    }

    await _download(normalizedUrl, generation: generation);
  }

  Future<void> _download(
    String normalizedUrl, {
    required int generation,
  }) async {
    if (_downloadAttempted) return;
    _downloadAttempted = true;

    final failedUntil = _failedUntil[normalizedUrl];
    if (widget.cacheFailedUrls &&
        failedUntil != null &&
        failedUntil.isAfter(DateTime.now())) {
      if (_cachedFile == null && mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = const HttpException(
            'La imagen está temporalmente fuera de línea.',
          );
        });
      }
      return;
    }

    try {
      final file = await PersistentNetworkImageCache.instance.download(
        normalizedUrl,
        headers: widget.headers,
      );
      await _evictFile(file);
      _failedUntil.remove(normalizedUrl);
      if (!mounted || generation != _generation) return;
      setState(() {
        _cachedFile = file;
        _loading = false;
        _error = null;
        _stackTrace = null;
      });
    } catch (error, stackTrace) {
      if (widget.cacheFailedUrls) {
        _failedUntil[normalizedUrl] = DateTime.now().add(_failureCooldown);
      }
      if (!mounted || generation != _generation || _cachedFile != null) return;
      setState(() {
        _loading = false;
        _error = error;
        _stackTrace = stackTrace;
      });
    }
  }

  Future<void> _evictFile(File file) async {
    final provider = FileImage(file);
    await provider.evict();
    final resized = ResizeImage.resizeIfNeeded(
      widget.cacheWidth,
      widget.cacheHeight,
      provider,
    );
    await resized.evict();
  }

  void _handleDecodeError(Object error, StackTrace? stackTrace) {
    final normalizedUrl = widget.url.trim();
    final generation = _generation;
    final shouldRetry = !_downloadAttempted;
    unawaited(
      PersistentNetworkImageCache.instance.remove(normalizedUrl).then((_) {
        if (!mounted || generation != _generation) return;
        if (shouldRetry) {
          setState(() {
            _cachedFile = null;
            _error = null;
            _stackTrace = null;
            _loading = true;
          });
          unawaited(_download(normalizedUrl, generation: generation));
          return;
        }
        setState(() {
          _cachedFile = null;
          _error = error;
          _stackTrace = stackTrace;
          _loading = false;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = widget.url.trim();
    if (normalizedUrl.isEmpty) {
      return _buildError(context, _error, _stackTrace);
    }

    if (kIsWeb || !widget.persistToDisk) {
      return _buildNetworkImage(normalizedUrl);
    }

    final file = _cachedFile;
    if (file != null) {
      return Image.file(
        file,
        width: widget.width,
        height: widget.height,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        fit: widget.fit,
        alignment: widget.alignment,
        filterQuality: widget.filterQuality,
        errorBuilder: (context, error, stackTrace) {
          _handleDecodeError(error, stackTrace);
          return _buildError(context, error, stackTrace);
        },
      );
    }

    if (_loading) {
      return _buildLoading(context);
    }

    return _buildError(context, _error, _stackTrace);
  }

  Widget _buildNetworkImage(String normalizedUrl) {
    return Image.network(
      normalizedUrl,
      width: widget.width,
      height: widget.height,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      fit: widget.fit,
      alignment: widget.alignment,
      filterQuality: widget.filterQuality,
      headers: widget.headers,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        final builder = widget.loadingBuilder;
        if (builder != null) return builder(context, progress);
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildError(context, error, stackTrace);
      },
    );
  }

  Widget _buildLoading(BuildContext context) {
    final builder = widget.loadingBuilder;
    if (builder != null) {
      return TickerMode(
        enabled: false,
        child: builder(
          context,
          ImageChunkEvent(cumulativeBytesLoaded: 0, expectedTotalBytes: null),
        ),
      );
    }
    return const TickerMode(
      enabled: false,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildError(
    BuildContext context,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final builder = widget.errorBuilder;
    if (builder != null) {
      return builder(context, error, stackTrace);
    }
    return const SizedBox.shrink();
  }
}
