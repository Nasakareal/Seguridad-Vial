import 'package:flutter/material.dart';
import '../../../models/feed_item.dart';
import '../../../services/guardianes_camino_dispositivos_service.dart';
import '../../../widgets/safe_network_image.dart';

class FeedPostCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback onTap;

  const FeedPostCard({super.key, required this.item, required this.onTap});

  String get _typeLabel {
    if (item.type == FeedItemType.hecho) return 'SINIESTRO';
    if (item.type == FeedItemType.actividad) return 'PROXIMIDAD SOCIAL';
    if (item.type == FeedItemType.carreteras) return 'CARRETERAS';
    if (item.type == FeedItemType.vialidades) return 'VIALIDADES';
    return 'PUBLICACIÓN';
  }

  IconData get _icon {
    if (item.type == FeedItemType.hecho) return Icons.car_crash;
    if (item.type == FeedItemType.actividad) return Icons.camera_alt;
    if (item.type == FeedItemType.carreteras) return Icons.add_road;
    if (item.type == FeedItemType.vialidades) return Icons.traffic;
    return Icons.feed;
  }

  @override
  Widget build(BuildContext context) {
    final resumen = item.resumen.trim();
    final subtitle = resumen.isNotEmpty ? resumen : 'Publicación';

    final userName = item.userName.trim();
    final user = userName.isNotEmpty ? userName : 'Usuario';

    final rawFoto = (item.fotoUrl ?? '').trim();
    final normalizedFoto = rawFoto.isEmpty
        ? ''
        : GuardianesCaminoDispositivosService.toPublicUrl(rawFoto);
    final fotoUrl = normalizedFoto.isNotEmpty ? normalizedFoto : null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                offset: const Offset(0, 8),
                color: Colors.black.withValues(alpha: .06),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_icon, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Text(
                                  _typeLabel,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 13.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (fotoUrl != null) ...[
                Divider(height: 1, color: Colors.grey.shade200),
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  child: BigFeedImage(url: fotoUrl),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class BigFeedImage extends StatelessWidget {
  final String url;
  const BigFeedImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade100,
      child: AspectRatio(
        aspectRatio: 1,
        child: SafeNetworkImage(
          url,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          loadingBuilder: (context, progress) =>
              const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, __, ___) => Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.grey.shade500,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }
}
