import 'package:flutter/material.dart';
import '../../../models/archivo_siniestros/archivo_models.dart';
import '../../../services/archivo_siniestros_service.dart';
import 'widgets/archivo_ui.dart';

class ArchivoAreasScreen extends StatefulWidget {
  final ArchivoSiniestrosService service;
  const ArchivoAreasScreen({super.key, required this.service});
  @override
  State<ArchivoAreasScreen> createState() => _ArchivoAreasScreenState();
}

class _ArchivoAreasScreenState extends State<ArchivoAreasScreen> {
  ArchivoPagina<ArchivoArea>? _data;
  Object? _error;
  bool _loading = true;
  int _page = 1;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load([int? page]) async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.service.getAreas(page: page ?? _page);
      if (mounted) setState(() { _data = result; _page = result.currentPage; });
    } catch (error) { if (mounted) setState(() => _error = error); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _edit([ArchivoArea? area]) async {
    final codigo = TextEditingController(text: area?.codigo ?? '');
    final nombre = TextEditingController(text: area?.nombre ?? '');
    final descripcion = TextEditingController(text: area?.descripcion ?? '');
    final ancho = TextEditingController(text: area?.ancho?.toString() ?? '');
    final alto = TextEditingController(text: area?.alto?.toString() ?? '');
    var tipo = area?.tipo ?? 'sala';
    var activo = area?.activo ?? true;
    final form = GlobalKey<FormState>();
    var saving = false;
    final changed = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, local) => AlertDialog(
        title: Text(area == null ? 'Nueva área' : 'Editar área'),
        content: SizedBox(width: 440, child: SingleChildScrollView(child: Form(key: form, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(controller: codigo, decoration: archivoInput('Código'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatorio' : null),
            const SizedBox(height: 10),
            TextFormField(controller: nombre, decoration: archivoInput('Nombre'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatorio' : null),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(value: tipo, decoration: archivoInput('Tipo'),
              items: const [
                DropdownMenuItem(value: 'sala', child: Text('Sala')),
                DropdownMenuItem(value: 'mesa', child: Text('Mesa')),
                DropdownMenuItem(value: 'otro', child: Text('Otro')),
              ], onChanged: (v) { if (v != null) local(() => tipo = v); }),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: ancho, keyboardType: TextInputType.number, decoration: archivoInput('Ancho del plano'))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: alto, keyboardType: TextInputType.number, decoration: archivoInput('Alto del plano'))),
            ]),
            const SizedBox(height: 10),
            TextFormField(controller: descripcion, maxLines: 2, decoration: archivoInput('Descripción')),
            SwitchListTile(title: const Text('Área activa'), value: activo, onChanged: (v) => local(() => activo = v)),
          ],
        )))),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: saving ? null : () async {
            if (!form.currentState!.validate()) return;
            local(() => saving = true);
            try {
              await widget.service.saveArea({
                'codigo': codigo.text.trim(), 'nombre': nombre.text.trim(), 'tipo': tipo,
                'descripcion': descripcion.text.trim(),
                'plano_ancho': double.tryParse(ancho.text.trim()),
                'plano_alto': double.tryParse(alto.text.trim()),
                'activo': activo,
              }, id: area?.id);
              if (context.mounted) Navigator.pop(context, true);
            } catch (e) {
              if (context.mounted) archivoToast(context, e.toString(), error: true);
              local(() => saving = false);
            }
          }, child: Text(saving ? 'Guardando…' : 'Guardar')),
        ],
      ),
    ));
    for (final controller in [codigo, nombre, descripcion, ancho, alto]) { controller.dispose(); }
    if (changed == true && mounted) { archivoToast(context, 'Área guardada'); _load(1); }
  }

  @override
  Widget build(BuildContext context) => ArchivoLayout(
    title: 'Áreas del archivo', subtitle: 'Salas, mesas y espacios de resguardo',
    actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Nueva área')),
    child: _loading && _data == null ? const ArchivoLoading() : _error != null && _data == null
        ? ArchivoError(error: _error!, retry: _load)
        : RefreshIndicator(onRefresh: () => _load(_page), child: ListView(
          padding: const EdgeInsets.all(14), children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Text(_error.toString(), style: const TextStyle(color: Colors.red)),
            if (_data == null || _data!.items.isEmpty) const ArchivoVacio('No hay áreas registradas.'),
            for (final area in _data?.items ?? <ArchivoArea>[]) Card(
              child: ListTile(
                leading: const Icon(Icons.meeting_room_outlined, color: archivoTeal),
                title: Text(area.nombre, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${area.codigo} · ${area.tipo} · ${area.anaquelesCount} anaqueles'),
                trailing: Icon(area.activo ? Icons.edit_outlined : Icons.do_not_disturb_alt_outlined),
                onTap: () => _edit(area),
              ),
            ),
            if (_data != null) ArchivoPaginacion(page: _page, lastPage: _data!.lastPage, onChanged: _load),
            const SizedBox(height: 70),
          ],
        )),
  );
}
