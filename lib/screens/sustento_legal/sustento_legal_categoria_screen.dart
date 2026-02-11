import 'package:flutter/material.dart';
import 'sustento_legal_data.dart';

class SustentoLegalCategoriaScreen extends StatelessWidget {
  const SustentoLegalCategoriaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map?) ??
        <String, dynamic>{};

    final String categoriaId = (args['categoriaId'] ?? '').toString();
    final String titulo = (args['titulo'] ?? 'Sustento Legal').toString();

    final items = kLegalItems
        .where((e) => e.categoriaId == categoriaId)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar',
            onPressed: () =>
                Navigator.pushNamed(context, '/sustento-legal/buscar'),
          ),
        ],
      ),
      body: items.isEmpty
          ? _EmptyState(
              title: 'Sin contenido aún',
              subtitle:
                  'Aún no hay fichas cargadas para esta categoría.\n(Se agregan en sustento_legal_data.dart)',
              onGoSearch: () =>
                  Navigator.pushNamed(context, '/sustento-legal/buscar'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _LegalCard(item: items[i]),
            ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  final LegalItem item;
  const _LegalCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pushNamed(
          context,
          '/sustento-legal/detalle',
          arguments: {'id': item.id},
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.titulo,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(item.resumen, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.fundamento
                  .map(
                    (f) => Chip(
                      label: Text(f, style: const TextStyle(fontSize: 12)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onGoSearch;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.onGoSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 52, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onGoSearch,
              icon: const Icon(Icons.search),
              label: const Text('Buscar fundamentos'),
            ),
          ],
        ),
      ),
    );
  }
}
