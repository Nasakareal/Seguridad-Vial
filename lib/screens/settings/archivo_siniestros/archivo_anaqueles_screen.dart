import 'package:flutter/material.dart';
import '../../../models/archivo_siniestros/archivo_models.dart';
import '../../../services/archivo_siniestros_service.dart';
import 'widgets/archivo_ui.dart';

class ArchivoAnaquelesScreen extends StatefulWidget {
  final ArchivoSiniestrosService service;
  const ArchivoAnaquelesScreen({super.key, required this.service});
  @override
  State<ArchivoAnaquelesScreen> createState() => _ArchivoAnaquelesScreenState();
}

class _ArchivoAnaquelesScreenState extends State<ArchivoAnaquelesScreen> {
  ArchivoPagina<ArchivoAnaquel>? _data;
  List<ArchivoArea> _areas = [];
  Object? _error;
  bool _loading = true;
  int _page = 1;
  int? _areaFilter;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load([int? page]) async {
    setState(() { _loading = true; _error = null; });
    try {
      final areas = await widget.service.getAreas(perPage: 100);
      final result = await widget.service.getAnaqueles(page: page ?? _page, areaId: _areaFilter);
      if (mounted) setState(() {
        _areas = areas.items;
        _data = result;
        _page = result.currentPage;
      });
    } catch (error) { if (mounted) setState(() => _error = error); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _edit([ArchivoAnaquel? item]) async {
    if (_areas.isEmpty) { archivoToast(context, 'Primero registra un área.', error: true); return; }
    final codigo = TextEditingController(text: item?.codigo ?? '');
    final nombre = TextEditingController(text: item?.nombre ?? '');
    final filas = TextEditingController(text: '${item?.filas ?? 4}');
    final columnas = TextEditingController(text: '${item?.columnas ?? 3}');
    final x = TextEditingController(text: item?.x?.toString() ?? '');
    final y = TextEditingController(text: item?.y?.toString() ?? '');
    final ancho = TextEditingController(text: item?.ancho?.toString() ?? '');
    final alto = TextEditingController(text: item?.alto?.toString() ?? '');
    final rotacion = TextEditingController(text: '${item?.rotacion ?? 0}');
    var areaId = item?.areaId ?? _areas.first.id;
    var activo = item?.activo ?? true;
    var saving = false;
    final form = GlobalKey<FormState>();
    final changed = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, local) => AlertDialog(
        title: Text(item == null ? 'Nuevo anaquel' : 'Editar anaquel'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(value: areaId, decoration: archivoInput('Área'),
              isExpanded: true,
              items: _areas.map((a) => DropdownMenuItem(value: a.id, child: Text(a.nombre, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) { if (v != null) local(() => areaId = v); }),
            const SizedBox(height: 10),
            TextFormField(controller: codigo, decoration: archivoInput('Código'),
              validator: (v) => (v ?? '').isEmpty ? 'Obligatorio' : null),
            const SizedBox(height: 10),
            TextFormField(controller: nombre, decoration: archivoInput('Nombre (opcional)')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: filas, keyboardType: TextInputType.number,
                decoration: archivoInput('Filas'), validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Número inválido' : null)),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: columnas, keyboardType: TextInputType.number,
                decoration: archivoInput('Columnas'), validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Número inválido' : null)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: x, keyboardType: TextInputType.number, decoration: archivoInput('Posición X'))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: y, keyboardType: TextInputType.number, decoration: archivoInput('Posición Y'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: ancho, keyboardType: TextInputType.number, decoration: archivoInput('Ancho'))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: alto, keyboardType: TextInputType.number, decoration: archivoInput('Alto'))),
            ]),
            const SizedBox(height: 10),
            TextFormField(controller: rotacion, keyboardType: TextInputType.number, decoration: archivoInput('Rotación (0 a 359°)'),
              validator: (v) => (int.tryParse(v ?? '') ?? -1) < 0 || (int.tryParse(v ?? '') ?? 360) > 359 ? 'Valor inválido' : null),
            SwitchListTile(title: const Text('Anaquel activo'), value: activo, onChanged: (v) => local(() => activo = v)),
          ]),
        ))),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: saving ? null : () async {
            if (!form.currentState!.validate()) return;
            local(() => saving = true);
            try {
              await widget.service.saveAnaquel({
                'area_id': areaId,
                'codigo': codigo.text.trim(),
                'nombre': nombre.text.trim().isEmpty ? null : nombre.text.trim(),
                'total_filas': int.parse(filas.text),
                'total_columnas': int.parse(columnas.text),
                'plano_x': double.tryParse(x.text),
                'plano_y': double.tryParse(y.text),
                'plano_ancho': double.tryParse(ancho.text),
                'plano_alto': double.tryParse(alto.text),
                'rotacion': int.parse(rotacion.text),
                'activo': activo,
              }, id: item?.id);
              if (context.mounted) Navigator.pop(context, true);
            } catch (error) {
              if (context.mounted) archivoToast(context, error.toString(), error: true);
              local(() => saving = false);
            }
          }, child: Text(saving ? 'Guardando…' : 'Guardar')),
        ],
      ),
    ));
    for (final c in [codigo, nombre, filas, columnas, x, y, ancho, alto, rotacion]) { c.dispose(); }
    if (changed == true && mounted) _load(1);
  }

  @override
  Widget build(BuildContext context) => ArchivoLayout(
    title: 'Anaqueles', subtitle: 'Organiza la cuadrícula de cada anaquel',
    actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Anaquel')),
    child: _loading && _data == null ? const ArchivoLoading()
        : _error != null && _data == null ? ArchivoError(error: _error!, retry: _load)
        : RefreshIndicator(onRefresh: () => _load(_page), child: ListView(
          padding: const EdgeInsets.all(14), children: [
            DropdownButtonFormField<int?>(value: _areaFilter, isExpanded: true,
              decoration: archivoInput('Filtrar por área'),
              items: [const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
                ..._areas.map((a) => DropdownMenuItem<int?>(value: a.id, child: Text(a.nombre, overflow: TextOverflow.ellipsis)))],
              onChanged: (v) { setState(() => _areaFilter = v); _load(1); }),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Text(_error.toString(), style: const TextStyle(color: Colors.red)),
            if (_data?.items.isEmpty ?? true) const ArchivoVacio('No hay anaqueles para esta área.'),
            for (final a in _data?.items ?? <ArchivoAnaquel>[]) Card(
              child: ListTile(
                leading: const Icon(Icons.warehouse_outlined, color: archivoTeal),
                title: Text('${a.codigo} · ${a.nombre}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${a.areaNombre} · ${a.filas} filas × ${a.columnas} columnas · ${a.bloquesCount} bloques'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _edit(a),
              ),
            ),
            if (_data != null) ArchivoPaginacion(page: _page, lastPage: _data!.lastPage, onChanged: _load),
            const SizedBox(height: 70),
          ],
        )),
  );
}
