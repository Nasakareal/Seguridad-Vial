import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/modulo_examen_diario.dart';
import '../../services/modulo_examenes_diarios_service.dart';

class ModuloExamenesDiariosScreen extends StatefulWidget {
  const ModuloExamenesDiariosScreen({super.key});

  @override
  State<ModuloExamenesDiariosScreen> createState() =>
      _ModuloExamenesDiariosScreenState();
}

class _ModuloExamenesDiariosScreenState
    extends State<ModuloExamenesDiariosScreen> {
  final _buscarCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<ModuloExamenDiario> _items = [];
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_maybeLoadMore);
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _page = 1;
        _lastPage = 1;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final page = await ModuloExamenesDiariosService.index(
        page: reset ? 1 : _page + 1,
        buscar: _buscarCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
        _page = page.currentPage;
        _lastPage = page.lastPage;
        _total = page.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = ModuloExamenesDiariosService.cleanExceptionMessage(e);
      });
    }
  }

  void _maybeLoadMore() {
    if (_loading || _loadingMore || _page >= _lastPage) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 320) {
      unawaited(_load(reset: false));
    }
  }

  Future<void> _openForm([ModuloExamenDiario? registro]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ModuloExamenDiarioDialog(registro: registro),
    );

    if (saved == true) {
      await _load(reset: true);
    }
  }

  Future<void> _delete(ModuloExamenDiario registro) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text(
          'Se eliminara ${registro.moduloNombre} del ${registro.fechaCorta}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ModuloExamenesDiariosService.delete(registro.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registro eliminado.')));
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ModuloExamenesDiariosService.cleanExceptionMessage(e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Examenes diarios'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(_load(reset: true)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Registro'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _buscarCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Buscar modulo, folios o informante',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _load(reset: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Buscar',
                        onPressed: () => unawaited(_load(reset: true)),
                        icon: const Icon(Icons.search),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$_total registros',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _ErrorState(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: _items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 120),
                                Center(child: Text('No hay registros.')),
                              ],
                            )
                          : ListView.separated(
                              controller: _scrollCtrl,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                96,
                              ),
                              itemBuilder: (context, index) {
                                if (index >= _items.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final item = _items[index];
                                return _RegistroCard(
                                  registro: item,
                                  onEdit: () => _openForm(item),
                                  onDelete: () => _delete(item),
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemCount: _items.length + (_loadingMore ? 1 : 0),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistroCard extends StatelessWidget {
  final ModuloExamenDiario registro;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RegistroCard({
    required this.registro,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      registro.moduloNombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    registro.fechaCorta,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(label: 'Total', value: registro.total),
                  _Pill(label: 'Aprobados', value: registro.aprobados),
                  _Pill(label: 'Reprobados', value: registro.reprobados),
                  _Pill(label: 'Hombres', value: registro.hombres),
                  _Pill(label: 'Mujeres', value: registro.mujeres),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                [
                  if ((registro.folios ?? '').trim().isNotEmpty)
                    'Folios: ${registro.folios}',
                  if ((registro.informadoPor ?? '').trim().isNotEmpty)
                    'Informo: ${registro.informadoPor}',
                ].join('\n'),
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Eliminar',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final int value;

  const _Pill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ModuloExamenDiarioDialog extends StatefulWidget {
  final ModuloExamenDiario? registro;

  const _ModuloExamenDiarioDialog({this.registro});

  @override
  State<_ModuloExamenDiarioDialog> createState() =>
      _ModuloExamenDiarioDialogState();
}

class _ModuloExamenDiarioDialogState extends State<_ModuloExamenDiarioDialog> {
  final _fechaCtrl = TextEditingController();
  final _moduloCtrl = TextEditingController();
  final _servicioPublicoCtrl = TextEditingController(text: '0');
  final _automovilistaCtrl = TextEditingController(text: '0');
  final _choferCtrl = TextEditingController(text: '0');
  final _motociclistaCtrl = TextEditingController(text: '0');
  final _permisoCtrl = TextEditingController(text: '0');
  final _hombresCtrl = TextEditingController(text: '0');
  final _mujeresCtrl = TextEditingController(text: '0');
  final _aprobadosCtrl = TextEditingController(text: '0');
  final _reprobadosCtrl = TextEditingController(text: '0');
  final _foliosCtrl = TextEditingController();
  final _informadoPorCtrl = TextEditingController();

  bool _saving = false;
  String? _error;

  List<TextEditingController> get _tipoCtrls => [
    _servicioPublicoCtrl,
    _automovilistaCtrl,
    _choferCtrl,
    _motociclistaCtrl,
    _permisoCtrl,
  ];

  int get _total => _tipoCtrls.fold(0, (sum, ctrl) => sum + _intValue(ctrl));

  @override
  void initState() {
    super.initState();
    final registro = widget.registro;
    if (registro == null) {
      final today = DateTime.now();
      _fechaCtrl.text = _formatDate(today);
    } else {
      _fechaCtrl.text = registro.fecha;
      _moduloCtrl.text = registro.moduloNombre;
      _servicioPublicoCtrl.text = registro.servicioPublico.toString();
      _automovilistaCtrl.text = registro.automovilista.toString();
      _choferCtrl.text = registro.chofer.toString();
      _motociclistaCtrl.text = registro.motociclista.toString();
      _permisoCtrl.text = registro.permiso.toString();
      _hombresCtrl.text = registro.hombres.toString();
      _mujeresCtrl.text = registro.mujeres.toString();
      _aprobadosCtrl.text = registro.aprobados.toString();
      _reprobadosCtrl.text = registro.reprobados.toString();
      _foliosCtrl.text = registro.folios ?? '';
      _informadoPorCtrl.text = registro.informadoPor ?? '';
    }

    for (final ctrl in _tipoCtrls) {
      ctrl.addListener(_refreshTotal);
    }
  }

  @override
  void dispose() {
    for (final ctrl in _tipoCtrls) {
      ctrl.removeListener(_refreshTotal);
    }
    _fechaCtrl.dispose();
    _moduloCtrl.dispose();
    _servicioPublicoCtrl.dispose();
    _automovilistaCtrl.dispose();
    _choferCtrl.dispose();
    _motociclistaCtrl.dispose();
    _permisoCtrl.dispose();
    _hombresCtrl.dispose();
    _mujeresCtrl.dispose();
    _aprobadosCtrl.dispose();
    _reprobadosCtrl.dispose();
    _foliosCtrl.dispose();
    _informadoPorCtrl.dispose();
    super.dispose();
  }

  void _refreshTotal() {
    setState(() {});
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_fechaCtrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() => _fechaCtrl.text = _formatDate(picked));
  }

  Future<void> _save() async {
    final fecha = _fechaCtrl.text.trim();
    final modulo = _moduloCtrl.text.trim();

    if (fecha.isEmpty || modulo.isEmpty) {
      setState(() => _error = 'Captura fecha y modulo.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ModuloExamenesDiariosService.save(
        id: widget.registro?.id,
        data: <String, dynamic>{
          'fecha': fecha,
          'modulo_nombre': modulo,
          'servicio_publico': _intValue(_servicioPublicoCtrl),
          'automovilista': _intValue(_automovilistaCtrl),
          'chofer': _intValue(_choferCtrl),
          'motociclista': _intValue(_motociclistaCtrl),
          'permiso': _intValue(_permisoCtrl),
          'hombres': _intValue(_hombresCtrl),
          'mujeres': _intValue(_mujeresCtrl),
          'aprobados': _intValue(_aprobadosCtrl),
          'reprobados': _intValue(_reprobadosCtrl),
          'folios': _foliosCtrl.text.trim(),
          'informado_por': _informadoPorCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = ModuloExamenesDiariosService.cleanExceptionMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.registro == null ? 'Nuevo registro' : 'Editar registro',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fechaCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        prefixIcon: Icon(Icons.event),
                        border: OutlineInputBorder(),
                      ),
                      onTap: _saving ? null : _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _moduloCtrl,
                      enabled: !_saving,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Modulo',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionLabel(label: 'Tipos de examen', total: _total),
              _NumberGrid(
                children: [
                  _NumberField(
                    label: 'Servicio publico',
                    ctrl: _servicioPublicoCtrl,
                  ),
                  _NumberField(
                    label: 'Automovilista',
                    ctrl: _automovilistaCtrl,
                  ),
                  _NumberField(label: 'Chofer', ctrl: _choferCtrl),
                  _NumberField(label: 'Motociclista', ctrl: _motociclistaCtrl),
                  _NumberField(label: 'Permiso', ctrl: _permisoCtrl),
                ],
              ),
              const SizedBox(height: 12),
              const _SectionLabel(label: 'Resultados'),
              _NumberGrid(
                children: [
                  _NumberField(label: 'Hombres', ctrl: _hombresCtrl),
                  _NumberField(label: 'Mujeres', ctrl: _mujeresCtrl),
                  _NumberField(label: 'Aprobados', ctrl: _aprobadosCtrl),
                  _NumberField(label: 'Reprobados', ctrl: _reprobadosCtrl),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _foliosCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Folios',
                  prefixIcon: Icon(Icons.confirmation_number),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _informadoPorCtrl,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Informado por',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              if ((_error ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save),
          label: Text(_saving ? 'Guardando...' : 'Guardar'),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final int? total;

  const _SectionLabel({required this.label, this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (total != null)
            Chip(
              label: Text('Total: $total'),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _NumberGrid extends StatelessWidget {
  final List<Widget> children;

  const _NumberGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 460;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map(
                (child) => SizedBox(
                  width: wide
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;

  const _NumberField({required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function({required bool reset}) onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => onRetry(reset: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

int _intValue(TextEditingController ctrl) {
  return int.tryParse(ctrl.text.trim()) ?? 0;
}

String _formatDate(DateTime date) {
  String two(int x) => x.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}
