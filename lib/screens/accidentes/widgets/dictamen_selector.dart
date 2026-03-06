import 'package:flutter/material.dart';
import '../../../models/dictamen_item.dart';
import '../../../models/hecho_form_data.dart';
import '../../../services/dictamenes_form_service.dart';
import '../../../services/dictamenes_service.dart';

class DictamenSelector extends StatefulWidget {
  final HechoFormData data;
  final bool disabled;
  final ValueChanged<DictamenItem?> onSelected;

  const DictamenSelector({
    super.key,
    required this.data,
    required this.disabled,
    required this.onSelected,
  });

  @override
  State<DictamenSelector> createState() => _DictamenSelectorState();
}

class _DictamenSelectorState extends State<DictamenSelector> {
  bool _loading = false;
  List<DictamenItem> _items = const [];
  DictamenItem? _selected;

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final items = await DictamenesFormService(DictamenesService()).fetchAll();
      DictamenItem? selected;
      if (widget.data.dictamenId != null) {
        final found = items
            .where((d) => d.id == widget.data.dictamenId)
            .toList();
        selected = found.isEmpty ? null : found.first;
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _selected = selected;
      });
      widget.onSelected(_selected);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _selected = null;
        widget.data.dictamenId = null;
      });
      widget.onSelected(null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar dictámenes: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void didUpdateWidget(covariant DictamenSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.situacion != 'TURNADO') {
      _selected = null;
      _items = const [];
      widget.data.dictamenId = null;
      widget.onSelected(null);
    } else {
      if (_items.isEmpty && !_loading) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.situacion != 'TURNADO') return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Dictamen *',
                  border: OutlineInputBorder(),
                ),
                value: widget.data.dictamenId,
                items: _items
                    .map(
                      (d) => DropdownMenuItem<int>(
                        value: d.id,
                        child: Text(d.label, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (widget.disabled || _loading)
                    ? null
                    : (id) {
                        setState(() {
                          widget.data.dictamenId = id;
                          _selected = (id == null)
                              ? null
                              : _items.firstWhere((x) => x.id == id);
                        });
                        widget.onSelected(_selected);
                      },
                validator: (v) {
                  if (widget.data.situacion == 'TURNADO' && v == null)
                    return 'Requerido';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: (widget.disabled || _loading) ? null : _load,
                icon: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text(''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _loading
              ? 'Cargando dictámenes...'
              : (_items.isEmpty
                    ? 'No hay dictámenes para seleccionar.'
                    : 'Selecciona el dictamen (Oficio MP se llena automático).'),
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}
