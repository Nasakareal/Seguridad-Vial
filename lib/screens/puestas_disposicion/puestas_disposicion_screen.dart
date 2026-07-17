import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../services/puestas_disposicion_service.dart';

class PuestasDisposicionScreen extends StatefulWidget {
  const PuestasDisposicionScreen({super.key});

  @override
  State<PuestasDisposicionScreen> createState() =>
      _PuestasDisposicionScreenState();
}

class _PuestasDisposicionScreenState extends State<PuestasDisposicionScreen> {
  final _service = PuestasDisposicionService();
  final _search = TextEditingController();

  bool _loading = true;
  bool _deleting = false;
  bool _editing = false;
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  String? _error;
  int _anio = DateTime.now().year;
  String? _tipoPuesta;
  String? _motivo;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  List<int> get _anios => List<int>.generate(
    6,
    (index) => DateTime.now().year - index,
    growable: false,
  );

  List<Map<String, dynamic>> get _filteredItems {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _items;

    return _items
        .where((item) {
          final values = <String>[
            _text(item['numero_puesta'], ''),
            _text(item['anio'], ''),
            _text(item['nombre_policia'], ''),
            _text(item['tipo_puesta'], ''),
            _text(item['motivo'], ''),
            _text(item['area'], ''),
            _nestedName(item, 'unidad'),
            _nestedName(item, 'delegacion'),
            _nestedName(item, 'destacamento'),
          ].join(' ').toLowerCase();
          return values.contains(query);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _search
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    final permissions = await Future.wait<bool>([
      AuthService.can('crear puestas a disposicion'),
      AuthService.can('editar puestas a disposicion'),
      AuthService.can('eliminar puestas a disposicion'),
    ]);
    if (!mounted) return;
    setState(() {
      _canCreate = permissions[0];
      _canEdit = permissions[1];
      _canDelete = permissions[2];
    });
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _service.index(
        anio: _anio,
        tipoPuesta: _tipoPuesta,
        motivo: _motivo,
      );
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'No se pudieron cargar las puestas.\n$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _text(dynamic value, [String fallback = '-']) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _nestedName(Map<String, dynamic> item, String key) {
    final nested = item[key];
    if (nested is Map) return _text(nested['nombre'], '');
    return '';
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse((value ?? '').toString());
    if (parsed == null) return _text(value);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year}';
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  int _hechoId(Map<String, dynamic> item) {
    final direct = _toInt(item['hecho_id']);
    if (direct > 0) return direct;
    final nested = item['hecho'];
    if (nested is Map) return _toInt(nested['id'] ?? nested['hecho_id']);
    return 0;
  }

  bool _hasPdf(Map<String, dynamic> item) =>
      _text(item['archivo_puesta'], '').isNotEmpty;

  int _fotoCount(Map<String, dynamic> item) {
    final fotos = item['fotos'];
    return fotos is List ? fotos.length : 0;
  }

  Future<void> _openShow(Map<String, dynamic> item) async {
    final id = _toInt(item['id']);
    if (id <= 0) return;

    await Navigator.of(context).pushNamed(
      AppRoutes.puestasDisposicionShow,
      arguments: {'puesta_disposicion_id': id},
    );
    if (mounted) await _load();
  }

  Future<void> _create() async {
    final created = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.puestasDisposicionCreate);
    if (created == true && mounted) await _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = _toInt(item['id']);
    if (id <= 0 || _deleting) return;

    final numero = _text(item['numero_puesta']);
    final anio = _text(item['anio']);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar puesta'),
        content: Text(
          'Se eliminará la puesta $numero/$anio y sus archivos asociados. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await _service.destroy(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Puesta eliminada.')));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final id = _toInt(item['id']);
    if (id <= 0 || _editing) return;

    var tipo = _text(item['tipo_puesta'], 'PERSONA').toUpperCase();
    if (!PuestaDisposicionCatalog.tipos.contains(tipo)) tipo = 'PERSONA';

    final motivoActual = _text(item['motivo'], '').toUpperCase();
    var motivoOpcion = PuestaDisposicionCatalog.esMotivoCatalogado(motivoActual)
        ? motivoActual
        : PuestaDisposicionCatalog.motivoOtro;
    final motivoOtro = TextEditingController(
      text: motivoOpcion == PuestaDisposicionCatalog.motivoOtro
          ? motivoActual
          : '',
    );
    final policia = TextEditingController(
      text: _text(item['nombre_policia'], ''),
    );
    final formKey = GlobalKey<FormState>();

    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Editar puesta ${_text(item['numero_puesta'])}/${_text(item['anio'])}',
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: tipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final option in PuestaDisposicionCatalog.tipos)
                          DropdownMenuItem(value: option, child: Text(option)),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => tipo = value ?? 'PERSONA'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: motivoOpcion,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Motivo',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final option in PuestaDisposicionCatalog.motivos)
                          DropdownMenuItem(
                            value: option,
                            child: Text(
                              option,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setDialogState(
                        () => motivoOpcion =
                            value ?? PuestaDisposicionCatalog.motivos.first,
                      ),
                    ),
                    if (motivoOpcion ==
                        PuestaDisposicionCatalog.motivoOtro) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: motivoOtro,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Especifique otro motivo',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Campo requerido'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: policia,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del policía',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Campo requerido'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(context, <String, String>{
                  'tipo': tipo,
                  'motivo': motivoOpcion == PuestaDisposicionCatalog.motivoOtro
                      ? motivoOtro.text.trim()
                      : motivoOpcion,
                  'policia': policia.text.trim(),
                });
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    motivoOtro.dispose();
    policia.dispose();
    if (values == null || !mounted) return;

    setState(() => _editing = true);
    try {
      await _service.updateBasic(
        id: id,
        tipoPuesta: values['tipo']!,
        motivo: values['motivo']!,
        nombrePolicia: values['policia']!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Puesta actualizada.')));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $error')));
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Puestas a disposición'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Nueva puesta'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _filters()),
            if (_loading && _items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _message(_error!, isError: true),
              )
            else if (items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Sin puestas para estos filtros.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _itemCard(items[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: 'Buscar en resultados',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        onPressed: _search.clear,
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _anio,
              decoration: const InputDecoration(
                labelText: 'Año',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final anio in _anios)
                  DropdownMenuItem(value: anio, child: Text('$anio')),
              ],
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _anio = value);
                      _load();
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _tipoPuesta,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final tipo in PuestaDisposicionCatalog.tipos)
                  DropdownMenuItem(value: tipo, child: Text(tipo)),
              ],
              onChanged: _loading
                  ? null
                  : (value) {
                      setState(() => _tipoPuesta = value);
                      _load();
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _motivo,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final motivo in PuestaDisposicionCatalog.motivos.where(
                  (value) => value != PuestaDisposicionCatalog.motivoOtro,
                ))
                  DropdownMenuItem(
                    value: motivo,
                    child: Text(motivo, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _loading
                  ? null
                  : (value) {
                      setState(() => _motivo = value);
                      _load();
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(String text, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: isError ? Colors.red.shade700 : null),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final numero = _text(item['numero_puesta']);
    final anio = _text(item['anio']);
    final hechoId = _hechoId(item);
    final unidad = _nestedName(item, 'unidad').isEmpty
        ? _text(item['area'])
        : _nestedName(item, 'unidad');
    final delegacion = _nestedName(item, 'delegacion');
    final destacamento = _nestedName(item, 'destacamento');
    final fotoCount = _fotoCount(item);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openShow(item),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Puesta $numero/$anio',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    _date(item['fecha_puesta']),
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_canEdit || _canDelete)
                    PopupMenuButton<String>(
                      tooltip: 'Acciones',
                      enabled: !_deleting && !_editing,
                      onSelected: (value) {
                        if (value == 'edit') _edit(item);
                        if (value == 'delete') _delete(item);
                      },
                      itemBuilder: (_) => [
                        if (_canEdit)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined),
                                SizedBox(width: 8),
                                Text('Editar datos principales'),
                              ],
                            ),
                          ),
                        if (_canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Eliminar'),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_text(item['tipo_puesta'])} · ${_text(item['motivo'])}',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(unidad, style: TextStyle(color: Colors.grey.shade700)),
              if (delegacion.isNotEmpty || destacamento.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (delegacion.isNotEmpty) delegacion,
                    if (destacamento.isNotEmpty) destacamento,
                  ].join(' · '),
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              if (hechoId > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'Hecho vinculado: #$hechoId',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                _text(item['nombre_policia'], 'Sin policía'),
                style: TextStyle(color: Colors.grey.shade700),
              ),
              if (_hasPdf(item) || fotoCount > 0) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (_hasPdf(item))
                      const Chip(
                        avatar: Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: Text('PDF'),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (fotoCount > 0)
                      Chip(
                        avatar: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: Text(
                          '$fotoCount foto${fotoCount == 1 ? '' : 's'}',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
