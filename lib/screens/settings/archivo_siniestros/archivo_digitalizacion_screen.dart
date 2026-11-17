import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../models/archivo_siniestros/archivo_models.dart';
import '../../../services/archivo_siniestros_service.dart';
import 'widgets/archivo_ui.dart';

class ArchivoDigitalizacionScreen extends StatefulWidget {
  final ArchivoSiniestrosService service;
  final int libroId;
  const ArchivoDigitalizacionScreen({super.key, required this.service, required this.libroId});
  @override
  State<ArchivoDigitalizacionScreen> createState() => _ArchivoDigitalizacionScreenState();
}

class _ArchivoDigitalizacionScreenState extends State<ArchivoDigitalizacionScreen> {
  ArchivoPagina<ArchivoDocumento>? _data;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  int _page = 1;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load([int? page]) async {
    setState(() { _loading = true; _error = null; });
    try {
      final docs = await widget.service.getDocumentos(widget.libroId, page: page ?? _page);
      if (mounted) setState(() { _data = docs; _page = docs.currentPage; });
    } catch (error) { if (mounted) setState(() => _error = error); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _upload() async {
    if (_busy) return;
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (pick == null || pick.files.isEmpty || !mounted) return;
    final file = pick.files.single;
    if (file.path == null) {
      archivoToast(context, 'Se necesita una ruta local de archivo en el dispositivo.', error: true);
      return;
    }
    if (file.size > 7 * 1024 * 1024) {
      archivoToast(context, 'El archivo supera el límite actual de 7 MiB.', error: true);
      return;
    }
    final nombre = TextEditingController(text: file.name);
    final inicio = TextEditingController(text: '1');
    final fin = TextEditingController(text: '1');
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Subir documento'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: nombre, decoration: archivoInput('Nombre del documento')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: inicio, keyboardType: TextInputType.number, decoration: archivoInput('Página inicial'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: fin, keyboardType: TextInputType.number, decoration: archivoInput('Página final'))),
        ]),
        const SizedBox(height: 12),
        const Text('Indica el rango real de páginas del libro que contiene el archivo. No debe suponerse que un archivo equivale a todo el libro.',
          style: TextStyle(color: archivoMuted, fontSize: 12)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Subir')),
      ],
    ));
    final n = nombre.text.trim();
    final i = int.tryParse(inicio.text);
    final f = int.tryParse(fin.text);
    nombre.dispose(); inicio.dispose(); fin.dispose();
    if (accepted != true) return;
    if (n.isEmpty || i == null || f == null || i < 1 || f < i) {
      archivoToast(context, 'Revisa el nombre y el rango de páginas.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.service.subirDocumento(
        libroId: widget.libroId,
        ruta: file.path!, nombre: n, paginaInicio: i, paginaFin: f,
      );
      if (mounted) { archivoToast(context, 'Documento guardado para revisión'); await _load(1); }
    } catch (error) { if (mounted) archivoToast(context, error.toString(), error: true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _open(ArchivoDocumento documento) async {
    if (_busy) return;
    final permit = await archivoConfirmar(context, 'Abrir documento privado',
      'El documento se descargará temporalmente y se abrirá con un visor del dispositivo. Utiliza únicamente aplicaciones autorizadas.');
    if (!permit) return;
    setState(() => _busy = true);
    try {
      final bytes = await widget.service.descargarDocumento(widget.libroId, documento.id);
      final temp = await getTemporaryDirectory();
      final extension = documento.mimeType.contains('pdf') ? '.pdf'
        : documento.mimeType.contains('png') ? '.png' : '.jpg';
      final file = File('${temp.path}/archivo_siniestros_${widget.libroId}_${documento.id}$extension');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        archivoToast(context, 'No hay un visor compatible: ${result.message}', error: true);
      }
    } catch (error) { if (mounted) archivoToast(context, error.toString(), error: true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _limpiarCopias() async {
    final approved = await archivoConfirmar(context, 'Limpiar copias temporales',
      'Se eliminarán las copias temporales de los documentos de este libro guardadas por esta pantalla.');
    if (!approved) return;
    try {
      final temp = await getTemporaryDirectory();
      var total = 0;
      await for (final file in temp.list()) {
        if (file is File && file.uri.pathSegments.last.startsWith('archivo_siniestros_${widget.libroId}_')) {
          await file.delete();
          total++;
        }
      }
      if (mounted) archivoToast(context, 'Copias eliminadas: $total');
    } catch (error) {
      if (mounted) archivoToast(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ArchivoLayout(
    title: 'Digitalización', subtitle: 'Consulta privada de documentos escaneados',
    actions: [
      IconButton(onPressed: _busy ? null : _limpiarCopias, icon: const Icon(Icons.delete_sweep_outlined), tooltip: 'Limpiar copias temporales'),
      IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
    ],
    floatingActionButton: FloatingActionButton.extended(onPressed: _busy ? null : _upload,
      icon: const Icon(Icons.upload_file), label: const Text('Subir archivo')),
    child: _loading && _data == null ? const ArchivoLoading()
      : _error != null && _data == null ? ArchivoError(error: _error!, retry: _load)
      : RefreshIndicator(onRefresh: () => _load(_page), child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 82), children: [
          const Card(child: Padding(padding: EdgeInsets.all(14),
            child: Text('Archivos PDF/JPG/PNG de hasta 7 MiB. Su contenido sigue protegido en Laravel; no se publican enlaces directos.'))),
          if (_busy || _loading) const LinearProgressIndicator(),
          if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error.toString(), style: const TextStyle(color: Colors.red))),
          Padding(padding: const EdgeInsets.all(10),
            child: Text('${_data?.total ?? 0} documentos', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
          if (_data?.items.isEmpty ?? true) const ArchivoVacio('Aún no hay documentos escaneados.'),
          for (final doc in _data?.items ?? <ArchivoDocumento>[]) Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(doc.mimeType.contains('pdf') ? Icons.picture_as_pdf : Icons.image_outlined, color: archivoTeal),
              title: Text(doc.nombre, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Páginas ${doc.paginaInicio}–${doc.paginaFin} · ${archivoEtiqueta(doc.estado)} · ${(doc.tamanoBytes / 1024).toStringAsFixed(0)} KB'),
              trailing: const Icon(Icons.open_in_new),
              onTap: _busy ? null : () => _open(doc),
            ),
          ),
          if (_data != null) ArchivoPaginacion(page: _page, lastPage: _data!.lastPage, onChanged: _load),
        ],
      )),
  );
}
