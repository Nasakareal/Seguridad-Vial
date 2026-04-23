import 'package:flutter/material.dart';
import '../../models/feed_item.dart';
import '../../services/guardianes_camino_dispositivos_service.dart';
import '../safe_network_image.dart';

class FeedItemCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback onTap;

  const FeedItemCard({super.key, required this.item, required this.onTap});

  IconData get _icon {
    switch (item.type) {
      case FeedItemType.hecho:
        return Icons.car_crash;
      case FeedItemType.actividad:
        return Icons.photo_camera;
      case FeedItemType.carreteras:
        return Icons.add_road;
      case FeedItemType.vialidades:
        return Icons.traffic;
    }
  }

  String get _typeLabel {
    switch (item.type) {
      case FeedItemType.hecho:
        return 'SINIESTRO';
      case FeedItemType.actividad:
        return 'PROXIMIDAD SOCIAL';
      case FeedItemType.carreteras:
        return 'CARRETERAS';
      case FeedItemType.vialidades:
        return 'VIALIDADES';
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumen = item.resumen.trim().isNotEmpty
        ? item.resumen.trim()
        : 'Publicación';
    final rawFoto = (item.fotoUrl ?? '').trim();
    final normalizedFoto = rawFoto.isEmpty
        ? ''
        : GuardianesCaminoDispositivosService.toPublicUrl(rawFoto);
    final fotoUrl = normalizedFoto.isNotEmpty ? normalizedFoto : null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                offset: const Offset(0, 8),
                color: Colors.black.withValues(alpha: .06),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.grey.shade200),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.userName.isNotEmpty
                                ? item.userName
                                : 'Usuario',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      resumen,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (fotoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SafeNetworkImage(
                    fotoUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _noImage(),
                  ),
                )
              else
                _noImage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Icon(Icons.image_not_supported, color: Colors.grey.shade500),
    );
  }
}
