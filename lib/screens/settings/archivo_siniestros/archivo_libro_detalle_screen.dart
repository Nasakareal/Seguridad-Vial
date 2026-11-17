import 'package:flutter/material.dart';

import '../../../models/archivo_siniestros/archivo_models.dart';
import '../../../services/archivo_siniestros_service.dart';
import 'archivo_digitalizacion_screen.dart';
import 'archivo_libro_form_screen.dart';
import 'archivo_escaner_qr_screen.dart';
import 'widgets/archivo_ui.dart';

class ArchivoLibroDetalleScreen extends StatefulWidget {
  final ArchivoSiniestrosService service;
  final int libroId;
  const ArchivoLibroDetalleScreen({super.key, required this.service, required this.libroId});
  @override
  State<ArchivoLibroDetalleScreen> createState() => _ArchivoLibroDetalleScreenState();
}

class _ArchivoLibroDetalleScreenState extends State<ArchivoLibroDetalleScreen> {
  ArchivoLibro? _libro;
  List<ArchivoArea> _areas = [];
  List<ArchivoBloque> _bloques = [];
  List<ArchivoMovimiento> _movimientos = [];
  List<ArchivoFolio> _folios = [];
  bool _loading = true;
  bool _working = false;
  Object? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final libro = await widget.service.getLibro(widget.libroId);
      final areas = await widget.service.getAreas(perPage: 100);
      final bloques = await widget.service.getBloques(perPage: 100);
      final movimientos = await widget.service.getMovimientos(widget.libroId);
      final folios = await widget.service.getFolios(widget.libroId);
      if (!mounted) return;
      setState(() {
        _libro = libro;
        _areas = areas.items;
        _bloques = bloques.items;
        _movimientos = movimientos.items;
        _folios = folios.items;
      });
    } catch (error) { if (mounted) setState(() => _error = error); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<String?> _blockQr() async {
    final result = await Navigator.push<ArchivoQrResult>(context,
      MaterialPageRoute(builder: (_) => const ArchivoEscanerQrScreen(requiredType: 'bloque')));
    return result?.uuid;
  }

  Future<void> _asignar() async {
    if (_bloques.isEmpty) { archivoToast(context, 'No hay bloques registrados.', error: true); return; }
    var blockId = _libro?.bloqueDestinoId ?? _bloques.first.id;
    var busy = false;
    final pos = TextEditingController();
    final selected = await showDialog<int?>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, local) => AlertDialog(
        title: const Text('Asignar destino'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(value: _bloques.any((b) => b.id == blockId) ? blockId : _bloques.first.id,
            isExpanded: true, decoration: archivoInput('Bloque'),
            items: _bloques.map((b) => DropdownMenuItem(value: b.id,
              child: Text('${b.anaquelCodigo} / ${b.codigo} · ${b.disponibles} libres', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: busy ? null : (v) { if (v != null) local(() => blockId = v); }),
          const SizedBox(height: 10),
          TextField(controller: pos, keyboardType: TextInputType.number, decoration: archivoInput('Posición (opcional)')),
        ]),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: busy ? null : () => Navigator.pop(context, blockId), child: const Text('Asignar')),
        ],
      ),
    ));
    final position = int.tryParse(pos.text);
    pos.dispose();
    if (selected == null) return;
    await _run(() => widget.service.asignarDestino(widget.libroId, selected, posicion: position));
  }

  Future<void> _retirar() async {
    if (_areas.isEmpty) { archivoToast(context, 'No hay áreas registradas.', error: true); return; }
    var areaId = _areas.first.id;
    final motivo = TextEditingController();
    final chosen = await showDialog<int?>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, local) => AlertDialog(
        title: const Text('Registrar retiro'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(value: areaId, isExpanded: true,
            decoration: archivoInput('Área de destino'),
            items: _areas.map((a) => DropdownMenuItem(value: a.id, child: Text(a.nombre))).toList(),
            onChanged: (v) { if (v != null) local(() => areaId = v); }),
          const SizedBox(height: 10),
          TextField(controller: motivo, decoration: archivoInput('Motivo del retiro'), maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            if (motivo.text.trim().isEmpty) { archivoToast(context, 'Escribe el motivo.', error: true); return; }
            Navigator.pop(context, areaId);
          }, child: const Text('Registrar retiro')),
        ],
      ),
    ));
    final text = motivo.text.trim();
    motivo.dispose();
    if (chosen == null) return;
    await _run(() => widget.service.retirar(widget.libroId, chosen, text));
  }

  Future<void> _ubicacionConQr(String tipo) async {
    String? qr = await _blockQr();
    if (qr == null) return;
    int? blockId;
    if (tipo == 'reubicar') {
      try {
        final b = await widget.service.bloquePorQr(qr);
        blockId = b.id;
      } catch (e) { if (mounted) archivoToast(context, e.toString(), error: true); return; }
    }
    if (!mounted) return;
    final position = TextEditingController();
    final selected = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(tipo == 'confirmar' ? 'Confirmar ubicación' : tipo == 'devolver' ? 'Devolver libro' : 'Reubicar libro'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Bloque identificado: $qr', maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        TextField(controller: position, keyboardType: TextInputType.number, decoration: archivoInput('Posición (opcional)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
      ],
    ));
    final pos = int.tryParse(position.text.trim());
    position.dispose();
    if (selected != true) return;
    final uuid = qr;
    final id = blockId;
    if (tipo == 'confirmar') {
      await _run(() => widget.service.confirmar(widget.libroId, uuid, posicion: pos));
    } else if (tipo == 'devolver') {
      await _run(() => widget.service.devolver(widget.libroId, uuid, posicion: pos));
    } else if (id != null) {
      await _run(() => widget.service.reubicar(widget.libroId, id, uuid, posicion: pos));
    }
  }

  Future<void> _run(Future<dynamic> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
      if (mounted) { archivoToast(context, 'Movimiento registrado'); await _load(); }
    } catch (error) { if (mounted) archivoToast(context, error.toString(), error: true); }
    finally { if (mounted) setState(() => _working = false); }
  }

  Future<void> _nuevoFolio() async {
    final folio = TextEditingController();
    final anio = TextEditingController(text: '${_libro?.anioInicio ?? DateTime.now().year}');
    final pagina = TextEditingController();
    final done = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Relacionar folio'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: folio, decoration: archivoInput('Folio')),
        const SizedBox(height: 10),
        TextField(controller: anio, keyboardType: TextInputType.number, decoration: archivoInput('Año')),
        const SizedBox(height: 10),
        TextField(controller: pagina, keyboardType: TextInputType.number, decoration: archivoInput('Página física (opcional)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Registrar')),
      ],
    ));
    final value = folio.text.trim();
    final year = int.tryParse(anio.text);
    final p = int.tryParse(pagina.text);
    folio.dispose(); anio.dispose(); pagina.dispose();
    if (done != true || value.isEmpty || year == null) return;
    await _run(() => widget.service.crearFolio(widget.libroId, {
      'folio': value, 'anio': year, 'numero_pagina': p,
    }));
  }

  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
    .then((_) { if (mounted) _load(); });

  @override
  Widget build(BuildContext context) => ArchivoLayout(
    title: _libro?.codigo ?? 'Libro',
    subtitle: 'Ficha de control documental',
    actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    child: _loading && _libro == null ? const ArchivoLoading()
      : _error != null && _libro == null ? ArchivoError(error: _error!, retry: _load)
      : _libro == null ? const ArchivoVacio('Libro no disponible.')
      : _body(_libro!),
  );

  Widget _body(ArchivoLibro l) => RefreshIndicator(onRefresh: _load, child: ListView(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
    children: [
      if (_working || _loading) const LinearProgressIndicator(),
      ArchivoSection(title: l.titulo.isEmpty ? l.codigo : l.titulo, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Código: ${l.codigo}'),
          Text('Libro: ${l.numero.isEmpty ? '—' : l.numero} · Año: ${l.anioInicio ?? '—'}–${l.anioFin ?? l.anioInicio ?? '—'}'),
          Text('Folios: ${l.folioInicial.isEmpty ? '—' : l.folioInicial} a ${l.folioFinal.isEmpty ? '—' : l.folioFinal}'),
          Text('Estado físico: ${archivoEtiqueta(l.estadoFisico)}'),
          Text('Digitalización: ${archivoEtiqueta(l.estadoDigitalizacion)}'),
          Text('Páginas: ${l.paginasDigitalizadas} / ${l.totalPaginas?.toString() ?? '?'}'),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => _open(ArchivoLibroFormScreen(service: widget.service, libro: l)),
            icon: const Icon(Icons.edit_outlined), label: const Text('Editar datos')),
        ],
      )),
      const SizedBox(height: 12),
      ArchivoSection(title: 'Ubicación física', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _row('Destino asignado', archivoText(l.ubicacionDestino['anaquel_codigo']).isEmpty ? 'Sin asignar' :
          '${l.ubicacionDestino['anaquel_codigo']} / ${l.ubicacionDestino['bloque_codigo']} · posición ${l.posicionDestino ?? 'por definir'}'),
        _row('Ubicación confirmada', l.ubicacionActual.isEmpty ?
          (l.areaActual.isNotEmpty ? archivoText(l.areaActual['nombre']) : 'No confirmada') :
          '${l.ubicacionActual['anaquel_codigo']} / ${l.ubicacionActual['bloque_codigo']} · posición ${l.posicionActual ?? '—'}'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: _working ? null : _asignar, icon: const Icon(Icons.pin_drop_outlined), label: const Text('Asignar destino')),
          OutlinedButton.icon(onPressed: _working ? null : () => _ubicacionConQr('confirmar'), icon: const Icon(Icons.qr_code_scanner), label: const Text('Confirmar QR')),
          OutlinedButton.icon(onPressed: _working ? null : _retirar, icon: const Icon(Icons.output), label: const Text('Retirar')),
          OutlinedButton.icon(onPressed: _working ? null : () => _ubicacionConQr('devolver'), icon: const Icon(Icons.input), label: const Text('Devolver')),
          OutlinedButton.icon(onPressed: _working ? null : () => _ubicacionConQr('reubicar'), icon: const Icon(Icons.swap_horiz), label: const Text('Reubicar')),
        ]),
      ])),
      const SizedBox(height: 12),
      ArchivoSection(title: 'Documentos digitalizados', child: Column(children: [
        Text('${l.documentos.length} documento(s) en vista previa. Los archivos se abren mediante una solicitud autenticada.'),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: () => _open(ArchivoDigitalizacionScreen(service: widget.service, libroId: l.id)),
          icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Ver y subir documentos')),
      ])),
      const SizedBox(height: 12),
      ArchivoSection(title: 'Folios relacionados', child: Column(children: [
        for (final f in _folios) ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${f.anio} · ${f.folio}'),
          subtitle: Text('Página ${f.pagina ?? '—'} · ${archivoEtiqueta(f.estado)}'),
        ),
        if (_folios.isEmpty) const Text('No hay folios indexados.'),
        const SizedBox(height: 6),
        OutlinedButton.icon(onPressed: _nuevoFolio, icon: const Icon(Icons.add), label: const Text('Agregar folio')),
      ])),
      const SizedBox(height: 12),
      ArchivoSection(title: 'Historial de movimientos', child: Column(children: [
        for (final m in _movimientos) ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history, color: archivoTeal),
          title: Text(archivoEtiqueta(m.tipo)),
          subtitle: Text('${m.fecha}\n${archivoText(m.usuario['name'])} ${m.motivo}'),
        ),
        if (_movimientos.isEmpty) const Text('Sin movimientos registrados.'),
      ])),
    ],
  ));

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: archivoMuted)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ]),
  );
}
