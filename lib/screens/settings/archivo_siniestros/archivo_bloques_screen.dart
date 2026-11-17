import 'package:flutter/material.dart';
import '../../../models/archivo_siniestros/archivo_models.dart';
import '../../../services/archivo_siniestros_service.dart';
import 'widgets/archivo_ui.dart';

class ArchivoBloquesScreen extends StatefulWidget {
  final ArchivoSiniestrosService service;
  final int? initialAnaquelId;
  const ArchivoBloquesScreen({super.key, required this.service, this.initialAnaquelId});
  @override
  State<ArchivoBloquesScreen> createState() => _ArchivoBloquesScreenState();
}

class _ArchivoBloquesScreenState extends State<ArchivoBloquesScreen> {
  ArchivoPagina<ArchivoBloque>? _data;
  List<ArchivoAnaquel> _anaqueles = [];
  Object? _error;
  bool _loading = true;
  int _page = 1;
  int? _anaquelId;

  @override
  void initState() { super.initState(); _anaquelId = widget.initialAnaquelId; _load(); }

  Future<void> _load([int? page]) async {
    setState(() { _loading = true; _error = null; });
    try {
      final anaqueles = await widget.service.getAnaqueles(perPage: 100);
      final result = await widget.service.getBloques(page: page ?? _page, anaquelId: _anaquelId);
      if (mounted) setState(() { _anaqueles = anaqueles.items; _data = result; _page = result.currentPage; });
    } catch (error) { if (mounted) setState(() => _error = error); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  String _codigoColumna(int number) {
    var n = number;
    var result = '';
    while (n > 0) {
      n--;
      result = '${String.fromCharCode(65 + n % 26)}$result';
      n ~/= 26;
    }
    return result;
  }

  Future<void> _generar() async {
    if (_anaqueles.isEmpty) return;
    var id = _anaquelId ?? _anaqueles.first.id;
    var capacidad = 8;
    var busy = false;
    final created = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, local) => AlertDialog(
        title: const Text('Generar bloques faltantes'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(value: id, isExpanded: true, decoration: archivoInput('Anaquel'),
            items: _anaqueles.map((a) => DropdownMenuItem(value: a.id, child: Text(a.codigo))).toList(),
            onChanged: busy ? null : (v) { if (v != null) local(() => id = v); }),
          const SizedBox(height: 12),
          TextFormField(initialValue: '$capacidad', keyboardType: TextInputType.number, decoration: archivoInput('Capacidad por bloque'),
            onChanged: (v) => capacidad = int.tryParse(v) ?? 0),
          const SizedBox(height: 10),
          const Text('Se crearán solamente las celdas que todavía no existen, sin borrar las actuales.'),
        ]),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: busy ? null : () async {
            if (capacidad < 1 || capacidad > 65535) { archivoToast(context, 'Capacidad inválida', error: true); return; }
            local(() => busy = true);
            try {
              final anaquel = _anaqueles.firstWhere((a) => a.id == id);
              final page = await widget.service.getBloques(anaquelId: id, perPage: 100);
              if (page.lastPage > 1) throw const ArchivoApiException('Hay más de 100 bloques. Genera los faltantes desde la web.');
              final ocupados = page.items.map((b) => '${b.fila}:${b.columna}').toSet();
              var creados = 0;
              for (var fila = 1; fila <= anaquel.filas; fila++) {
                for (var columna = 1; columna <= anaquel.columnas; columna++) {
                  if (ocupados.contains('$fila:$columna')) continue;
                  await widget.service.saveBloque({
                    'anaquel_id': id,
                    'codigo': '${_codigoColumna(columna)}$fila',
                    'fila': fila, 'columna': columna,
                    'capacidad_libros': capacidad,
                    'orden_apilado': 'arriba_abajo',
                    'activo': true,
                    'observaciones': null,
                  });
                  creados++;
                }
              }
              if (context.mounted) {
                archivoToast(context, 'Se crearon $creados bloques.');
                Navigator.pop(context, true);
              }
            } catch (error) {
              if (context.mounted) archivoToast(context, error.toString(), error: true);
              local(() => busy = false);
            }
          }, child: Text(busy ? 'Generando…' : 'Crear bloques')),
        ],
      ),
    ));
    if (created == true && mounted) _load(1);
  }

  Future<void> _edit([ArchivoBloque? item]) async {
    if (_anaqueles.isEmpty) { archivoToast(context, 'Primero registra un anaquel.', error: true); return; }
    var id = item?.anaquelId ?? _anaquelId ?? _anaqueles.first.id;
    final codigo = TextEditingController(text: item?.codigo ?? '');
    final fila = TextEditingController(text: '${item?.fila ?? 1}');
    final columna = TextEditingController(text: '${item?.columna ?? 1}');
    final capacidad = TextEditingController(text: '${item?.capacidad ?? 8}');
    final observaciones = TextEditingController(text: item?.observaciones ?? '');
    var orden = item?.orden.isNotEmpty == true ? item!.orden : 'arriba_abajo';
    var activo = item?.activo ?? true;
    var busy = false;
    final form = GlobalKey<FormState>();
    final changed = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, local) => AlertDialog(
        title: Text(item == null ? 'Nuevo bloque' : 'Editar bloque ${item.codigo}'),
        content: SizedBox(width: 430, child: SingleChildScrollView(child: Form(key: form, child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(value: id, isExpanded: true, decoration: archivoInput('Anaquel'),
              items: _anaqueles.map((a) => DropdownMenuItem(value: a.id, child: Text(a.codigo))).toList(),
              onChanged: (v) { if (v != null) local(() => id = v); }),
            const SizedBox(height: 10),
            TextFormField(controller: codigo, decoration: archivoInput('Código'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatorio' : null),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: fila, keyboardType: TextInputType.number, decoration: archivoInput('Fila'),
                validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Inválido' : null)),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: columna, keyboardType: TextInputType.number, decoration: archivoInput('Columna'),
                validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Inválido' : null)),
            ]),
            const SizedBox(height: 10),
            TextFormField(controller: capacidad, keyboardType: TextInputType.number, decoration: archivoInput('Capacidad de libros'),
              validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Inválido' : null),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(value: orden, decoration: archivoInput('Orden de la pila'),
              items: const [
                DropdownMenuItem(value: 'arriba_abajo', child: Text('De arriba hacia abajo')),
                DropdownMenuItem(value: 'abajo_arriba', child: Text('De abajo hacia arriba')),
              ], onChanged: (v) { if (v != null) local(() => orden = v); }),
            const SizedBox(height: 10),
            TextFormField(controller: observaciones, maxLines: 2, decoration: archivoInput('Observaciones')),
            SwitchListTile(title: const Text('Bloque activo'), value: activo, onChanged: (v) => local(() => activo = v)),
          ],
        )))),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: busy ? null : () async {
            if (!form.currentState!.validate()) return;
            local(() => busy = true);
            try {
              await widget.service.saveBloque({
                'anaquel_id': id,
                'codigo': codigo.text.trim(), 'fila': int.parse(fila.text),
                'columna': int.parse(columna.text), 'capacidad_libros': int.parse(capacidad.text),
                'orden_apilado': orden, 'activo': activo,
                'observaciones': observaciones.text.trim(),
              }, id: item?.id);
              if (context.mounted) Navigator.pop(context, true);
            } catch (error) {
              if (context.mounted) archivoToast(context, error.toString(), error: true);
              local(() => busy = false);
            }
          }, child: Text(busy ? 'Guardando…' : 'Guardar')),
        ],
      ),
    ));
    for (final c in [codigo, fila, columna, capacidad, observaciones]) { c.dispose(); }
    if (changed == true && mounted) _load(1);
  }

  @override
  Widget build(BuildContext context) => ArchivoLayout(
    title: 'Bloques', subtitle: 'Capacidad de cada espacio del anaquel',
    actions: [IconButton(onPressed: _generar, icon: const Icon(Icons.auto_awesome), tooltip: 'Generar bloques faltantes'),
      IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Bloque')),
    child: _loading && _data == null ? const ArchivoLoading()
        : _error != null && _data == null ? ArchivoError(error: _error!, retry: _load)
        : RefreshIndicator(onRefresh: () => _load(_page), child: ListView(
          padding: const EdgeInsets.all(14), children: [
            DropdownButtonFormField<int?>(value: _anaquelId, isExpanded: true,
              decoration: archivoInput('Anaquel'),
              items: [const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
                ..._anaqueles.map((a) => DropdownMenuItem<int?>(value: a.id, child: Text(a.codigo)))],
              onChanged: (v) { setState(() => _anaquelId = v); _load(1); }),
            const SizedBox(height: 10),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Text(_error.toString(), style: const TextStyle(color: Colors.red)),
            if (_data?.items.isEmpty ?? true) const ArchivoVacio('No hay bloques. Puedes generarlos automáticamente.'),
            for (final b in _data?.items ?? <ArchivoBloque>[]) Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: archivoTeal.withValues(alpha: .12),
                  child: Text(b.codigo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
                title: Text('${b.anaquelCodigo} · ${b.codigo}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Fila ${b.fila}, columna ${b.columna}  ·  ${b.ocupados} ocupados  ·  ${b.reservados} reservados  ·  ${b.disponibles} libres'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _edit(b),
              ),
            ),
            if (_data != null) ArchivoPaginacion(page: _page, lastPage: _data!.lastPage, onChanged: _load),
            const SizedBox(height: 75),
          ],
        )),
  );
}
