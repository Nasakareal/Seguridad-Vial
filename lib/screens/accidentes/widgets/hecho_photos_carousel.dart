import 'package:flutter/material.dart';

import '../../../widgets/photo_viewer.dart';
import '../../../widgets/safe_network_image.dart';

class HechoPhotosCarousel extends StatefulWidget {
  const HechoPhotosCarousel({
    super.key,
    required this.primaryUrl,
    required this.secondaryUrl,
  });

  final String primaryUrl;
  final String secondaryUrl;

  @override
  State<HechoPhotosCarousel> createState() => _HechoPhotosCarouselState();
}

class _HechoPhotosCarouselState extends State<HechoPhotosCarousel> {
  late final PageController _controller;
  int _currentPage = 0;

  List<String> get _urls {
    final result = <String>[];
    for (final raw in <String>[widget.primaryUrl, widget.secondaryUrl]) {
      final url = raw.trim();
      if (url.isNotEmpty && !result.contains(url)) result.add(url);
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void didUpdateWidget(covariant HechoPhotosCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primaryUrl == widget.primaryUrl &&
        oldWidget.secondaryUrl == widget.secondaryUrl) {
      return;
    }
    _currentPage = 0;
    if (_controller.hasClients) _controller.jumpToPage(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (urls.isEmpty) return const SizedBox.shrink();
    final hasMultiple = urls.length > 1;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            hasMultiple ? 'Fotos del hecho' : 'Foto del hecho',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: hasMultiple
                  ? Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        PageView.builder(
                          controller: _controller,
                          itemCount: urls.length,
                          onPageChanged: (page) {
                            setState(() => _currentPage = page);
                          },
                          itemBuilder: (_, index) => _photo(urls[index], index),
                        ),
                        if (_currentPage > 0)
                          _arrow(
                            alignment: Alignment.centerLeft,
                            icon: Icons.chevron_left,
                            tooltip: 'Foto anterior',
                            onPressed: () => _goTo(_currentPage - 1),
                          ),
                        if (_currentPage < urls.length - 1)
                          _arrow(
                            alignment: Alignment.centerRight,
                            icon: Icons.chevron_right,
                            tooltip: 'Siguiente foto',
                            onPressed: () => _goTo(_currentPage + 1),
                          ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .62),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${_currentPage + 1} / ${urls.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _photo(urls.first, 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photo(String url, int index) {
    return InkWell(
      onTap: () => showPhotoViewer(
        context: context,
        title: 'Foto ${index + 1} del hecho',
        photoUrl: url,
      ),
      child: SafeNetworkImage(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image),
        ),
        loadingBuilder: (_, __) => Container(
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }

  Widget _arrow({
    required Alignment alignment,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Material(
          color: Colors.black.withValues(alpha: .55),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}
