import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/hechos/hechos_catalogos.dart';
import '../../../models/dictamen_item.dart';
import '../../../models/hecho_form_data.dart';
import '../../../services/hechos_form_service.dart';
import '../../../services/offline_sync_service.dart';
import 'ubicacion_card.dart';
import 'photo_card.dart';
import 'danos_patrimoniales_card.dart';
import 'dictamen_selector.dart';

enum HechoFormMode { create, edit }

class HechoForm extends StatefulWidget {
  final HechoFormMode mode;
  final HechoFormData data;
  final Future<OfflineActionResult> Function({
    required HechoFormData data,
    required DictamenItem? dictamenSelected,
    required File? fotoLugar,
    required File? fotoSituacion,
  })
  onSubmit;
  final Future<void> Function(OfflineActionResult result, HechoFormData data)?
  onSubmitted;

  const HechoForm({
    super.key,
    required this.mode,
    required this.data,
    required this.onSubmit,
    this.onSubmitted,
  });

  @override
  State<HechoForm> createState() => _HechoFormState();
}

class _HechoFormState extends State<HechoForm> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  TimeOfDay? _hora;
  DateTime? _fecha;

  final _folioCtrl = TextEditingController();
  final _peritoCtrl = TextEditingController();
  final _authPracCtrl = TextEditingController();
  final _unidadCtrl = TextEditingController();

  final _calleCtrl = TextEditingController();
  final _coloniaCtrl = TextEditingController();
  final _entreCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController();

  final _vehMpCtrl = TextEditingController();
  final _persMpCtrl = TextEditingController();

  final _propsCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();

  final _picker = ImagePicker();
  File? _fotoLugar;
  File? _fotoSituacion;

  DictamenItem? _dictamenSelected;

  @override
  void initState() {
    super.initState();
    _syncFromData();
  }

  @override
  void didUpdateWidget(covariant HechoForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      _syncFromData();
    }
  }

  void _syncFromData() {
    final d = widget.data;

    _hora = d.hora;
    _fecha = d.fecha;

    _folioCtrl.text = d.folioC5i;
    _peritoCtrl.text = d.perito;
    _authPracCtrl.text = d.autorizacionPractico;
    _unidadCtrl.text = d.unidad;

    _calleCtrl.text = d.calle;
    _coloniaCtrl.text = d.colonia;
    _entreCtrl.text = d.entreCalles;
    _municipioCtrl.text = d.municipio;

    _vehMpCtrl.text = d.vehiculosMp;
    _persMpCtrl.text = d.personasMp;

    _propsCtrl.text = d.propiedadesAfectadas;
    _montoCtrl.text = d.montoDanos;
  }

  @override
  void dispose() {
    _folioCtrl.dispose();
    _peritoCtrl.dispose();
    _authPracCtrl.dispose();
    _unidadCtrl.dispose();
    _calleCtrl.dispose();
    _coloniaCtrl.dispose();
    _entreCtrl.dispose();
    _municipioCtrl.dispose();
    _vehMpCtrl.dispose();
    _persMpCtrl.dispose();
    _propsCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());

  String? _safeDropdownValue(String? value, List<String> options) {
    if (value == null) return null;
    return options.contains(value) ? value : null;
  }

  Future<void> _pickHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora ?? widget.data.hora ?? TimeOfDay.now(),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _hora = picked;
      widget.data.hora = picked;
    });
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? widget.data.fecha ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _fecha = picked;
      widget.data.fecha = picked;
    });
  }

  Future<void> _pickPhoto(bool isLugar) async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null || !mounted) return;

    setState(() {
      final f = File(x.path);
      if (isLugar) {
        _fotoLugar = f;
      } else {
        _fotoSituacion = f;
      }
    });
  }

  bool _validateBusinessRules() {
    final d = widget.data;

    if (_hora == null ||
        _fecha == null ||
        d.sector == null ||
        d.tipoHecho == null ||
        d.superficieVia == null ||
        d.tiempo == null ||
        d.clima == null ||
        d.condiciones == null ||
        d.controlTransito == null ||
        d.causa == null ||
        d.colisionCamino == null ||
        d.situacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos obligatorios')),
      );
      return false;
    }

    if (d.situacion == 'TURNADO' &&
        (d.dictamenId == null || _dictamenSelected == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona el dictamen')));
      return false;
    }

    if (d.danosPatrimoniales) {
      final props = _propsCtrl.text.trim();
      final monto = _montoCtrl.text.trim();

      if (props.isEmpty && monto.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Si hay daños patrimoniales, captura el monto o describe las propiedades afectadas.',
            ),
          ),
        );
        return false;
      }
    }

    return true;
  }

  void _syncToData() {
    final d = widget.data;

    d.folioC5i = _folioCtrl.text;
    d.perito = _peritoCtrl.text;
    d.autorizacionPractico = _authPracCtrl.text;
    d.unidad = _unidadCtrl.text;

    d.calle = _calleCtrl.text;
    d.colonia = _coloniaCtrl.text;
    d.entreCalles = _entreCtrl.text;
    d.municipio = _municipioCtrl.text;

    d.vehiculosMp = _vehMpCtrl.text;
    d.personasMp = _persMpCtrl.text;

    d.propiedadesAfectadas = _propsCtrl.text;
    d.montoDanos = _montoCtrl.text;

    d.hora = _hora;
    d.fecha = _fecha;
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    _syncToData();
    if (!_validateBusinessRules()) return;

    setState(() => _submitting = true);

    try {
      final result = await widget.onSubmit(
        data: widget.data,
        dictamenSelected: _dictamenSelected,
        fotoLugar: _fotoLugar,
        fotoSituacion: _fotoSituacion,
      );

      if (!mounted) return;
      if (widget.onSubmitted != null) {
        await widget.onSubmitted!(result, widget.data);
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fallo: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    final sectorValue = _safeDropdownValue(
      d.sector,
      HechosCatalogos.sectoresUi,
    );
    final tipoHechoValue = _safeDropdownValue(
      d.tipoHecho,
      HechosCatalogos.tiposHecho,
    );
    final superficieViaValue = _safeDropdownValue(
      d.superficieVia,
      HechosCatalogos.superficiesViaUi,
    );
    final tiempoValue = _safeDropdownValue(d.tiempo, HechosCatalogos.tiemposUi);
    final climaValue = _safeDropdownValue(d.clima, HechosCatalogos.climasUi);
    final condicionesValue = _safeDropdownValue(
      d.condiciones,
      HechosCatalogos.condicionesUi,
    );
    final controlTransitoValue = _safeDropdownValue(
      d.controlTransito,
      HechosCatalogos.controlesTransitoUi,
    );
    final causaValue = _safeDropdownValue(d.causa, HechosCatalogos.causasUi);
    final colisionCaminoValue = _safeDropdownValue(
      d.colisionCamino,
      HechosCatalogos.colisionCaminoUi,
    );
    final situacionValue = _safeDropdownValue(
      d.situacion,
      HechosCatalogos.situaciones,
    );

    return Form(
      key: _formKey,
      child: Column(
        children: [
          UbicacionCard(
            data: d,
            disabled: _submitting,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),

          DanosPatrimonialesCard(
            data: d,
            disabled: _submitting,
            propsCtrl: _propsCtrl,
            montoCtrl: _montoCtrl,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),

          PhotoCard(
            title: 'Foto del hecho (opcional)',
            file: _fotoLugar,
            disabled: _submitting,
            onPick: () => _pickPhoto(true),
            onClear: () => setState(() => _fotoLugar = null),
          ),
          PhotoCard(
            title: 'Foto de la situación (opcional)',
            file: _fotoSituacion,
            disabled: _submitting,
            onPick: () => _pickPhoto(false),
            onClear: () => setState(() => _fotoSituacion = null),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _folioCtrl,
                  decoration: _dec('Folio C5i *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _peritoCtrl,
                  decoration: _dec('Perito *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _authPracCtrl,
                  decoration: _dec('Autorización Práctico'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _unidadCtrl,
                  decoration: _dec('Unidad *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _submitting ? null : _pickHora,
                  child: InputDecorator(
                    decoration: _dec('Hora *'),
                    child: Text(
                      _hora != null
                          ? HechosFormService.horaStr(_hora!)
                          : 'Seleccionar',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _submitting ? null : _pickFecha,
                  child: InputDecorator(
                    decoration: _dec('Fecha *'),
                    child: Text(
                      _fecha != null
                          ? HechosFormService.ymd(_fecha!)
                          : 'Seleccionar',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Sector *'),
            value: sectorValue,
            items: HechosCatalogos.sectoresUi
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(v, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _submitting ? null : (v) => setState(() => d.sector = v),
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          TextFormField(
            controller: _calleCtrl,
            decoration: _dec('Calle *'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _coloniaCtrl,
            decoration: _dec('Colonia *'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _entreCtrl,
            decoration: _dec('Entre calles'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _municipioCtrl,
            decoration: _dec('Municipio *'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Tipo Hecho *'),
            value: tipoHechoValue,
            items: HechosCatalogos.tiposHecho
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: _submitting
                ? null
                : (v) => setState(() => d.tipoHecho = v),
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Superficie vía *'),
            value: superficieViaValue,
            items: HechosCatalogos.superficiesViaUi
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: _submitting
                ? null
                : (v) => setState(() => d.superficieVia = v),
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _dec('Tiempo *'),
                  value: tiempoValue,
                  items: HechosCatalogos.tiemposUi
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => d.tiempo = v),
                  validator: (v) => v == null ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _dec('Clima *'),
                  value: climaValue,
                  items: HechosCatalogos.climasUi
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => d.clima = v),
                  validator: (v) => v == null ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Condiciones *'),
            value: condicionesValue,
            items: HechosCatalogos.condicionesUi
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(v, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _submitting
                ? null
                : (v) => setState(() => d.condiciones = v),
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Control tránsito *'),
            value: controlTransitoValue,
            items: HechosCatalogos.controlesTransitoUi
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: _submitting
                ? null
                : (v) => setState(() => d.controlTransito = v),
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Checaron antecedentes?'),
            value: d.checaronAntecedentes,
            onChanged: _submitting
                ? null
                : (v) => setState(() => d.checaronAntecedentes = v ?? false),
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Causas *'),
            value: causaValue,
            items: HechosCatalogos.causasUi
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: _submitting ? null : (v) => setState(() => d.causa = v),
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Colisión camino *'),
            value: colisionCaminoValue,
            items: HechosCatalogos.colisionCaminoUi
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: _submitting
                ? null
                : (v) => setState(() => d.colisionCamino = v),
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: _dec('Situación *'),
            value: situacionValue,
            items: HechosCatalogos.situaciones
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: _submitting
                ? null
                : (v) {
                    setState(() {
                      d.situacion = v;
                      if (d.situacion != 'TURNADO') {
                        d.dictamenId = null;
                        _dictamenSelected = null;
                      }
                    });
                  },
            validator: (v) => v == null ? 'Requerido' : null,
          ),

          DictamenSelector(
            data: d,
            disabled: _submitting,
            onSelected: (sel) => _dictamenSelected = sel,
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _vehMpCtrl,
                  decoration: _dec('Vehículos MP *'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _persMpCtrl,
                  decoration: _dec('Personas MP *'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.mode == HechoFormMode.create
                          ? 'Registrar Hecho'
                          : 'Guardar cambios',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
