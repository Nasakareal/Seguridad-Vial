import 'package:flutter/material.dart';
import 'sustento_legal_data.dart';

class SustentoLegalBusquedaScreen extends StatefulWidget {
  const SustentoLegalBusquedaScreen({super.key});

  @override
  State<SustentoLegalBusquedaScreen> createState() =>
      _SustentoLegalBusquedaScreenState();
}

class _SustentoLegalBusquedaScreenState
    extends State<SustentoLegalBusquedaScreen> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<LegalItem> _results() {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return const [];

    bool hit(LegalItem it) {
      final haystack = <String>[
        it.titulo,
        it.resumen,
        it.categoriaId,
        ...it.fundamento,
        ...it.keywords,
        ...it.permite,
        ...it.noPermite,
        ...it.pasos,
      ].join(' ').toLowerCase();

      return haystack.contains(q);
    }

    final res = kLegalItems.where(hit).toList();

    // orden simple: primero coincidencias en título, luego resto
    res.sort((a, b) {
      final at = a.titulo.toLowerCase().contains(q) ? 0 : 1;
      final bt = b.titulo.toLowerCase().contains(q) ? 0 : 1;
      return at.compareTo(bt);
    });

    return res;
  }

  @override
  Widget build(BuildContext context) {
    final results = _results();

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar sustento legal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText:
                    'Ej: flagrancia, revisión, custodia, art 16, CNPP 146…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _ctrl.clear();
                            _q = '';
                          });
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 12),

            if (_q.trim().isEmpty)
              Expanded(child: _Hint())
            else if (results.isEmpty)
              Expanded(child: _Empty(q: _q.trim()))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final it = results[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/sustento-legal/detalle',
                          arguments: {'id': it.id},
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.titulo,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              it.resumen,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: it.fundamento
                                  .take(3)
                                  .map(
                                    (f) => Chip(
                                      label: Text(
                                        f,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 52, color: Colors.grey.shade600),
            const SizedBox(height: 10),
            const Text(
              'Escribe una palabra clave',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ejemplos: “flagrancia”, “CNPP 146”, “custodia”, “uso de la fuerza”.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String q;
  const _Empty({required this.q});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 52, color: Colors.grey.shade600),
            const SizedBox(height: 10),
            Text(
              'Sin resultados para “$q”',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Intenta con otra palabra o agrega más fichas en sustento_legal_data.dart',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
