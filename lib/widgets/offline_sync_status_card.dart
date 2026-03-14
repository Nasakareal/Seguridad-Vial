import 'package:flutter/material.dart';

import '../services/offline_sync_service.dart';

class OfflineSyncStatusCard extends StatelessWidget {
  const OfflineSyncStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: OfflineSyncService.pendingCount,
      builder: (context, pending, _) {
        return ValueListenableBuilder<int>(
          valueListenable: OfflineSyncService.failedCount,
          builder: (context, failed, __) {
            if (pending <= 0 && failed <= 0) {
              return const SizedBox.shrink();
            }

            final hasFailed = failed > 0;
            final color = hasFailed ? Colors.orange : Colors.teal;
            final message = hasFailed
                ? 'Hay $failed registro(s) que requieren revisión antes de sincronizar.'
                : 'Hay $pending registro(s) guardados sin conexión. Se enviarán cuando regrese internet.';

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: color.withOpacity(0.08),
                border: Border.all(color: color.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Icon(
                    hasFailed
                        ? Icons.error_outline
                        : Icons.cloud_upload_outlined,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: color.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () async {
                      await OfflineSyncService.flushPending(
                        force: true,
                        announceSkipped: true,
                      );
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
