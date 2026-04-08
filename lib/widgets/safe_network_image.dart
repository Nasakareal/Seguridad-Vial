import 'package:flutter/material.dart';

typedef SafeNetworkImageErrorBuilder =
    Widget Function(
      BuildContext context,
      Object? error,
      StackTrace? stackTrace,
    );
typedef SafeNetworkImageLoadingBuilder =
    Widget Function(BuildContext context, ImageChunkEvent progress);

class SafeNetworkImage extends StatelessWidget {
  static final Set<String> _failedUrls = <String>{};

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final SafeNetworkImageErrorBuilder? errorBuilder;
  final SafeNetworkImageLoadingBuilder? loadingBuilder;
  final Map<String, String>? headers;
  final bool cacheFailedUrls;

  const SafeNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.errorBuilder,
    this.loadingBuilder,
    this.headers,
    this.cacheFailedUrls = true,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      return _buildError(context, null, null);
    }

    if (cacheFailedUrls && _failedUrls.contains(normalizedUrl)) {
      return _buildError(context, null, null);
    }

    return Image.network(
      normalizedUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      headers: headers,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        final builder = loadingBuilder;
        if (builder != null) return builder(context, progress);
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        if (cacheFailedUrls) {
          _failedUrls.add(normalizedUrl);
        }
        return _buildError(context, error, stackTrace);
      },
    );
  }

  Widget _buildError(
    BuildContext context,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final builder = errorBuilder;
    if (builder != null) {
      return builder(context, error, stackTrace);
    }
    return const SizedBox.shrink();
  }
}
