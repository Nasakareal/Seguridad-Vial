import 'package:flutter/material.dart';

class QuickActionsGrid extends StatelessWidget {
  final bool canAccidentes;
  final bool canMapa;

  final VoidCallback onAccidentes;
  final VoidCallback onMapa;

  const QuickActionsGrid({
    super.key,
    required this.canAccidentes,
    required this.canMapa,
    required this.onAccidentes,
    required this.onMapa,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];

    if (canMapa) {
      actions.add(
        Expanded(
          child: _QuickCard(
            icon: Icons.map,
            title: 'Mapa de Patrullas',
            subtitle: 'Ubicaciones activas',
            onTap: onMapa,
          ),
        ),
      );
    }

    if (canMapa && canAccidentes) {
      actions.add(const SizedBox(width: 12));
    }

    if (canAccidentes) {
      actions.add(
        Expanded(
          child: _QuickCard(
            icon: Icons.directions_car,
            title: 'Siniestros',
            subtitle: 'Listado y registros',
            onTap: onAccidentes,
          ),
        ),
      );
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(children: actions);
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
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
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.blue, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}
