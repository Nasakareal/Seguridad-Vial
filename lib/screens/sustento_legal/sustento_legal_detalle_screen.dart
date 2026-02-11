import 'package:flutter/material.dart';
import 'sustento_legal_data.dart';

class SustentoLegalDetalleScreen extends StatelessWidget {
  const SustentoLegalDetalleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map?) ??
        <String, dynamic>{};

    final String id = (args['id'] ?? '').toString();

    final LegalItem? item = kLegalItems
        .where((e) => e.id == id)
        .cast<LegalItem?>()
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () =>
                Navigator.pushNamed(context, '/sustento-legal/buscar'),
          ),
        ],
      ),
      body: item == null
          ? const _NotFound()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  item.titulo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),
                Text(item.resumen),

                if (item.reglaRapida.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Regla rápida',
                    child: Text(item.reglaRapida),
                  ),
                ],

                if (item.aplicaCuando.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Aplica cuando',
                    child: _Bullets(items: item.aplicaCuando),
                  ),
                ],

                const SizedBox(height: 12),
                _Section(
                  title: 'Fundamento',
                  child: _FundamentoBlocks(items: item.fundamento),
                ),

                if (item.requisitos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Requisitos',
                    child: _Bullets(items: item.requisitos),
                  ),
                ],

                const SizedBox(height: 12),
                _Section(
                  title: 'Qué SÍ autoriza',
                  child: _Bullets(items: item.permite),
                ),

                const SizedBox(height: 12),
                _Section(
                  title: 'Qué NO autoriza',
                  child: _Bullets(items: item.noPermite),
                ),

                if (item.documenta.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Debes documentar',
                    child: _Bullets(items: item.documenta),
                  ),
                ],

                const SizedBox(height: 12),
                _Section(
                  title: 'Qué sigue (operativo)',
                  child: _Bullets(items: item.pasos),
                ),

                if (item.erroresComunes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Errores comunes',
                    child: _Bullets(items: item.erroresComunes),
                  ),
                ],

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar'),
                        onPressed: () {
                          final text = _buildShareText(item);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Copiado (${text.length} caracteres)',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar otro'),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/sustento-legal/buscar',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  String _buildShareText(LegalItem item) {
    final b = StringBuffer();
    b.writeln(item.titulo);
    b.writeln(item.resumen);
    b.writeln('');

    void add(String title, List<String> items) {
      if (items.isEmpty) return;
      b.writeln(title);
      for (final i in items) {
        b.writeln('- $i');
      }
      b.writeln('');
    }

    add('Aplica cuando:', item.aplicaCuando);
    add('Fundamento:', item.fundamento);
    add('Requisitos:', item.requisitos);
    add('SÍ autoriza:', item.permite);
    add('NO autoriza:', item.noPermite);
    add('Debes documentar:', item.documenta);
    add('Qué sigue:', item.pasos);
    add('Errores comunes:', item.erroresComunes);

    return b.toString().trim();
  }
}

class _FundamentoBlocks extends StatelessWidget {
  final List<String> items;
  const _FundamentoBlocks({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width - 64;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((f) {
        return Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Text(f, softWrap: true, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  final List<String> items;
  const _Bullets({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((t) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(fontSize: 16)),
              Expanded(child: Text(t)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No se encontró el contenido'));
  }
}

extension _FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
