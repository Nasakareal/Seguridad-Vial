import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/vehiculos/aseguradoras_vehiculo.dart';
import '../../core/vehiculos/colores_vehiculo.dart';
import '../../core/vehiculos/estados_republica.dart';
import '../../core/vehiculos/marcas_vehiculo.dart';
import '../../core/vehiculos/vehiculo_taxonomia.dart';
import '../../core/licencias/licencia_barcode_payload.dart';
import '../../models/conduce_legalidad.dart';
import '../../services/conduce_legalidad_service.dart';
import '../../services/gruas_catalog_service.dart';
import '../../services/photo_picker_service.dart';
import '../../services/vehiculo_form_service.dart';
import '../../widgets/marca_vehiculo_dropdown.dart';
import '../../widgets/safe_network_image.dart';
import '../../widgets/tarjeta_circulacion_scanner_screen.dart';

class ConduceLegalidadCapturaScreen extends StatefulWidget {
  final int operativoId;
  final ConduceLegalidadCaptura? initialCaptura;

  const ConduceLegalidadCapturaScreen({
    super.key,
    required this.operativoId,
    this.initialCaptura,
  });

  @override
  State<ConduceLegalidadCapturaScreen> createState() =>
      _ConduceLegalidadCapturaScreenState();
}

class _ConduceLegalidadCapturaScreenState
    extends State<ConduceLegalidadCapturaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _narrativaCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController(text: 'Morelia');
  final _lugarCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  bool _loadingMeta = true;
  bool _saving = false;
  String? _metaError;
  ConduceLegalidadMeta? _meta;
  final List<ConduceLegalidadVehiculo> _vehiculos = [];
  final List<ConduceLegalidadPersona> _personas = [];
  final List<ConduceLegalidadFoto> _fotosExistentes = [];
  final List<File> _fotos = [];
  final ImagePicker _picker = ImagePicker();

  bool get _editing => widget.initialCaptura != null;

  @override
  void initState() {
    super.initState();
    _hydrateInitialCaptura();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeta());
  }

  @override
  void dispose() {
    _narrativaCtrl.dispose();
    _municipioCtrl.dispose();
    _lugarCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  void _hydrateInitialCaptura() {
    final captura = widget.initialCaptura;
    if (captura == null) return;

    _narrativaCtrl.text = captura.narrativa ?? '';
    _municipioCtrl.text = captura.municipio?.trim().isNotEmpty == true
        ? captura.municipio!
        : 'Morelia';
    _lugarCtrl.text = captura.lugar ?? '';
    _observacionesCtrl.text = captura.observaciones ?? '';
    _vehiculos
      ..clear()
      ..addAll(captura.vehiculos);
    _personas
      ..clear()
      ..addAll(captura.personas);
    _fotosExistentes
      ..clear()
      ..addAll(captura.fotos);
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _metaError = null;
    });
    try {
      final meta = await ConduceLegalidadService.fetchMeta();
      if (!mounted) return;
      setState(() {
        _meta = meta;
        _loadingMeta = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _metaError = e.toString();
        _loadingMeta = false;
      });
    }
  }

  Future<void> _addVehiculo() async {
    final vehiculo = await showConduceLegalidadVehiculoModal(
      context,
      fundamentos: _meta?.fundamentosCorralon ?? const [],
    );
    if (vehiculo == null || !mounted) return;
    setState(() {
      _vehiculos.add(vehiculo);
      _aplicarNarrativaSugerida(vehiculo);
    });
  }

  void _aplicarNarrativaSugerida(ConduceLegalidadVehiculo vehiculo) {
    final narrativa = (vehiculo.infraccion?.narrativaSugerida ?? '').trim();
    if (narrativa.isEmpty) return;

    final actual = _narrativaCtrl.text.trim();
    if (actual.contains(narrativa)) return;

    _narrativaCtrl.text = actual.isEmpty ? narrativa : '$actual\n\n$narrativa';
  }

  Future<void> _addPersona() async {
    final persona = await showConduceLegalidadPersonaModal(context);
    if (persona == null || !mounted) return;
    setState(() => _personas.add(persona));
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final hasNarrativa = _narrativaCtrl.text.trim().isNotEmpty;
    if (!hasNarrativa &&
        _vehiculos.isEmpty &&
        _personas.isEmpty &&
        _fotosExistentes.isEmpty &&
        _fotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Captura una narrativa o agrega vehiculos/personas/fotos.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'fecha': _dateForPayload(),
        'hora': _timeForPayload(),
        'municipio': _emptyToNull(_municipioCtrl.text),
        'lugar': _emptyToNull(_lugarCtrl.text),
        'narrativa': _emptyToNull(_narrativaCtrl.text),
        'observaciones': _emptyToNull(_observacionesCtrl.text),
        'vehiculos': _vehiculos.map((item) => item.toJson()).toList(),
        'personas': _personas.map((item) => item.toJson()).toList(),
      };

      final result = _editing
          ? await ConduceLegalidadService.updateCaptura(
              operativoId: widget.operativoId,
              capturaId: widget.initialCaptura!.id,
              payload: payload,
              fotos: List<File>.from(_fotos),
            )
          : await ConduceLegalidadService.storeCaptura(
              operativoId: widget.operativoId,
              payload: payload,
              fotos: List<File>.from(_fotos),
            );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final files = await PhotoPickerService.pickAndCropMultiImage(
      context,
      _picker,
    );
    if (files.isEmpty || !mounted) return;

    setState(() {
      for (final file in files) {
        if (!_fotos.any((current) => current.path == file.path)) {
          _fotos.add(file);
        }
      }
    });
  }

  Future<void> _pickFromCamera() async {
    final file = await PhotoPickerService.pickAndCropImage(
      context,
      _picker,
      source: ImageSource.camera,
    );
    if (file == null || !mounted) return;

    setState(() {
      if (!_fotos.any((current) => current.path == file.path)) {
        _fotos.add(file);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar captura' : 'Agregar captura'),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
                children: [
                  if (_metaError != null)
                    _WarningPanel(text: _metaError!, onRetry: _loadMeta),
                  if (_metaError != null) const SizedBox(height: 12),
                  TextFormField(
                    controller: _narrativaCtrl,
                    minLines: 5,
                    maxLines: 12,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Narrativa',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes),
                    ),
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
                      labelText: 'Lugar especifico',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle(
                    title: 'Vehiculos',
                    trailing: TextButton.icon(
                      onPressed: _saving ? null : _addVehiculo,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar'),
                    ),
                  ),
                  if (_vehiculos.isEmpty)
                    const _EmptyLine(text: 'Sin vehiculos agregados.')
                  else
                    ..._vehiculos.asMap().entries.map(
                      (entry) => _VehicleTile(
                        vehiculo: entry.value,
                        onRemove: () =>
                            setState(() => _vehiculos.removeAt(entry.key)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _SectionTitle(
                    title: 'Personas',
                    trailing: TextButton.icon(
                      onPressed: _saving ? null : _addPersona,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar'),
                    ),
                  ),
                  if (_personas.isEmpty)
                    const _EmptyLine(text: 'Sin personas agregadas.')
                  else
                    ..._personas.asMap().entries.map(
                      (entry) => _PersonTile(
                        persona: entry.value,
                        onRemove: () =>
                            setState(() => _personas.removeAt(entry.key)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _SectionTitle(
                    title: 'Fotos',
                    trailing: Text(
                      '${_fotosExistentes.length + _fotos.length}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_fotosExistentes.isNotEmpty) ...[
                    _ExistingFotosPanel(fotos: _fotosExistentes),
                    const SizedBox(height: 10),
                  ],
                  _FotosPickerPanel(
                    fotos: _fotos,
                    saving: _saving,
                    emptyText: _fotosExistentes.isEmpty
                        ? 'Sin fotos'
                        : 'Sin fotos nuevas',
                    onGallery: _pickFromGallery,
                    onCamera: _pickFromCamera,
                    onRemove: (index) => setState(() {
                      _fotos.removeAt(index);
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _observacionesCtrl,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.info_outline),
                    ),
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
                        : const Icon(Icons.save),
                    label: Text(
                      _saving
                          ? 'Guardando...'
                          : (_editing
                                ? 'Actualizar captura'
                                : 'Guardar captura'),
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

  String _dateForPayload() {
    final existing = widget.initialCaptura?.fecha?.trim();
    if (_editing && existing != null && existing.isNotEmpty) return existing;
    return _date(DateTime.now());
  }

  String _timeForPayload() {
    final existing = widget.initialCaptura?.hora?.trim();
    if (_editing && existing != null && existing.length >= 5) {
      return existing.substring(0, 5);
    }
    return _time(TimeOfDay.now());
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

Future<ConduceLegalidadVehiculo?> showConduceLegalidadVehiculoModal(
  BuildContext context, {
  required List<ConduceLegalidadFundamento> fundamentos,
}) {
  return showModalBottomSheet<ConduceLegalidadVehiculo>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _VehiculoModal(fundamentos: fundamentos),
  );
}

class _VehiculoModal extends StatefulWidget {
  final List<ConduceLegalidadFundamento> fundamentos;

  const _VehiculoModal({required this.fundamentos});

  @override
  State<_VehiculoModal> createState() => _VehiculoModalState();
}

class _VehiculoModalState extends State<_VehiculoModal> {
  final _formKey = GlobalKey<FormState>();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _lineaCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _placasCtrl = TextEditingController();
  final _serieCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController(text: '2');
  final _tipoServicioCtrl = TextEditingController(text: 'PARTICULAR');
  final _tarjetaCtrl = TextEditingController();
  final _aseguradoraCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  String? _tipoGeneralSeleccionado = 'motocicleta';
  String? _tipoCarroceriaSeleccionada;
  String? _estadoPlacasSeleccionado;
  ConduceLegalidadFundamento? _fundamento;
  bool _cargandoGruas = true;
  List<Map<String, dynamic>> _gruas = [];
  int? _gruaIdSeleccionada;
  int? _corralonGruaIdSeleccionada;
  bool _antecedenteVehiculo = false;
  String? _rawTarjeta;
  String? _motivoRetencionAuto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarGruas());
  }

  @override
  void dispose() {
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _lineaCtrl.dispose();
    _colorCtrl.dispose();
    _placasCtrl.dispose();
    _serieCtrl.dispose();
    _capacidadCtrl.dispose();
    _tipoServicioCtrl.dispose();
    _tarjetaCtrl.dispose();
    _aseguradoraCtrl.dispose();
    _motivoCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  String _t(TextEditingController controller) => controller.text.trim();

  List<String> _carroceriasDeTipoGeneral(String? tipoGeneral) {
    return VehiculoTaxonomia.carroceriasDeTipoGeneral(tipoGeneral);
  }

  String _marcaParaGuardar() {
    return MarcasVehiculo.valueFromAny(
          _t(_marcaCtrl),
          tipoGeneral: _tipoGeneralSeleccionado,
          carroceria: _tipoCarroceriaSeleccionada,
        ) ??
        _t(_marcaCtrl);
  }

  void _syncMarcaConTipoYCarroceria() {
    final value = MarcasVehiculo.valueFromAny(
      _marcaCtrl.text,
      tipoGeneral: _tipoGeneralSeleccionado,
      carroceria: _tipoCarroceriaSeleccionada,
    );
    _marcaCtrl.text = value ?? '';
  }

  String _colorDropdownValue() {
    return ColoresVehiculo.normalizeUnknown(_t(_colorCtrl));
  }

  void _setColor(String? value) {
    _colorCtrl.text = value ?? '';
  }

  String _aseguradoraDropdownValue() {
    return AseguradorasVehiculo.valueFromAny(_t(_aseguradoraCtrl)) ?? '';
  }

  void _setAseguradora(String? value) {
    _aseguradoraCtrl.text = value ?? '';
  }

  Future<void> _cargarGruas() async {
    try {
      final gruas = await GruasCatalogService.fetchSiniestrosGruas();
      if (!mounted) return;
      setState(() {
        _gruas = gruas;
        if (!GruasCatalogService.containsId(_gruas, _gruaIdSeleccionada)) {
          _gruaIdSeleccionada = null;
        }
        if (!GruasCatalogService.containsId(
          _gruas,
          _corralonGruaIdSeleccionada,
        )) {
          _corralonGruaIdSeleccionada = null;
        }
        _cargandoGruas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoGruas = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar gruas: $e')),
      );
    }
  }

  String? _nombreGruaById(int? id) {
    return GruasCatalogService.findNameById(_gruas, id);
  }

  int? _toIntOrNull(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  String? _tipoGeneralValidator(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Requerido';
    return null;
  }

  String? _tipoCarroceriaValidator(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Requerido';
    return null;
  }

  bool _isTipoGeneralDisponible(String? value) {
    final clean = (value ?? '').trim();
    return clean.isNotEmpty && VehiculoTaxonomia.carrocerias.containsKey(clean);
  }

  bool _isCarroceriaDisponible(String? tipoGeneral, String? carroceria) {
    final clean = (carroceria ?? '').trim();
    if (clean.isEmpty) return false;
    return _carroceriasDeTipoGeneral(tipoGeneral).contains(clean);
  }

  String? _inferirTipoGeneralPorCarroceria(String? carroceria) {
    final clean = (carroceria ?? '').trim();
    if (clean.isEmpty) return null;

    for (final entry in VehiculoTaxonomia.carrocerias.entries) {
      if (entry.value.contains(clean)) return entry.key;
    }

    return null;
  }

  Future<void> _scanTarjeta() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const TarjetaCirculacionScannerScreen(),
      ),
    );
    final text = raw?.trim() ?? '';
    if (text.isEmpty || !mounted) return;

    final parsed = VehiculoFormService.parseTarjetaCirculacionQr(text);
    var applied = 0;

    bool setText(TextEditingController controller, String? value) {
      final clean = (value ?? '').trim();
      if (clean.isEmpty || controller.text.trim() == clean) return false;
      controller.text = clean;
      return true;
    }

    setState(() {
      _rawTarjeta = parsed.rawText;
      final tipoGeneral =
          parsed.tipoGeneral ??
          _inferirTipoGeneralPorCarroceria(parsed.tipoCarroceria);
      if (_isTipoGeneralDisponible(tipoGeneral) &&
          _tipoGeneralSeleccionado != tipoGeneral) {
        _tipoGeneralSeleccionado = tipoGeneral;
        _tipoCarroceriaSeleccionada = null;
        applied += 1;
      }

      final tipoCarroceria = parsed.tipoCarroceria;
      if (_isCarroceriaDisponible(_tipoGeneralSeleccionado, tipoCarroceria) &&
          _tipoCarroceriaSeleccionada != tipoCarroceria) {
        _tipoCarroceriaSeleccionada = tipoCarroceria;
        applied += 1;
      }

      final marca = MarcasVehiculo.valueFromAny(
        parsed.marca,
        tipoGeneral: _tipoGeneralSeleccionado,
        carroceria: _tipoCarroceriaSeleccionada,
      );
      if (setText(_marcaCtrl, marca ?? parsed.marca)) applied += 1;
      if (setText(_lineaCtrl, parsed.linea)) applied += 1;
      if (setText(_modeloCtrl, parsed.modelo)) applied += 1;
      if (setText(
        _colorCtrl,
        ColoresVehiculo.normalizeUnknown(parsed.color ?? ''),
      )) {
        applied += 1;
      }
      if (setText(
        _placasCtrl,
        VehiculoFormService.normalizePlacas(parsed.placas ?? ''),
      )) {
        applied += 1;
      }
      if (setText(
        _serieCtrl,
        VehiculoFormService.normalizeSerie(parsed.serie ?? ''),
      )) {
        applied += 1;
      }
      final tipoServicio = VehiculoFormService.normalizeTipoServicioPlaca(
        parsed.tipoServicio,
      );
      if (setText(_tipoServicioCtrl, tipoServicio)) applied += 1;
      if (VehiculoFormService.isTipoServicioPublicoFederal(
        _tipoServicioCtrl.text,
      )) {
        if (_estadoPlacasSeleccionado != null) {
          _estadoPlacasSeleccionado = null;
          applied += 1;
        }
      } else {
        final estado = EstadosRepublica.valueFromAny(parsed.estadoPlacas);
        if ((estado ?? '').trim().isNotEmpty &&
            _estadoPlacasSeleccionado != estado) {
          _estadoPlacasSeleccionado = estado;
          applied += 1;
        }
      }
      if (setText(_tarjetaCtrl, parsed.tarjetaCirculacionNombre)) {
        applied += 1;
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('QR leido. Campos llenados: $applied.')),
    );
  }

  void _setFundamento(ConduceLegalidadFundamento? value) {
    final currentMotivo = _motivoCtrl.text.trim();
    final shouldAutofill =
        currentMotivo.isEmpty ||
        (_motivoRetencionAuto != null && currentMotivo == _motivoRetencionAuto);
    final nextMotivo = _motivoRetencionTexto(value);

    setState(() {
      _fundamento = value;
      _motivoRetencionAuto = nextMotivo;
      if (shouldAutofill) {
        _motivoCtrl.text = nextMotivo ?? '';
      }
    });
  }

  String? _motivoRetencionTexto(ConduceLegalidadFundamento? fundamento) {
    if (fundamento == null) return null;

    final referencia = (fundamento.referenciaLegalCorta ?? '').trim();
    final motivo = fundamento.display.trim();
    if (referencia.isNotEmpty && motivo.isNotEmpty) {
      return '$referencia - $motivo';
    }
    if (referencia.isNotEmpty) return referencia;
    if (motivo.isNotEmpty) return motivo;

    final fundamentoLegal = (fundamento.fundamentoLegal ?? '').trim();
    return fundamentoLegal.isEmpty ? null : fundamentoLegal;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final tipoServicio = VehiculoFormService.tipoServicioPlacaValue(
      _t(_tipoServicioCtrl),
    );
    final marca = _marcaParaGuardar();
    final validationError = VehiculoFormService.validateVehiculoBeforeSubmit(
      marca: marca,
      linea: _t(_lineaCtrl),
      color: _t(_colorCtrl),
      tipoServicio: tipoServicio,
      partesDanadas: '',
      tipoGeneral: _tipoGeneralSeleccionado,
      tipoCarroceria: _tipoCarroceriaSeleccionada,
      placas: _t(_placasCtrl),
      estadoPlacas: _estadoPlacasSeleccionado,
      serie: _t(_serieCtrl),
      capacidad: _t(_capacidadCtrl),
      montoDanos: '',
      modelo: _t(_modeloCtrl),
      tarjetaCirculacionNombre: _t(_tarjetaCtrl),
      aseguradora: _t(_aseguradoraCtrl),
      requireMontoDanos: false,
      requirePartesDanadas: false,
    );
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    final hasIdentity = [
      _marcaCtrl.text,
      _lineaCtrl.text,
      _placasCtrl.text,
      _serieCtrl.text,
    ].any((value) => value.trim().isNotEmpty);
    if (!hasIdentity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Captura placas, serie, marca o linea del vehiculo.'),
        ),
      );
      return;
    }

    final placasClean = VehiculoFormService.normalizePlacas(_t(_placasCtrl));
    final estadoPlacasPayload = VehiculoFormService.estadoPlacasParaPayload(
      placas: placasClean,
      tipoServicio: tipoServicio,
      estadoPlacas: _estadoPlacasSeleccionado,
    );
    final gruaNombre = _nombreGruaById(_gruaIdSeleccionada);
    final corralonNombre = _nombreGruaById(_corralonGruaIdSeleccionada);

    Navigator.pop(
      context,
      ConduceLegalidadVehiculo(
        marca: _empty(marca),
        modelo: _empty(_t(_modeloCtrl)),
        tipoGeneral: _tipoGeneralSeleccionado,
        tipo: _tipoCarroceriaSeleccionada,
        linea: _empty(_t(_lineaCtrl)),
        color: _empty(_t(_colorCtrl)),
        placas: _empty(placasClean),
        estadoPlacas: _empty(estadoPlacasPayload),
        serie: _empty(VehiculoFormService.normalizeSerie(_t(_serieCtrl)) ?? ''),
        capacidadPersonas: _toIntOrNull(_t(_capacidadCtrl)) ?? 0,
        tipoServicio: _empty(tipoServicio),
        tarjetaCirculacionNombre: _empty(_t(_tarjetaCtrl)),
        gruaId: _gruaIdSeleccionada,
        corralonId: _corralonGruaIdSeleccionada,
        grua: _empty(gruaNombre),
        corralon: _empty(corralonNombre),
        aseguradora: _empty(_t(_aseguradoraCtrl)),
        antecedenteVehiculo: _antecedenteVehiculo,
        rawTarjetaQr: _rawTarjeta,
        licenciaPuntoInfraccionId: _fundamento?.id,
        retencionVehiculo: _fundamento != null,
        motivoRetencion: _empty(_motivoCtrl.text),
        observaciones: _empty(_observacionesCtrl.text),
        fundamentoLegal: _fundamento?.fundamentoLegal,
        infraccion: _fundamento,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carroceriasDisponibles = _carroceriasDeTipoGeneral(
      _tipoGeneralSeleccionado,
    );
    final tipoServicioSeleccionado = VehiculoFormService.tipoServicioPlacaValue(
      _tipoServicioCtrl.text,
    );
    final esServicioPublicoFederal =
        VehiculoFormService.isTipoServicioPublicoFederal(
          tipoServicioSeleccionado,
        );
    final tienePlacas = VehiculoFormService.normalizePlacas(
      _t(_placasCtrl),
    ).isNotEmpty;
    final requiereEstadoPlacas = tienePlacas && !esServicioPublicoFederal;
    final colorSeleccionado = _colorDropdownValue();
    final coloresDisponibles = ColoresVehiculo.opcionesConActual(
      colorSeleccionado,
    );
    final aseguradoraSeleccionada = _aseguradoraDropdownValue();

    if ((!tienePlacas || esServicioPublicoFederal) &&
        _estadoPlacasSeleccionado != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _estadoPlacasSeleccionado = null);
      });
    }

    return FractionallySizedBox(
      heightFactor: .92,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _ModalHeader(
                title: 'Agregar vehiculo',
                onClose: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _scanTarjeta,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear tarjeta'),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _tipoGeneralSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Tipo de vehiculo *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_car),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('-- Seleccione --'),
                  ),
                  ...VehiculoTaxonomia.tiposGenerales.map((item) {
                    return DropdownMenuItem<String>(
                      value: item['value'],
                      child: Text(item['label'] ?? ''),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _tipoGeneralSeleccionado = value;
                    _tipoCarroceriaSeleccionada = null;
                    _syncMarcaConTipoYCarroceria();
                  });
                },
                validator: _tipoGeneralValidator,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _tipoCarroceriaSeleccionada,
                decoration: const InputDecoration(
                  labelText: 'Carroceria *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.merge_type),
                ),
                items: carroceriasDisponibles.isEmpty
                    ? const [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('-- Seleccione tipo primero --'),
                        ),
                      ]
                    : [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('-- Seleccione --'),
                        ),
                        ...carroceriasDisponibles.map((carroceria) {
                          return DropdownMenuItem<String>(
                            value: carroceria,
                            child: Text(carroceria),
                          );
                        }),
                      ],
                onChanged: carroceriasDisponibles.isEmpty
                    ? null
                    : (value) {
                        setState(() {
                          _tipoCarroceriaSeleccionada = value;
                          _syncMarcaConTipoYCarroceria();
                        });
                      },
                validator: (value) {
                  if ((_tipoGeneralSeleccionado ?? '').isEmpty) return null;
                  return _tipoCarroceriaValidator(value);
                },
              ),
              const SizedBox(height: 10),
              MarcaVehiculoDropdown(
                controller: _marcaCtrl,
                tipoGeneral: _tipoGeneralSeleccionado,
                carroceria: _tipoCarroceriaSeleccionada,
                decoration: const InputDecoration(
                  labelText: 'Marca *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_offer),
                ),
              ),
              const SizedBox(height: 10),
              _text(
                _lineaCtrl,
                'Linea *',
                Icons.text_fields,
                validator: (value) => VehiculoFormService.validateRequiredText(
                  value,
                  max: 50,
                  label: 'Linea',
                ),
              ),
              _text(
                _modeloCtrl,
                'Modelo',
                Icons.calendar_month,
                validator: (value) => VehiculoFormService.validateOptionalText(
                  value,
                  max: 10,
                  label: 'Modelo',
                ),
              ),
              DropdownButtonFormField<String>(
                value: colorSeleccionado.isEmpty ? null : colorSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Color *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.color_lens),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('-- Seleccione --'),
                  ),
                  ...coloresDisponibles.map((color) {
                    return DropdownMenuItem<String>(
                      value: color,
                      child: Text(color),
                    );
                  }),
                ],
                onChanged: (value) => setState(() => _setColor(value)),
                validator: (value) => VehiculoFormService.validateRequiredText(
                  value,
                  max: 30,
                  label: 'Color',
                ),
              ),
              const SizedBox(height: 10),
              _text(
                _placasCtrl,
                'Placas',
                Icons.credit_card,
                validator: VehiculoFormService.validatePlacas,
                onChanged: (_) => setState(() {}),
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: tipoServicioSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Tipo de servicio de placa *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.miscellaneous_services),
                ),
                items: VehiculoFormService.tiposServicioPlaca.map((value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _tipoServicioCtrl.text = value;
                    if (VehiculoFormService.isTipoServicioPublicoFederal(
                      value,
                    )) {
                      _estadoPlacasSeleccionado = null;
                    }
                  });
                },
                validator: VehiculoFormService.validateTipoServicioPlaca,
              ),
              if (requiereEstadoPlacas) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _estadoPlacasSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Estado de placas *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.map),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('-- Seleccione --'),
                    ),
                    ...EstadosRepublica.estados.map((estado) {
                      return DropdownMenuItem<String>(
                        value: estado['value'],
                        child: Text(estado['label'] ?? ''),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _estadoPlacasSeleccionado = value);
                  },
                  validator: (value) {
                    if (!requiereEstadoPlacas) return null;
                    if ((value ?? '').trim().isEmpty) {
                      return 'Requerido si capturas placas';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 10),
              _text(
                _serieCtrl,
                'Serie/NIV',
                Icons.confirmation_number,
                validator: VehiculoFormService.validateSerie,
              ),
              _text(
                _capacidadCtrl,
                'Capacidad de personas *',
                Icons.people,
                keyboardType: TextInputType.number,
                validator: VehiculoFormService.validateCapacidad,
              ),
              _text(_tarjetaCtrl, 'Nombre en tarjeta', Icons.badge),
              _cargandoGruas
                  ? const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        title: Text('Cargando gruas...'),
                      ),
                    )
                  : DropdownButtonFormField<int?>(
                      value: _gruaIdSeleccionada,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Grua (empresa)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_shipping),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('SIN GRUA / N/A'),
                        ),
                        ..._gruas
                            .where((g) => GruasCatalogService.idOf(g) != null)
                            .map((g) {
                              final id = GruasCatalogService.idOf(g)!;
                              return DropdownMenuItem<int?>(
                                value: id,
                                child: Text(
                                  GruasCatalogService.displayName(g),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                      ],
                      onChanged: (value) {
                        setState(() => _gruaIdSeleccionada = value);
                      },
                    ),
              const SizedBox(height: 10),
              _cargandoGruas
                  ? const SizedBox.shrink()
                  : DropdownButtonFormField<int?>(
                      value: _corralonGruaIdSeleccionada,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Corralon (empresa)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.warehouse),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('SIN CORRALON / N/A'),
                        ),
                        ..._gruas
                            .where((g) => GruasCatalogService.idOf(g) != null)
                            .map((g) {
                              final id = GruasCatalogService.idOf(g)!;
                              return DropdownMenuItem<int?>(
                                value: id,
                                child: Text(
                                  GruasCatalogService.displayName(
                                    g,
                                    fallbackPrefix: 'CORRALON',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                      ],
                      onChanged: (value) {
                        setState(() => _corralonGruaIdSeleccionada = value);
                      },
                    ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: aseguradoraSeleccionada.isEmpty
                    ? null
                    : aseguradoraSeleccionada,
                decoration: const InputDecoration(
                  labelText: 'Aseguradora',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.policy),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('-- Sin aseguradora --'),
                  ),
                  ...AseguradorasVehiculo.opciones.map((aseguradora) {
                    return DropdownMenuItem<String>(
                      value: aseguradora,
                      child: Text(aseguradora),
                    );
                  }),
                ],
                onChanged: (value) => setState(() => _setAseguradora(value)),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Antecedente del vehiculo'),
                value: _antecedenteVehiculo,
                onChanged: (value) =>
                    setState(() => _antecedenteVehiculo = value),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ConduceLegalidadFundamento?>(
                value: _fundamento,
                isExpanded: true,
                itemHeight: null,
                menuMaxHeight: MediaQuery.of(context).size.height * .55,
                decoration: const InputDecoration(
                  labelText: 'Motivo de corralon',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.gavel_outlined),
                ),
                selectedItemBuilder: (context) => [
                  const _DropdownSelectedText('Sin fundamento seleccionado'),
                  ...widget.fundamentos.map(
                    (item) => _DropdownSelectedText(item.display),
                  ),
                ],
                items: [
                  const DropdownMenuItem<ConduceLegalidadFundamento?>(
                    value: null,
                    child: _DropdownMenuText('Sin fundamento seleccionado'),
                  ),
                  ...widget.fundamentos.map(
                    (item) => DropdownMenuItem<ConduceLegalidadFundamento?>(
                      value: item,
                      child: _DropdownMenuText(item.display),
                    ),
                  ),
                ],
                onChanged: _setFundamento,
              ),
              if (_fundamento != null) ...[
                const SizedBox(height: 8),
                Text(
                  _fundamento!.fundamentoLegal ?? _fundamento!.display,
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _text(
                _motivoCtrl,
                'Motivo de retencion',
                Icons.report_problem_outlined,
                maxLines: 3,
              ),
              _text(
                _observacionesCtrl,
                'Observaciones',
                Icons.info_outline,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.add),
                label: const Text('Agregar vehiculo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _text(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
          alignLabelWithHint: maxLines > 1,
        ),
        validator: validator,
        onChanged: onChanged,
      ),
    );
  }
}

Future<ConduceLegalidadPersona?> showConduceLegalidadPersonaModal(
  BuildContext context,
) {
  return showModalBottomSheet<ConduceLegalidadPersona>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _PersonaModal(),
  );
}

class _PersonaModal extends StatefulWidget {
  const _PersonaModal();

  @override
  State<_PersonaModal> createState() => _PersonaModalState();
}

class _PersonaModalState extends State<_PersonaModal> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _domicilioCtrl = TextEditingController();
  final _ocupacionCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  final _tipoLicenciaCtrl = TextEditingController();
  final _estadoLicenciaCtrl = TextEditingController();
  final _numeroLicenciaCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  String? _sexo;
  DateTime? _vigencia;
  bool _permanente = false;
  String? _rawLicencia;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _domicilioCtrl.dispose();
    _ocupacionCtrl.dispose();
    _edadCtrl.dispose();
    _tipoLicenciaCtrl.dispose();
    _estadoLicenciaCtrl.dispose();
    _numeroLicenciaCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanLicencia() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _LicenciaScannerScreen()),
    );
    final text = raw?.trim() ?? '';
    if (text.isEmpty || !mounted) return;

    final parsed = VehiculoFormService.parseLicenciaConducirQr(text);
    var applied = 0;

    bool setText(TextEditingController controller, String? value) {
      final clean = (value ?? '').trim();
      if (clean.isEmpty || controller.text.trim() == clean) return false;
      controller.text = clean;
      return true;
    }

    setState(() {
      _rawLicencia = parsed.rawText;
      if (setText(_numeroLicenciaCtrl, parsed.numeroLicencia)) applied += 1;
      if (setText(_nombreCtrl, parsed.nombre)) applied += 1;
      if (setText(_tipoLicenciaCtrl, parsed.tipoLicencia)) applied += 1;
      if (parsed.permanente) {
        _permanente = true;
        _vigencia = null;
        applied += 1;
      } else if (parsed.vigencia != null) {
        _permanente = false;
        _vigencia = parsed.vigencia;
        applied += 1;
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Licencia leida. Campos llenados: $applied.')),
    );
  }

  Future<void> _pickVigencia() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _vigencia ?? now,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _vigencia = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final hasIdentity =
        _nombreCtrl.text.trim().isNotEmpty ||
        _numeroLicenciaCtrl.text.trim().isNotEmpty;
    if (!hasIdentity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captura nombre o numero de licencia.')),
      );
      return;
    }

    Navigator.pop(
      context,
      ConduceLegalidadPersona(
        nombre: _empty(_nombreCtrl.text),
        telefono: _empty(_telefonoCtrl.text),
        domicilio: _empty(_domicilioCtrl.text),
        sexo: _sexo,
        ocupacion: _empty(_ocupacionCtrl.text),
        edad: int.tryParse(_edadCtrl.text.trim()),
        tipoLicencia: _empty(_tipoLicenciaCtrl.text),
        estadoLicencia: _empty(_estadoLicenciaCtrl.text),
        numeroLicencia: _empty(_numeroLicenciaCtrl.text),
        vigenciaLicencia: _permanente || _vigencia == null
            ? null
            : _date(_vigencia!),
        permanente: _permanente,
        rawLicenciaQr: _rawLicencia,
        observaciones: _empty(_observacionesCtrl.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final licenciaWarning = _licenciaWarningText();

    return FractionallySizedBox(
      heightFactor: .92,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _ModalHeader(
                title: 'Agregar persona',
                onClose: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _scanLicencia,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear licencia'),
                ),
              ),
              const SizedBox(height: 12),
              _text(_nombreCtrl, 'Nombre', Icons.person),
              _text(
                _telefonoCtrl,
                'Telefono',
                Icons.phone,
                keyboardType: TextInputType.phone,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: VehiculoFormService.validateTelefono,
              ),
              _text(_domicilioCtrl, 'Domicilio', Icons.home),
              DropdownButtonFormField<String>(
                value: _sexo,
                decoration: const InputDecoration(
                  labelText: 'Sexo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Sin dato')),
                  DropdownMenuItem(
                    value: 'MASCULINO',
                    child: Text('MASCULINO'),
                  ),
                  DropdownMenuItem(value: 'FEMENINO', child: Text('FEMENINO')),
                  DropdownMenuItem(value: 'OTRO', child: Text('OTRO')),
                ],
                onChanged: (value) => setState(() => _sexo = value),
              ),
              const SizedBox(height: 10),
              _text(_ocupacionCtrl, 'Ocupacion', Icons.work_outline),
              _text(
                _edadCtrl,
                'Edad',
                Icons.numbers,
                keyboardType: TextInputType.number,
                validator: VehiculoFormService.validateEdad,
              ),
              SwitchListTile(
                title: const Text('Licencia permanente'),
                value: _permanente,
                onChanged: (value) => setState(() {
                  _permanente = value;
                  if (value) _vigencia = null;
                }),
              ),
              if (!_permanente)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vigencia de licencia'),
                  subtitle: Text(
                    _vigencia == null ? 'Sin fecha' : _date(_vigencia!),
                  ),
                  trailing: IconButton(
                    tooltip: 'Seleccionar fecha',
                    onPressed: _pickVigencia,
                    icon: const Icon(Icons.date_range),
                  ),
                ),
              _text(_tipoLicenciaCtrl, 'Tipo de licencia', Icons.badge),
              _text(
                _estadoLicenciaCtrl,
                'Estado de licencia',
                Icons.map_outlined,
                onChanged: (_) => setState(() {}),
              ),
              _text(
                _numeroLicenciaCtrl,
                'Numero de licencia',
                Icons.confirmation_number_outlined,
              ),
              if (licenciaWarning != null) ...[
                _AttentionPanel(text: licenciaWarning),
                const SizedBox(height: 10),
              ],
              _text(
                _observacionesCtrl,
                'Observaciones',
                Icons.info_outline,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.add),
                label: const Text('Agregar persona'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _licenciaWarningText() {
    final estado = _estadoLicenciaCtrl.text.trim().toUpperCase();
    final suspendidaOCancelada =
        estado.contains('SUSPEND') || estado.contains('CANCEL');
    if (suspendidaOCancelada) {
      return 'Licencia suspendida o cancelada: registra el motivo de corralon Art. 328 fr. II en el vehiculo y no permitas que continue conduciendo.';
    }

    final estadoNoVigente =
        estado.contains('NO VIGENTE') ||
        estado.contains('VENCID') ||
        estado.contains('EXPIR') ||
        estado.contains('NO VALID') ||
        estado.contains('NO VALIDA');
    if (estadoNoVigente) {
      return 'Licencia no vigente: no permitas que continue conduciendo; debe presentarse una persona con licencia vigente.';
    }

    if (!_permanente && _vigencia != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final vigencia = DateTime(
        _vigencia!.year,
        _vigencia!.month,
        _vigencia!.day,
      );
      if (vigencia.isBefore(today)) {
        return 'Licencia vencida: no permitas que continue conduciendo; debe presentarse una persona con licencia vigente.';
      }
    }

    return null;
  }

  Widget _text(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        textCapitalization: TextCapitalization.words,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
          alignLabelWithHint: maxLines > 1,
        ),
        validator: validator,
      ),
    );
  }
}

class _LicenciaScannerScreen extends StatefulWidget {
  const _LicenciaScannerScreen();

  @override
  State<_LicenciaScannerScreen> createState() => _LicenciaScannerScreenState();
}

class _LicenciaScannerScreenState extends State<_LicenciaScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoZoom: true,
  );

  bool _handled = false;

  void _handleDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final raw = LicenciaBarcodePayload.fromBarcode(barcode)?.trim() ?? '';
      if (raw.isEmpty) continue;

      _handled = true;
      unawaited(_controller.stop());
      if (!mounted) return;
      Navigator.pop(context, raw);
      return;
    }
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear licencia'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Cambiar camara',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No se pudo iniciar la camara.\n\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.72),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: const Text(
                'Apunta al QR de la licencia. Se llenaran los campos reconocibles.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget trailing;

  const _SectionTitle({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        trailing,
      ],
    );
  }
}

class _DropdownMenuText extends StatelessWidget {
  final String text;

  const _DropdownMenuText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text, softWrap: true),
    );
  }
}

class _DropdownSelectedText extends StatelessWidget {
  final String text;

  const _DropdownSelectedText(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  final ConduceLegalidadVehiculo vehiculo;
  final VoidCallback onRemove;

  const _VehicleTile({required this.vehiculo, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final title = [
      vehiculo.marca,
      vehiculo.linea,
      vehiculo.modelo,
    ].whereType<String>().where((v) => v.trim().isNotEmpty).join(' ');

    return _CaptureTile(
      icon: Icons.directions_car,
      title: title.trim().isEmpty ? 'Vehiculo' : title,
      subtitle: [
        vehiculo.placas,
        vehiculo.serie,
        vehiculo.grua == null ? null : 'Grua: ${vehiculo.grua}',
        vehiculo.corralon == null ? null : 'Corralon: ${vehiculo.corralon}',
        vehiculo.infraccion?.display,
      ].whereType<String>().where((v) => v.trim().isNotEmpty).join(' | '),
      onRemove: onRemove,
    );
  }
}

class _ExistingFotosPanel extends StatelessWidget {
  final List<ConduceLegalidadFoto> fotos;

  const _ExistingFotosPanel({required this.fotos});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: fotos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final url = fotos[index].previewUrl ?? '';
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: Colors.grey.shade100,
            child: SafeNetworkImage(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Icon(Icons.broken_image_outlined));
              },
            ),
          ),
        );
      },
    );
  }
}

class _FotosPickerPanel extends StatelessWidget {
  final List<File> fotos;
  final bool saving;
  final String emptyText;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final ValueChanged<int> onRemove;

  const _FotosPickerPanel({
    required this.fotos,
    required this.saving,
    required this.emptyText,
    required this.onGallery,
    required this.onCamera,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fotos.isEmpty)
          Container(
            height: 138,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Text(
                emptyText,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: fotos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final foto = fotos[index];
              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(foto, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: InkWell(
                      onTap: saving ? null : () => onRemove(index),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .62),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: saving ? null : onGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Galeria'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: saving ? null : onCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camara'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  final ConduceLegalidadPersona persona;
  final VoidCallback onRemove;

  const _PersonTile({required this.persona, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return _CaptureTile(
      icon: Icons.badge_outlined,
      title: persona.nombre?.trim().isNotEmpty == true
          ? persona.nombre!
          : 'Persona',
      subtitle: persona.numeroLicencia ?? persona.tipoLicencia ?? '',
      onRemove: onRemove,
    );
  }
}

class _CaptureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRemove;

  const _CaptureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: subtitle.trim().isEmpty ? null : Text(subtitle),
        trailing: IconButton(
          tooltip: 'Quitar',
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;

  const _EmptyLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(text, style: TextStyle(color: Colors.grey.shade700)),
    );
  }
}

class _AttentionPanel extends StatelessWidget {
  final String text;

  const _AttentionPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFF92400E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningPanel extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _WarningPanel({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFF92400E)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          IconButton(
            tooltip: 'Reintentar',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _ModalHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: onClose,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

String? _empty(String? value) {
  final text = (value ?? '').trim();
  return text.isEmpty ? null : text;
}

String _date(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
