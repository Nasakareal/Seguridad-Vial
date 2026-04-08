import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/guardianes_camino/guardianes_camino_dispositivos_catalogos.dart';
import '../../services/guardianes_camino_dispositivo_form_service.dart';

enum _DynamicFieldKind { integer, decimal, text, select }

class _DynamicFieldOption {
  final String value;
  final String label;

  const _DynamicFieldOption({required this.value, required this.label});
}

class _DynamicFieldSpec {
  final String label;
  final _DynamicFieldKind kind;
  final String defaultValue;
  final String? hint;
  final int? minLines;
  final int? maxLines;
  final List<_DynamicFieldOption> options;

  const _DynamicFieldSpec({
    required this.label,
    required this.kind,
    this.defaultValue = '',
    this.hint,
    this.minLines,
    this.maxLines,
    this.options = const <_DynamicFieldOption>[],
  });
}

const Map<String, _DynamicFieldSpec> _dynamicFieldSpecs =
    <String, _DynamicFieldSpec>{
      'vehiculos_inspeccionados': _DynamicFieldSpec(
        label: 'Vehículos inspeccionados',
        kind: _DynamicFieldKind.integer,
        defaultValue: '0',
      ),
      'personas_inspeccionadas': _DynamicFieldSpec(
        label: 'Personas inspeccionadas',
        kind: _DynamicFieldKind.integer,
        defaultValue: '0',
      ),
      'vehiculos_impactados': _DynamicFieldSpec(
        label: 'Vehículos impactados',
        kind: _DynamicFieldKind.integer,
        defaultValue: '0',
      ),
      'personas_impactadas': _DynamicFieldSpec(
        label: 'Personas impactadas',
        kind: _DynamicFieldKind.integer,
        defaultValue: '0',
      ),
      'estado_fuerza_participante': _DynamicFieldSpec(
        label: 'Estado de fuerza participante',
        kind: _DynamicFieldKind.integer,
        defaultValue: '0',
      ),
      'kilometros_recorridos': _DynamicFieldSpec(
        label: 'Kilómetros recorridos',
        kind: _DynamicFieldKind.decimal,
        defaultValue: '0',
      ),
      'crps_participantes': _DynamicFieldSpec(
        label: 'CRPS participantes',
        kind: _DynamicFieldKind.text,
        hint: 'Ejemplo: 25-1234 y 22-5678',
      ),
      'prox_empresas': _DynamicFieldSpec(
        label: 'Empresas',
        kind: _DynamicFieldKind.integer,
        defaultValue: '0',
      ),
      'prox_tiendas_conveniencia': _DynamicFieldSpec(
        label: 'Tiendas de conveniencia',
        kind: _DynamicFieldKind.integer,
        defaultValue: '0',
      ),
      'prox_escuelas': _DynamicFieldSpec(
        label: 'Escuelas',
        kind: _DynamicFieldKind.integer,
        defaultValue: '0',
      ),
      'prox_hospitales': _DynamicFieldSpec(
        label: 'Hospitales',
        kind: _DynamicFieldKind.integer,
        defaultValue: '0',
      ),
      'tipo_acompanamiento': _DynamicFieldSpec(
        label: 'Tipo de acompañamiento',
        kind: _DynamicFieldKind.select,
        hint: 'Selecciona una opción',
        options: <_DynamicFieldOption>[
          _DynamicFieldOption(value: 'ESCOLTA', label: 'Escolta'),
          _DynamicFieldOption(value: 'CARAVANA', label: 'Caravana'),
          _DynamicFieldOption(value: 'EMERGENCIA', label: 'Emergencia'),
          _DynamicFieldOption(value: 'OTRO', label: 'Otro'),
        ],
      ),
      'tipo_abanderamiento': _DynamicFieldSpec(
        label: 'Tipo de abanderamiento',
        kind: _DynamicFieldKind.select,
        hint: 'Selecciona una opción',
        options: <_DynamicFieldOption>[
          _DynamicFieldOption(value: 'SINIESTROS', label: 'Siniestros'),
          _DynamicFieldOption(value: 'EVENTOS', label: 'Eventos'),
          _DynamicFieldOption(value: 'OTRO', label: 'Otro'),
        ],
      ),
      'tipo_auxilio_vial': _DynamicFieldSpec(
        label: 'Tipo de auxilio vial',
        kind: _DynamicFieldKind.select,
        hint: 'Selecciona una opción',
        options: <_DynamicFieldOption>[
          _DynamicFieldOption(value: 'FALLA MECANICA', label: 'Falla mecánica'),
          _DynamicFieldOption(value: 'PEATON', label: 'Peatón'),
          _DynamicFieldOption(value: 'OTRO', label: 'Otro'),
        ],
      ),
      'folio_atendido': _DynamicFieldSpec(
        label: 'N° folio atendido',
        kind: _DynamicFieldKind.text,
      ),
      'motivo_folio': _DynamicFieldSpec(
        label: 'Motivo del folio',
        kind: _DynamicFieldKind.text,
        minLines: 3,
        maxLines: 4,
      ),
    };

class DispositivoFormScreen extends StatefulWidget {
  final GuardianesCaminoCatalogoLocal catalogo;

  const DispositivoFormScreen({super.key, required this.catalogo});

  @override
  State<DispositivoFormScreen> createState() => _DispositivoFormScreenState();
}

class _DispositivoFormScreenState extends State<DispositivoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  bool _saving = false;

  final _tipoReporteCtrl = TextEditingController();
  final _asuntoCtrl = TextEditingController();
  final _lugarCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _carreteraCtrl = TextEditingController();
  final _tramoCtrl = TextEditingController();
  final _kilometroCtrl = TextEditingController();
  final _narrativaCtrl = TextEditingController();
  final _accionesCtrl = TextEditingController();
  final _fraseCtrl = TextEditingController();
  final _nombreConductorCtrl = TextEditingController();
  final _ocupacionCtrl = TextEditingController();
  final _acompanantesCtrl = TextEditingController(text: '0');
  final _vehiculoDescripcionCtrl = TextEditingController();
  final _placasCtrl = TextEditingController();
  final _procedenciaCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  final _motivoApoyoCtrl = TextEditingController();
  final _cargoResponsableCtrl = TextEditingController();
  final _nombreResponsableCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  late final Map<String, TextEditingController> _dynamicControllers =
      <String, TextEditingController>{
        for (final field in widget.catalogo.campos)
          field: TextEditingController(text: _specForField(field).defaultValue),
      };

  DateTime _fecha = DateTime.now();
  TimeOfDay _hora = TimeOfDay.now();
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFin;
  bool _requiereEvidencia = false;

  double? _lat;
  double? _lng;
  String? _geoStatus;
  bool _resolvingLocation = false;
  List<File> _fotos = <File>[];

  bool get _showApoyoUsuario {
    final nombre = widget.catalogo.nombre.toUpperCase();
    return nombre.contains('ACOMPAÑAMIENTOS') ||
        nombre.contains('ABANDERAMIENTOS') ||
        nombre.contains('AUXILIOS VIALES') ||
        nombre.contains('CABALLEROS DEL CAMINO');
  }

  @override
  void dispose() {
    _tipoReporteCtrl.dispose();
    _asuntoCtrl.dispose();
    _lugarCtrl.dispose();
    _descripcionCtrl.dispose();
    _carreteraCtrl.dispose();
    _tramoCtrl.dispose();
    _kilometroCtrl.dispose();
    _narrativaCtrl.dispose();
    _accionesCtrl.dispose();
    _fraseCtrl.dispose();
    _nombreConductorCtrl.dispose();
    _ocupacionCtrl.dispose();
    _acompanantesCtrl.dispose();
    _vehiculoDescripcionCtrl.dispose();
    _placasCtrl.dispose();
    _procedenciaCtrl.dispose();
    _destinoCtrl.dispose();
    _motivoApoyoCtrl.dispose();
    _cargoResponsableCtrl.dispose();
    _nombreResponsableCtrl.dispose();
    _observacionesCtrl.dispose();
    for (final controller in _dynamicControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _fmtHm(TimeOfDay? t) {
    if (t == null) return 'Seleccionar';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  _DynamicFieldSpec _specForField(String field) {
    return _dynamicFieldSpecs[field] ??
        _DynamicFieldSpec(label: field, kind: _DynamicFieldKind.text);
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildDynamicField(String field) {
    final spec = _specForField(field);
    final controller = _dynamicControllers[field]!;

    if (spec.kind == _DynamicFieldKind.select) {
      final currentValue = controller.text.trim();

      return DropdownButtonFormField<String>(
        value: currentValue.isEmpty ? null : currentValue,
        items: [
          DropdownMenuItem<String>(
            value: '',
            child: Text(spec.hint ?? 'Selecciona una opción'),
          ),
          ...spec.options.map(
            (option) => DropdownMenuItem<String>(
              value: option.value,
              child: Text(option.label),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() {
            controller.text = value?.trim() ?? '';
          });
        },
        decoration: _dec(spec.label),
      );
    }

    final keyboardType = switch (spec.kind) {
      _DynamicFieldKind.decimal => const TextInputType.numberWithOptions(
        decimal: true,
      ),
      _DynamicFieldKind.integer => TextInputType.number,
      _DynamicFieldKind.text => TextInputType.text,
      _DynamicFieldKind.select => TextInputType.text,
    };

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: spec.minLines,
      maxLines: spec.maxLines,
      decoration: _dec(spec.label, hint: spec.hint),
    );
  }

  Widget _card({
    required String title,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Future<void> _pickFecha() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null) return;
    setState(() => _fecha = picked);
  }

  Future<void> _pickHora({
    required TimeOfDay initial,
    required void Function(TimeOfDay value) onSelected,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => onSelected(picked));
  }

  Future<void> _usarUbicacionActual() async {
    if (_resolvingLocation) return;
    setState(() {
      _resolvingLocation = true;
      _geoStatus = 'Buscando ubicación...';
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('El GPS está apagado.');

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('No se otorgó permiso de ubicación.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _geoStatus =
            'OK: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _geoStatus = 'No se pudo obtener la ubicación: $e');
    } finally {
      if (mounted) setState(() => _resolvingLocation = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _fotos = <File>[..._fotos, File(picked.path)]);
  }

  Future<void> _onRegistrarTap() async {
    if (!_formKey.currentState!.validate()) return;

    if (_saving) return;

    final payload = GuardianesCaminoDispositivoFormPayload(
      catalogo: widget.catalogo,
      fecha: _fecha,
      hora: _hora,
      horaInicio: _horaInicio,
      horaFin: _horaFin,
      tipoReporte: _tipoReporteCtrl.text,
      asunto: _asuntoCtrl.text,
      lugar: _lugarCtrl.text,
      descripcion: _descripcionCtrl.text,
      carretera: _carreteraCtrl.text,
      tramo: _tramoCtrl.text,
      kilometro: _kilometroCtrl.text,
      narrativa: _narrativaCtrl.text,
      accionesRealizadas: _accionesCtrl.text,
      fraseInstitucional: _fraseCtrl.text,
      nombreConductor: _nombreConductorCtrl.text,
      ocupacionConductor: _ocupacionCtrl.text,
      acompanantesCantidad: _acompanantesCtrl.text,
      vehiculoDescripcion: _vehiculoDescripcionCtrl.text,
      placasApoyado: _placasCtrl.text,
      procedencia: _procedenciaCtrl.text,
      destino: _destinoCtrl.text,
      motivoApoyo: _motivoApoyoCtrl.text,
      cargoResponsable: _cargoResponsableCtrl.text,
      nombreResponsable: _nombreResponsableCtrl.text,
      observaciones: _observacionesCtrl.text,
      requiereEvidencia: _requiereEvidencia,
      lat: _lat,
      lng: _lng,
      dynamicFields: <String, String>{
        for (final entry in _dynamicControllers.entries)
          entry.key: entry.value.text,
      },
      fotos: _fotos,
    );

    final validation =
        await GuardianesCaminoDispositivoFormService.validateBeforeSubmit(
          payload: payload,
        );
    if (validation != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validation)));
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await GuardianesCaminoDispositivoFormService.create(
        payload: payload,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Captura de Dispositivo'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withValues(alpha: .18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Operativo',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Guardianes del Camino',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.catalogo.titulo,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: 'Datos base',
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: widget.catalogo.nombre,
                      items: [
                        DropdownMenuItem<String>(
                          value: widget.catalogo.nombre,
                          child: Text(widget.catalogo.titulo),
                        ),
                      ],
                      onChanged: null,
                      decoration: _dec('Dispositivo'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickFecha,
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: _dec('Fecha'),
                              child: Text(_fmtYmd(_fecha)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickHora(
                              initial: _hora,
                              onSelected: (value) => _hora = value,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: _dec('Hora'),
                              child: Text(_fmtHm(_hora)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickHora(
                              initial: _horaInicio ?? _hora,
                              onSelected: (value) => _horaInicio = value,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: _dec('Hora inicio'),
                              child: Text(_fmtHm(_horaInicio)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickHora(
                              initial: _horaFin ?? _hora,
                              onSelected: (value) => _horaFin = value,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: _dec('Hora fin'),
                              child: Text(_fmtHm(_horaFin)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tipoReporteCtrl,
                      decoration: _dec('Tipo de reporte'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _asuntoCtrl,
                      decoration: _dec('Asunto'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lugarCtrl,
                      decoration: _dec('Lugar'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descripcionCtrl,
                      minLines: 3,
                      maxLines: 4,
                      decoration: _dec('Descripción breve'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: 'Campos dinámicos',
                subtitle: 'Sección variable según el dispositivo seleccionado.',
                child: Column(
                  children: widget.catalogo.campos.map((field) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildDynamicField(field),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: 'Georreferencia y tramo',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _carreteraCtrl,
                      decoration: _dec('Carretera'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tramoCtrl,
                      decoration: _dec('Tramo'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _kilometroCtrl,
                      decoration: _dec('Kilómetro', hint: 'Ejemplo: 217+500'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _resolvingLocation
                                ? null
                                : _usarUbicacionActual,
                            icon: const Icon(Icons.location_searching),
                            label: const Text('Usar mi ubicación'),
                          ),
                        ),
                        if (_lat != null && _lng != null) ...[
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _lat = null;
                                _lng = null;
                                _geoStatus = 'Sin coordenadas';
                              });
                            },
                            child: const Text('Quitar'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_geoStatus ?? 'Sin coordenadas'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: 'Narrativa',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _narrativaCtrl,
                      minLines: 4,
                      maxLines: 6,
                      decoration: _dec('Narrativa'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _accionesCtrl,
                      minLines: 3,
                      maxLines: 5,
                      decoration: _dec('Acciones realizadas'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fraseCtrl,
                      minLines: 2,
                      maxLines: 3,
                      decoration: _dec('Frase institucional'),
                    ),
                  ],
                ),
              ),
              if (_showApoyoUsuario) ...[
                const SizedBox(height: 12),
                _card(
                  title: 'Datos de apoyo a usuario',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nombreConductorCtrl,
                        decoration: _dec('Nombre del conductor o usuario'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ocupacionCtrl,
                        decoration: _dec('Ocupación'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _acompanantesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _dec('Acompañantes'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _vehiculoDescripcionCtrl,
                        decoration: _dec('Descripción del vehículo'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _placasCtrl,
                        decoration: _dec('Placas'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _procedenciaCtrl,
                        decoration: _dec('Procedencia'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _destinoCtrl,
                        decoration: _dec('Destino'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _motivoApoyoCtrl,
                        minLines: 3,
                        maxLines: 4,
                        decoration: _dec('Motivo del apoyo'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _card(
                title: 'Responsable y observaciones',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _cargoResponsableCtrl,
                      decoration: _dec('Cargo responsable'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nombreResponsableCtrl,
                      decoration: _dec('Nombre responsable'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Requiere evidencia'),
                      value: _requiereEvidencia,
                      onChanged: (value) =>
                          setState(() => _requiereEvidencia = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _observacionesCtrl,
                      minLines: 3,
                      maxLines: 4,
                      decoration: _dec('Observaciones'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                title: 'Fotos',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickPhoto(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galería'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickPhoto(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Cámara'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_fotos.isEmpty)
                      const Text('Todavía no agregas fotos.')
                    else
                      SizedBox(
                        height: 94,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _fotos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final foto = _fotos[index];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    foto,
                                    width: 94,
                                    height: 94,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _fotos = <File>[..._fotos]
                                          ..removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _saving ? null : _onRegistrarTap,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Guardando...' : 'Registrar'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
