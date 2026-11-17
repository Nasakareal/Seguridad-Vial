import 'package:flutter/material.dart';
import '../../../models/archivo_siniestros/archivo_models.dart';
import '../../../services/archivo_siniestros_service.dart';
import 'widgets/archivo_ui.dart';

class ArchivoLibroFormScreen extends StatefulWidget {
  final ArchivoSiniestrosService service;
  final ArchivoLibro? libro;
  const ArchivoLibroFormScreen({super.key, required this.service, this.libro});
  @override
  State<ArchivoLibroFormScreen> createState() => _ArchivoLibroFormScreenState();
}

class _ArchivoLibroFormScreenState extends State<ArchivoLibroFormScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  List<ArchivoBloque> _bloques = [];
  int? _bloqueId;
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  TextEditingController _c(String key) => _controllers[key]!;

  @override
  void initState() {
    super.initState();
    final libro = widget.libro;
    final values = <String, String>{
      'codigo': libro?.codigo ?? '',
      'titulo': libro?.titulo ?? '',
      'numero_libro': libro?.numero ?? '',
      'anio_inicio': libro?.anioInicio?.toString() ?? '',
      'anio_fin': libro?.anioFin?.toString() ?? '',
      'folio_inicial': libro?.folioInicial ?? '',
      'folio_final': libro?.folioFinal ?? '',
      'fecha_inicio': (libro?.fechaInicio ?? '').split('T').first,
      'fecha_fin': (libro?.fechaFin ?? '').split('T').first,
      'total_paginas': libro?.totalPaginas?.toString() ?? '',
      'observaciones': libro?.observaciones ?? '',
      'posicion_destino': libro?.posicionDestino?.toString() ?? '',
    };
    for (final entry in values.entries) { _controllers[entry.key] = TextEditingController(text: entry.value); }
    _bloqueId = libro?.bloqueDestinoId;
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await widget.service.getBloques(perPage: 100);
      if (result.lastPage > 1) {
        throw const ArchivoApiException('Hay más de 100 bloques. Filtra o reduce la lista antes de asignar.');
      }
      if (mounted) setState(() => _bloques = result.items.where((b) => b.activo).toList());
    } catch (error) { if (mounted) setState(() => _error = error); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'codigo': _c('codigo').text.trim(),
        'titulo': _nullable('titulo'),
        'numero_libro': _nullable('numero_libro'),
        'anio_inicio': _integer('anio_inicio'),
        'anio_fin': _integer('anio_fin'),
        'folio_inicial': _nullable('folio_inicial'),
        'folio_final': _nullable('folio_final'),
        'fecha_inicio': _nullable('fecha_inicio'),
        'fecha_fin': _nullable('fecha_fin'),
        'total_paginas': _integer('total_paginas'),
        'observaciones': _nullable('observaciones'),
        if (widget.libro == null) 'bloque_destino_id': _bloqueId,
        if (widget.libro == null) 'posicion_destino': _integer('posicion_destino'),
      };
      await widget.service.saveLibro(data, id: widget.libro?.id);
      if (mounted) { archivoToast(context, 'Libro guardado correctamente'); Navigator.pop(context, true); }
    } catch (error) { if (mounted) archivoToast(context, error.toString(), error: true); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  String? _nullable(String key) => _c(key).text.trim().isEmpty ? null : _c(key).text.trim();
  int? _integer(String key) => int.tryParse(_c(key).text.trim());

  Widget _field(String key, String label, {bool required = false, bool number = false, int maxLines = 1}) =>
      TextFormField(
        controller: _c(key),
        keyboardType: number ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: archivoInput(label),
        validator: (value) {
          if (required && (value ?? '').trim().isEmpty) return 'Obligatorio';
          if (number && (value ?? '').trim().isNotEmpty && int.tryParse(value!.trim()) == null) return 'Número inválido';
          return null;
        },
      );

  @override
  Widget build(BuildContext context) => ArchivoLayout(
    title: widget.libro == null ? 'Registrar libro' : 'Editar libro',
    subtitle: 'Inventario y destino de resguardo',
    child: _loading ? const ArchivoLoading() : _error != null ? ArchivoError(error: _error!, retry: _load)
      : Form(key: _form, child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 36), children: [
        ArchivoSection(title: 'Identificación', child: Column(children: [
          _field('codigo', 'Código único del libro', required: true),
          const SizedBox(height: 10),
          _field('titulo', 'Título'),
          const SizedBox(height: 10),
          _field('numero_libro', 'Número de libro'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field('anio_inicio', 'Año inicial', number: true)),
            const SizedBox(width: 9),
            Expanded(child: _field('anio_fin', 'Año final', number: true)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field('folio_inicial', 'Folio inicial')),
            const SizedBox(width: 9),
            Expanded(child: _field('folio_final', 'Folio final')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field('fecha_inicio', 'Fecha inicial (AAAA-MM-DD)')),
            const SizedBox(width: 9),
            Expanded(child: _field('fecha_fin', 'Fecha final (AAAA-MM-DD)')),
          ]),
          const SizedBox(height: 10),
          _field('total_paginas', 'Total de páginas', number: true),
          const SizedBox(height: 10),
          _field('observaciones', 'Observaciones', maxLines: 3),
        ])),
        const SizedBox(height: 12),
        if (widget.libro == null) ArchivoSection(title: 'Ubicación de destino', child: Column(children: [
          DropdownButtonFormField<int?>(value: _bloques.any((b) => b.id == _bloqueId) ? _bloqueId : null,
            isExpanded: true,
            decoration: archivoInput('Bloque (opcional)'),
            items: [const DropdownMenuItem<int?>(value: null, child: Text('Asignar después')),
              ..._bloques.map((b) => DropdownMenuItem<int?>(value: b.id,
                child: Text('${b.anaquelCodigo} / ${b.codigo} · ${b.disponibles} libres', overflow: TextOverflow.ellipsis)))],
            onChanged: (v) => setState(() => _bloqueId = v),
          ),
          const SizedBox(height: 10),
          _field('posicion_destino', 'Posición en la pila (opcional)', number: true),
          const Text('La ubicación queda reservada; deberá confirmarse mediante el QR del bloque.', style: TextStyle(color: archivoMuted, fontSize: 12)),
        ])) else const Card(child: Padding(padding: EdgeInsets.all(14),
          child: Text('La ubicación se modifica desde la ficha del libro para dejar historial de movimientos.'))),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _saving ? null : _submit,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Guardando…' : 'Guardar libro')),
      ])),
  );
}
