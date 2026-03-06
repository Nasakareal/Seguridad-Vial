import 'package:flutter/material.dart';

class QuickActionsGrid extends StatelessWidget {
  final bool canAccidentes;
  final bool canGruas;
  final bool canMapa;
  final bool canSustento;
  final bool canBuscar;

  final VoidCallback onAccidentes;
  final VoidCallback onGruas;
  final VoidCallback onMapa;
  final VoidCallback onSustentoLegal;
  final VoidCallback onBuscar;

  const QuickActionsGrid({
    super.key,
    required this.canAccidentes,
    required this.canGruas,
    required this.canMapa,
    required this.canSustento,
    required this.canBuscar,
    required this.onAccidentes,
    required this.onGruas,
    required this.onMapa,
    required this.onSustentoLegal,
    required this.onBuscar,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    final row1 = <Widget>[];
    if (canBuscar) {
      row1.add(
        Expanded(
          child: _QuickCard(
            icon: Icons.search,
            title: 'Búsqueda',
            subtitle: 'Por placa, serie, conductor…',
            onTap: onBuscar,
          ),
        ),
      );
    }
    if (canAccidentes) {
      if (row1.isNotEmpty) row1.add(const SizedBox(width: 12));
      row1.add(
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
    if (row1.isNotEmpty) rows.add(Row(children: row1));

    final row2 = <Widget>[];
    if (canGruas) {
      row2.add(
        Expanded(
          child: _QuickCard(
            icon: Icons.local_shipping,
            title: 'Grúas',
            subtitle: 'Listado y gráfica',
            onTap: onGruas,
          ),
        ),
      );
    }
    if (canMapa) {
      if (row2.isNotEmpty) row2.add(const SizedBox(width: 12));
      row2.add(
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
    if (row2.isNotEmpty) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
      rows.add(Row(children: row2));
    }

    final row3 = <Widget>[];
    if (canSustento) {
      row3.add(
        Expanded(
          child: _QuickCard(
            icon: Icons.gavel,
            title: 'Sustento Legal',
            subtitle: 'Catálogo y consulta',
            onTap: onSustentoLegal,
          ),
        ),
      );
    }
    if (row3.isNotEmpty) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
      rows.add(Row(children: row3));
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(children: rows);
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
                color: Colors.black.withOpacity(.06),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(.10),
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
