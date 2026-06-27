import 'package:flutter/material.dart';

import '../../models/conduce_legalidad.dart';
import '../../services/conduce_legalidad_service.dart';

class ConduceLegalidadOperativoFormScreen extends StatefulWidget {
  final ConduceLegalidadOperativo? initialOperativo;

  const ConduceLegalidadOperativoFormScreen({super.key, this.initialOperativo});

  @override
  State<ConduceLegalidadOperativoFormScreen> createState() =>
      _ConduceLegalidadOperativoFormScreenState();
}

class _ConduceLegalidadOperativoFormScreenState
    extends State<ConduceLegalidadOperativoFormScreen> {
  static const _operativoNombre = 'Operativo conduce con legalidad';

  final _formKey = GlobalKey<FormState>();
  final _municipioCtrl = TextEditingController(text: 'Morelia');
  final _lugarCtrl = TextEditingController();

  DateTime _fecha = DateTime.now();
  TimeOfDay _hora = TimeOfDay.now();
  bool _saving = false;

  bool get _editing => widget.initialOperativo != null;

  @override
  void initState() {
    super.initState();
    _hydrateInitialOperativo();
  }

  @override
  void dispose() {
    _municipioCtrl.dispose();
    _lugarCtrl.dispose();
    super.dispose();
  }

  void _hydrateInitialOperativo() {
    final operativo = widget.initialOperativo;
    if (operativo == null) return;

    _municipioCtrl.text = operativo.municipio?.trim().isNotEmpty == true
        ? operativo.municipio!
        : 'Morelia';
    _lugarCtrl.text = operativo.lugar ?? '';
    _fecha = _parseDate(operativo.fecha) ?? DateTime.now();
    _hora = _parseTime(operativo.horaInicio) ?? TimeOfDay.now();
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _fecha = picked);
    }
  }

  Future<void> _pickHora() async {
    final picked = await showTimePicker(context: context, initialTime: _hora);
    if (picked != null && mounted) {
      setState(() => _hora = picked);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final payload = {
        'fecha': _date(_fecha),
        'hora_inicio': _time(_hora),
        'municipio': _emptyToNull(_municipioCtrl.text),
        'lugar': _emptyToNull(_lugarCtrl.text),
      };

      if (_editing) {
        await ConduceLegalidadService.updateOperativo(
          widget.initialOperativo!.id,
          payload,
        );
      } else {
        await ConduceLegalidadService.createOperativo({
          ...payload,
          'estado': 'activo',
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editing
                ? 'Operativo actualizado correctamente.'
                : 'Operativo activado correctamente.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final action = _editing ? 'actualizar' : 'activar';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al $action: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar operativo' : 'Activar operativo'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Operativo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fact_check_outlined),
              ),
              child: const Text(
                _operativoNombre,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickFecha,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(_date(_fecha)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickHora,
                    icon: const Icon(Icons.schedule),
                    label: Text(_time(_hora)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _municipioCtrl,
              decoration: const InputDecoration(
                labelText: 'Municipio',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lugarCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Punto o lugar',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Captura el punto.' : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _editing
                          ? Icons.save_outlined
                          : Icons.play_circle_outline,
                    ),
              label: Text(
                _saving
                    ? 'Guardando...'
                    : (_editing ? 'Guardar cambios' : 'Activar operativo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _emptyToNull(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  DateTime? _parseDate(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  TimeOfDay? _parseTime(String? value) {
    final text = value?.trim();
    if (text == null || text.length < 5) return null;
    final hour = int.tryParse(text.substring(0, 2));
    final minute = int.tryParse(text.substring(3, 5));
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _date(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _time(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
