import 'package:flutter/material.dart';

class HeaderCard extends StatelessWidget {
  final bool trackingOn;
  final bool showTrackingStatus;

  const HeaderCard({
    super.key,
    required this.trackingOn,
    this.showTrackingStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = trackingOn ? Colors.green : Colors.red;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade800,
            Colors.blue.shade600,
            Colors.lightBlue.shade400,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, .62, 1],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: .32)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withValues(alpha: .12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: .30),
                  Colors.white.withValues(alpha: .12),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: .42)),
            ),
            child: const Icon(Icons.shield, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seguridad Vial',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                if (showTrackingStatus)
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        trackingOn ? 'Ubicación ACTIVA' : 'Ubicación NO ACTIVA',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
