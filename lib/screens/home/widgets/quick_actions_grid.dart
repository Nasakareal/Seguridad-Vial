import 'package:flutter/material.dart';

import '../../../widgets/glass.dart';

class QuickActionsGrid extends StatelessWidget {
  final bool canAccidentes;
  final bool canMapa;
  final bool canConstancias;

  final VoidCallback onAccidentes;
  final VoidCallback onMapa;
  final VoidCallback? onConstancias;

  const QuickActionsGrid({
    super.key,
    required this.canAccidentes,
    required this.canMapa,
    this.canConstancias = false,
    required this.onAccidentes,
    required this.onMapa,
    this.onConstancias,
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

    if (canConstancias && onConstancias != null) {
      if (actions.isNotEmpty) {
        actions.add(const SizedBox(width: 12));
      }
      actions.add(
        Expanded(
          child: _QuickCard(
            icon: Icons.badge,
            title: 'Constancias de manejo',
            subtitle: 'Alta y captura',
            onTap: onConstancias!,
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
    const radius = BorderRadius.all(Radius.circular(18));

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 190;

        return LiquidGlassSurface(
          borderRadius: radius,
          padding: EdgeInsets.zero,
          opacity: .84,
          blur: 9,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(compact ? 12 : 14),
                child: Row(
                  children: [
                    Container(
                      width: compact ? 40 : 44,
                      height: compact ? 40 : 44,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .90),
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.blue.shade700,
                        size: compact ? 23 : 26,
                      ),
                    ),
                    SizedBox(width: compact ? 9 : 12),
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
                              fontSize: compact ? 12 : 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: Colors.grey.shade500),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
