import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/vehiculos/colores_vehiculo.dart';
import '../../core/vehiculos/estados_republica.dart';
import '../../core/vehiculos/vehiculo_taxonomia.dart';
import '../../services/grua_corralon_service.dart';
import '../../services/vehiculo_form_service.dart';
import '../../widgets/marca_vehiculo_dropdown.dart';

const _navy = Color(0xff0b3558);
const _teal = Color(0xff087f8c);

class GruaExpedienteScreen extends StatefulWidget {
  final Map<String, dynamic>? item;

  const GruaExpedienteScreen({super.key, this.item});

  @override
  State<GruaExpedienteScreen> createState() => _GruaExpedienteScreenState();
}

class _GruaExpedienteScreenState extends State<GruaExpedienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {};
  String _modalidad = 'ARRASTRE';
  String? _tipoGeneral;
  bool? _maniobras;
  final Map<String, bool> _inventario = {
    'llaves': false,
    'tarjeta_circulacion': false,
    'placas': false,
    'estereo': false,
    'bateria': false,
    'llanta_refaccion': false,
    'herramienta': false,
    'danos_visibles': false,
  };
  XFile? _memoria;
  bool _saving = false;

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item ?? const <String, dynamic>{};
    final service = item['servicio'] is Map
        ? Map<String, dynamic>.from(item['servicio'] as Map)
        : const <String, dynamic>{};
    String v(String key, [Map<String, dynamic>? source]) =>
        (source ?? item)[key]?.toString() ?? '';
    for (final entry in <String, String>{
      'marca': v('marca'),
      'linea': v('linea'),
      'modelo': v('modelo'),
      'tipo': v('tipo'),
      'color': v('color'),
      'placas': v('placas'),
      'estado_placas': v('estado_placas'),
      'serie': v('serie'),
      'tipo_servicio': v('tipo_servicio'),
      'tarjeta_circulacion_nombre': v('tarjeta_circulacion_nombre'),
      'numero_inventario_grua': v('numero_inventario_grua'),
      'corralon': v('corralon'),
      'folio_sierse': v('folio_sierse', service),
      'fecha_solicitud': _dateValue(
        service['fecha_solicitud'] ?? item['fecha_servicio'],
      ),
      'fecha_arribo': _dateValue(service['fecha_arribo']),
      'fecha_inicio': _dateValue(service['fecha_inicio']),
      'fecha_fin': _dateValue(service['fecha_fin']),
      'lugar_origen': v('lugar_origen', service),
      'lugar_destino': v('lugar_destino', service),
      'autoridad_solicitante': v('autoridad_solicitante', service),
      'agente_solicitante': v('agente_solicitante', service),
      'persona_solicitante': v('persona_solicitante', service),
      'operador_nombre': v('operador_nombre', service),
      'unidad_grua': v('unidad_grua', service),
      'kilometros_recorridos': v('kilometros_recorridos', service),
      'importe_total': v('importe_total', service),
      'forma_pago': v('forma_pago', service),
      'maniobras_descripcion': v('maniobras_descripcion', service),
      'observaciones_grua': v('observaciones_grua', service),
    }.entries) {
      _c[entry.key] = TextEditingController(text: entry.value);
    }
    _modalidad = service['modalidad_servicio']?.toString().isNotEmpty == true
        ? service['modalidad_servicio'].toString()
        : 'ARRASTRE';
    _tipoGeneral = service['tipo_general_vehiculo']?.toString();
    _tipoGeneral ??= _inferVehicleType(_c['tipo']!.text);
    _maniobras = service['realizo_maniobras'] as bool?;
    if (service['inventario_recepcion'] is Map) {
      final saved = Map<String, dynamic>.from(
        service['inventario_recepcion'] as Map,
      );
      for (final key in _inventario.keys) {
        _inventario[key] = saved[key] == true || saved[key].toString() == '1';
      }
    }
  }

  static String? _inferVehicleType(String body) {
    for (final entry in VehiculoTaxonomia.carrocerias.entries) {
      if (entry.value.any(
        (value) => value.toLowerCase() == body.toLowerCase(),
      )) {
        return entry.key;
      }
    }
    return null;
  }

  static String _dateValue(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return '';
    final value = DateTime.tryParse(raw.toString());
    if (value == null) return raw.toString();
    return value.toLocal().toIso8601String().substring(0, 16);
  }

  @override
  void dispose() {
    for (final controller in _c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMemory() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    if (file.size > 20 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La memoria no puede exceder 20 MB.')),
      );
      return;
    }
    setState(() => _memoria = XFile.fromData(file.bytes!, name: file.name));
  }

  Future<void> _pickDate(String key) async {
    final now = DateTime.now();
    final parsed = DateTime.tryParse(_c[key]!.text) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(parsed),
    );
    if (time == null) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    _c[key]!.text = value.toIso8601String().substring(0, 16);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_c['placas']!.text.trim().isEmpty) &&
        (_c['serie']!.text.trim().isEmpty)) {
      _message('Captura por lo menos placas o NIV/serie.');
      return;
    }
    setState(() => _saving = true);
    try {
      final fields = <String, String>{
        for (final entry in _c.entries) entry.key: entry.value.text.trim(),
        'modalidad_servicio': _modalidad,
        if (_tipoGeneral != null) 'tipo_general_vehiculo': _tipoGeneral!,
        if (_maniobras != null) 'realizo_maniobras': _maniobras! ? '1' : '0',
        for (final entry in _inventario.entries)
          'inventario_recepcion[${entry.key}]': entry.value ? '1' : '0',
      };
      if (_editing) {
        await GruaCorralonService.updateRecord(
          vehiculoId: int.parse(widget.item!['id'].toString()),
          fields: fields,
          memoriaDescriptiva: _memoria,
        );
      } else {
        await GruaCorralonService.createService(
          fields: fields,
          memoriaDescriptiva: _memoria,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final existingMemory = widget.item?['servicio'] is Map
        ? (widget.item!['servicio'] as Map)['memoria']
        : null;
    return Scaffold(
      backgroundColor: const Color(0xffeef3f7),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(
          _editing ? 'Completar expediente SIERSE' : 'Nuevo servicio SIERSE',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _section('Vehículo', Icons.directions_car, [
              DropdownButtonFormField<String>(
                value: _tipoGeneral,
                decoration: const InputDecoration(
                  labelText: 'Tipo de vehículo *',
                  border: OutlineInputBorder(),
                ),
                items: VehiculoTaxonomia.tiposGenerales
                    .map(
                      (item) => DropdownMenuItem(
                        value: item['value'],
                        child: Text(item['label'] ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _tipoGeneral = value;
                  _c['tipo']!.clear();
                }),
                validator: (value) =>
                    value == null ? 'Campo obligatorio' : null,
              ),
              DropdownButtonFormField<String>(
                value:
                    VehiculoTaxonomia.carroceriasDeTipoGeneral(
                      _tipoGeneral,
                    ).contains(_c['tipo']!.text)
                    ? _c['tipo']!.text
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Carrocería *',
                  border: OutlineInputBorder(),
                ),
                items: VehiculoTaxonomia.carroceriasDeTipoGeneral(_tipoGeneral)
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _c['tipo']!.text = value ?? ''),
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Campo obligatorio' : null,
              ),
              MarcaVehiculoDropdown(
                controller: _c['marca']!,
                tipoGeneral: _tipoGeneral,
                carroceria: _c['tipo']!.text,
                decoration: const InputDecoration(
                  labelText: 'Marca *',
                  border: OutlineInputBorder(),
                ),
              ),
              _field('linea', 'Línea', required: true),
              _field('modelo', 'Modelo / año'),
              DropdownButtonFormField<String>(
                value:
                    ColoresVehiculo.opcionesConActual(
                      _c['color']!.text,
                    ).contains(_c['color']!.text)
                    ? _c['color']!.text
                    : ColoresVehiculo.valueFromAny(_c['color']!.text),
                decoration: const InputDecoration(
                  labelText: 'Color *',
                  border: OutlineInputBorder(),
                ),
                items: ColoresVehiculo.opcionesConActual(_c['color']!.text)
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _c['color']!.text = value ?? ''),
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Campo obligatorio' : null,
              ),
              _field('placas', 'Placas'),
              DropdownButtonFormField<String>(
                value:
                    EstadosRepublica.estados.any(
                      (item) => item['value'] == _c['estado_placas']!.text,
                    )
                    ? _c['estado_placas']!.text
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Estado de placas',
                  border: OutlineInputBorder(),
                ),
                items: EstadosRepublica.estados
                    .map(
                      (item) => DropdownMenuItem(
                        value: item['value'],
                        child: Text(item['label'] ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _c['estado_placas']!.text = value ?? ''),
              ),
              _field('serie', 'NIV / serie'),
              DropdownButtonFormField<String>(
                value: VehiculoFormService.tipoServicioPlacaValue(
                  _c['tipo_servicio']!.text,
                ),
                decoration: const InputDecoration(
                  labelText: 'Tipo de servicio de placa',
                  border: OutlineInputBorder(),
                ),
                items: VehiculoFormService.tiposServicioPlaca
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _c['tipo_servicio']!.text = value ?? ''),
              ),
              _field(
                'tarjeta_circulacion_nombre',
                'Titular de tarjeta de circulación',
              ),
              _field('numero_inventario_grua', 'Número de inventario'),
              _field('corralon', 'Depósito / corralón'),
            ]),
            _section('Servicio auxiliar', Icons.local_shipping_outlined, [
              DropdownButtonFormField<String>(
                value: _modalidad,
                decoration: const InputDecoration(
                  labelText: 'Modalidad *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'GRUA', child: Text('Grúa')),
                  DropdownMenuItem(value: 'ARRASTRE', child: Text('Arrastre')),
                  DropdownMenuItem(
                    value: 'ARRASTRE_SALVAMENTO',
                    child: Text('Arrastre / salvamento'),
                  ),
                  DropdownMenuItem(value: 'REMOLQUE', child: Text('Remolque')),
                  DropdownMenuItem(value: 'DEPOSITO', child: Text('Depósito')),
                ],
                onChanged: (value) => setState(() => _modalidad = value!),
              ),
              _field('folio_sierse', 'Folio SIERSE'),
              _date(
                'fecha_solicitud',
                'Fecha y hora de solicitud',
                required: true,
              ),
              _date('fecha_arribo', 'Fecha y hora de arribo'),
              _date('fecha_inicio', 'Inicio de maniobras'),
              _date('fecha_fin', 'Fin del servicio'),
              _field('lugar_origen', 'Lugar de origen', required: true),
              _field('lugar_destino', 'Destino / depósito'),
              _field('autoridad_solicitante', 'Autoridad solicitante'),
              _field('agente_solicitante', 'Agente que solicita'),
              _field('persona_solicitante', 'Persona usuaria / interesada'),
              _field('operador_nombre', 'Operador de la grúa', required: true),
              _field(
                'unidad_grua',
                'Unidad / número económico',
                required: true,
              ),
              _field(
                'kilometros_recorridos',
                'Kilómetros recorridos',
                number: true,
              ),
              _field('importe_total', 'Importe total', number: true),
              _field('forma_pago', 'Forma de pago'),
            ]),
            _section('Maniobras y condición', Icons.construction, [
              SegmentedButton<bool>(
                emptySelectionAllowed: true,
                segments: const [
                  ButtonSegment(value: true, label: Text('Sí hubo maniobras')),
                  ButtonSegment(value: false, label: Text('No hubo maniobras')),
                ],
                selected: _maniobras == null ? {} : {_maniobras!},
                onSelectionChanged: (value) =>
                    setState(() => _maniobras = value.first),
              ),
              _field(
                'maniobras_descripcion',
                'Descripción detallada de maniobras',
                lines: 4,
              ),
              _field(
                'observaciones_grua',
                'Condición, incidencias y observaciones',
                lines: 4,
              ),
            ]),
            _section(
              'Inventario rápido de recepción',
              Icons.inventory_2_outlined,
              [
                const Text(
                  'Marca lo que recibió físicamente la grúa. Los daños visibles deben describirse en observaciones.',
                ),
                ...<String, String>{
                  'llaves': 'Llaves',
                  'tarjeta_circulacion': 'Tarjeta de circulación',
                  'placas': 'Placas colocadas',
                  'estereo': 'Estéreo',
                  'bateria': 'Batería',
                  'llanta_refaccion': 'Llanta de refacción',
                  'herramienta': 'Herramienta / gato',
                  'danos_visibles': 'Daños visibles al recibir',
                }.entries.map(
                  (entry) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _inventario[entry.key] ?? false,
                    title: Text(entry.value),
                    onChanged: (value) =>
                        setState(() => _inventario[entry.key] = value ?? false),
                  ),
                ),
              ],
            ),
            _section('Memoria descriptiva oficial', Icons.description_outlined, [
              Text(
                existingMemory is Map
                    ? 'Archivo vigente: ${existingMemory['nombre'] ?? 'memoria descriptiva'}'
                    : 'Adjunta el archivo generado o validado en SIERSE. No se sustituye por un resumen de la app.',
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickMemory,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _memoria?.name ??
                      (existingMemory is Map
                          ? 'Reemplazar memoria'
                          : 'Subir memoria descriptiva'),
                ),
              ),
            ]),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _teal,
                padding: const EdgeInsets.all(16),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _saving
                    ? 'Guardando…'
                    : (_editing ? 'Guardar expediente' : 'Registrar servicio'),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: _teal),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children.expand((child) => [child, const SizedBox(height: 12)]),
        ],
      ),
    ),
  );

  Widget _field(
    String key,
    String label, {
    bool required = false,
    bool number = false,
    int lines = 1,
  }) => TextFormField(
    controller: _c[key],
    maxLines: lines,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : null,
    decoration: InputDecoration(
      labelText: required ? '$label *' : label,
      border: const OutlineInputBorder(),
    ),
    validator: required
        ? (value) => (value ?? '').trim().isEmpty ? 'Campo obligatorio' : null
        : null,
  );

  Widget _date(String key, String label, {bool required = false}) =>
      TextFormField(
        controller: _c[key],
        readOnly: true,
        onTap: () => _pickDate(key),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          suffixIcon: const Icon(Icons.event),
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (value) =>
                  (value ?? '').trim().isEmpty ? 'Campo obligatorio' : null
            : null,
      );
}
