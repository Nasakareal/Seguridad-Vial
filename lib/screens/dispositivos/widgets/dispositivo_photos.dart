import 'package:flutter/material.dart';

import '../../../services/guardianes_camino_dispositivos_service.dart';
import '../../../widgets/safe_network_image.dart';

class DispositivoPhotoPreview extends StatelessWidget {
  final List<String> urls;

  const DispositivoPhotoPreview({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedUrls(urls);
    if (resolved.isEmpty) return const SizedBox.shrink();

    final first = resolved.first;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Material(
            color: const Color(0xFFE2E8F0),
            child: InkWell(
              onTap: () => showDispositivoPhotoDialog(context, first),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SafeNetworkImage(
                    first,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    loadingBuilder: (context, progress) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorBuilder: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image, size: 34)),
                  ),
                  if (resolved.length > 1)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '+${resolved.length - 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DispositivoPhotosStrip extends StatelessWidget {
  final List<String> urls;

  const DispositivoPhotosStrip({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedUrls(urls);
    if (resolved.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: resolved.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final url = resolved[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: Material(
                  color: const Color(0xFFE2E8F0),
                  child: InkWell(
                    onTap: () => showDispositivoPhotoDialog(context, url),
                    child: SafeNetworkImage(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, progress) => const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

void showDispositivoPhotoDialog(BuildContext context, String rawUrl) {
  final url = GuardianesCaminoDispositivosService.toPublicUrl(rawUrl);
  if (url.isEmpty) return;

  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InteractiveViewer(
          child: SafeNetworkImage(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No se pudo cargar la imagen.'),
            ),
          ),
        ),
      ),
    ),
  );
}

List<String> _resolvedUrls(List<String> urls) {
  return urls
      .map(GuardianesCaminoDispositivosService.toPublicUrl)
      .where((url) => url.trim().isNotEmpty)
      .toSet()
      .toList();
}
