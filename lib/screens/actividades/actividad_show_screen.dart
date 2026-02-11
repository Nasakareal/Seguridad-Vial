import 'package:flutter/material.dart';

import '../../services/actividades_service.dart';
import '../../models/actividad.dart';

class ActividadShowScreen extends StatefulWidget {
  const ActividadShowScreen({super.key});

  @override
  State<ActividadShowScreen> createState() => _ActividadShowScreenState();
}

class _ActividadShowScreenState extends State<ActividadShowScreen> {
  bool _loading = true;
  String? _error;
  Actividad? _actividad;

  int? _idFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final v = args['actividad_id'] ?? args['id'];
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '');
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final id = _idFromArgs();
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Falta actividad_id';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final a = await ActividadesService.fetchShow(id);
      if (!mounted) return;
      setState(() {
        _actividad = a;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar.\n$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _actividad;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Detalle de actividad'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Center(child: Text(_error!)),
                )
              else if (a == null)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: Center(child: Text('Sin datos.')),
                )
              else ...[
                _card(
                  title: 'Información',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('ID', '#${a.id}'),
                      _kv('Categoría', a.categoria?.nombre ?? '—'),
                      _kv('Subcategoría', a.subcategoria?.nombre ?? '—'),
                      _kv('Nombre', a.nombre),
                      _kv('Cantidad', a.cantidad.toString()),
                      _kv('Creado', a.createdAt?.toString() ?? '—'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(title: 'Foto', child: _photoBlock(a)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoBlock(Actividad a) {
    final p = (a.fotoPath ?? '').trim();
    if (p.isEmpty) {
      return const Text('Sin foto.');
    }

    final url = ActividadesService.toPublicUrl(p);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade200,
            child: const Center(child: Text('No se pudo cargar la imagen.')),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$k:',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
