import 'package:flutter/material.dart';
import '../../../models/archivo_siniestros/archivo_models.dart';
import '../../../services/archivo_siniestros_service.dart';
import 'archivo_libro_form_screen.dart';
import 'archivo_libro_detalle_screen.dart';
import 'widgets/archivo_ui.dart';

class ArchivoLibrosScreen extends StatefulWidget {
  final ArchivoSiniestrosService service;
  const ArchivoLibrosScreen({super.key, required this.service});
  @override
  State<ArchivoLibrosScreen> createState() => _ArchivoLibrosScreenState();
}

class _ArchivoLibrosScreenState extends State<ArchivoLibrosScreen> {
  final _q = TextEditingController();
  final _anio = TextEditingController();
  String? _estado;
  ArchivoPagina<ArchivoLibro>? _data;
  bool _loading = true;
  int _page = 1;
  Object? _error;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _q.dispose(); _anio.dispose(); super.dispose(); }

  Future<void> _load([int? page]) async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.service.getLibros(
        q: _q.text.trim(), anio: int.tryParse(_anio.text),
        estadoFisico: _estado, page: page ?? _page,
      );
      if (mounted) setState(() { _data = result; _page = result.currentPage; });
    } catch (error) { if (mounted) setState(() => _error = error); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
      .then((_) { if (mounted) _load(_page); });

  @override
  Widget build(BuildContext context) => ArchivoLayout(
    title: 'Libros de siniestros', subtitle: 'Búsqueda e inventario físico/digital',
    actions: [IconButton(onPressed: () => _load(_page), icon: const Icon(Icons.refresh))],
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _open(ArchivoLibroFormScreen(service: widget.service)),
      icon: const Icon(Icons.add), label: const Text('Registrar libro'),
    ),
    child: _loading && _data == null ? const ArchivoLoading()
      : _error != null && _data == null ? ArchivoError(error: _error!, retry: _load)
      : RefreshIndicator(onRefresh: () => _load(_page), child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
        children: [
          ArchivoSection(title: 'Buscar libro', child: Column(children: [
            TextField(
              controller: _q,
              onSubmitted: (_) => _load(1),
              decoration: archivoInput('Folio, código o título', icon: Icons.search),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _anio, keyboardType: TextInputType.number,
                onSubmitted: (_) => _load(1), decoration: archivoInput('Año (opcional)'))),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String?>(
                value: _estado,
                isExpanded: true,
                decoration: archivoInput('Estado físico'),
                items: const [
                  DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                  DropdownMenuItem<String?>(value: 'por_ubicar', child: Text('Por ubicar')),
                  DropdownMenuItem<String?>(value: 'almacenado', child: Text('Almacenado')),
                  DropdownMenuItem<String?>(value: 'retirado', child: Text('Retirado')),
                ],
                onChanged: (value) => setState(() => _estado = value),
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: () => _load(1), icon: const Icon(Icons.search), label: const Text('Buscar'))),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: () { _q.clear(); _anio.clear(); setState(() => _estado = null); _load(1); },
                tooltip: 'Limpiar filtros', icon: const Icon(Icons.restart_alt)),
            ]),
          ])),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error.toString(), style: const TextStyle(color: Colors.red))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Text('${_data?.total ?? 0} libros encontrados', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
          if (_data?.items.isEmpty ?? true) const ArchivoVacio('No se encontraron libros para estos filtros.'),
          for (final libro in _data?.items ?? <ArchivoLibro>[]) Card(
            margin: const EdgeInsets.only(bottom: 9),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFCCFBF1), foregroundColor: archivoTeal,
                child: Icon(Icons.menu_book_outlined)),
              title: Text(libro.titulo.isEmpty ? libro.codigo : libro.titulo,
                style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('${libro.codigo}  ·  ${libro.anioInicio ?? 'Sin año'}\n${libro.ubicacionTexto}\n${archivoEtiqueta(libro.estadoFisico)} · ${archivoEtiqueta(libro.estadoDigitalizacion)}'),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(ArchivoLibroDetalleScreen(service: widget.service, libroId: libro.id)),
            ),
          ),
          if (_data != null) ArchivoPaginacion(page: _page, lastPage: _data!.lastPage, onChanged: _load),
        ],
      )),
  );
}
