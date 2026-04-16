import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/puestas_disposicion_service.dart';

class PuestaDisposicionCreateScreen extends StatefulWidget {
  const PuestaDisposicionCreateScreen({super.key});

  @override
  State<PuestaDisposicionCreateScreen> createState() =>
      _PuestaDisposicionCreateScreenState();
}

class _PuestaDisposicionCreateScreenState
    extends State<PuestaDisposicionCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = PuestasDisposicionService();
  final _picker = ImagePicker();

  final _motivo = TextEditingController();
  final _lugar = TextEditingController();
  final _policia = TextEditingController();
  final _mp = TextEditingController();
  final _autoridad = TextEditingController();
  final _carpeta = TextEditingController();
  final _oficio = TextEditingController();
  final _narrativa = TextEditingController();
  final _observaciones = TextEditingController();

  bool _saving = false;
  bool _loadingUnidades = true;
  int? _unidadId;
  DateTime _fecha = DateTime.now();
  TimeOfDay? _hora;
  String _tipoPuesta = 'PERSONA';
  List<PuestaUnidad> _unidades = <PuestaUnidad>[];

  File? _pdf;
  String? _pdfName;

  final _personas = <_PersonaFields>[];
  final _vehiculos = <_VehiculoFields>[];
  final _objetos = <_ObjetoFields>[];

  @override
  void initState() {
    super.initState();
    _loadUnidades();
  }

  @override
  void dispose() {
    for (final item in _personas) {
      item.dispose();
    }
    for (final item in _vehiculos) {
      item.dispose();
    }
    for (final item in _objetos) {
      item.dispose();
    }
    _motivo.dispose();
    _lugar.dispose();
    _policia.dispose();
    _mp.dispose();
    _autoridad.dispose();
    _carpeta.dispose();
    _oficio.dispose();
    _narrativa.dispose();
    _observaciones.dispose();
    super.dispose();
  }

  Future<void> _loadUnidades() async {
    try {
      final unidades = await _service.unidadesParaCrear();
      if (!mounted) return;
      setState(() {
        _unidades = unidades;
        _unidadId = unidades.isNotEmpty ? unidades.first.id : null;
        _loadingUnidades = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingUnidades = false);
    }
  }

  String _ymd(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  String _dmy(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Campo requerido' : null;
  }

  void _put(Map<String, String> fields, String key, String value) {
    final text = value.trim();
    if (text.isNotEmpty) fields[key] = text;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1),
    );

    if (picked != null && mounted) setState(() => _fecha = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
    );

    if (picked != null && mounted) setState(() => _hora = picked);
  }

  Future<void> _pickPdf() async {
    try {
      final selected = await _picker.pickMedia();
      if (selected == null) return;

      if (!selected.path.toLowerCase().endsWith('.pdf')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona un archivo PDF.')),
        );
        return;
      }

      setState(() {
        _pdf = File(selected.path);
        _pdfName = selected.name;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo seleccionar el PDF.')),
      );
    }
  }

  Future<void> _save() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      if (kDebugMode) {
        debugPrint('Puesta a disposicion: formulario invalido');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los campos marcados.')),
      );
      return;
    }

    if (_unidadId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una unidad.')));
      return;
    }

    final fields = <String, String>{
      'unidad_id': _unidadId.toString(),
      'tipo_puesta': _tipoPuesta,
      'motivo': _motivo.text.trim(),
      'estatus': 'ACTIVA',
      'nombre_policia': _policia.text.trim(),
      'fecha_puesta': _ymd(_fecha),
    };

    if (_hora != null) {
      fields['hora_puesta'] =
          '${_hora!.hour.toString().padLeft(2, '0')}:${_hora!.minute.toString().padLeft(2, '0')}';
    }

    _put(fields, 'lugar_puesta', _lugar.text);
    _put(fields, 'nombre_mp', _mp.text);
    _put(fields, 'autoridad_receptora', _autoridad.text);
    _put(fields, 'carpeta_investigacion', _carpeta.text);
    _put(fields, 'oficio', _oficio.text);
    _put(fields, 'narrativa', _narrativa.text);
    _put(fields, 'observaciones', _observaciones.text);

    var index = 0;
    for (final item in _personas.where((item) => item.hasAny)) {
      item.write(fields, index++);
    }

    index = 0;
    for (final item in _vehiculos.where((item) => item.hasAny)) {
      item.write(fields, index++);
    }

    index = 0;
    for (final item in _objetos.where((item) => item.hasAny)) {
      item.write(fields, index++);
    }

    if (kDebugMode) {
      debugPrint(
        'Puesta a disposicion: enviando unidad=$_unidadId tipo=$_tipoPuesta personas=${_personas.where((item) => item.hasAny).length} vehiculos=${_vehiculos.where((item) => item.hasAny).length} objetos=${_objetos.where((item) => item.hasAny).length}',
      );
    }

    setState(() => _saving = true);

    try {
      await _service.store(fields: fields, archivoPuesta: _pdf);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Puesta registrada.')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo registrar: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Crear Puesta a Disposición'),
        backgroundColor: Colors.blue,
      ),
      body: _loadingUnidades
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Section(
                    title: 'Llene los Datos',
                    children: [
                      _readonly('Número de Puesta', 'Se asigna al registrar'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _tipoPuesta,
                        decoration: _decoration('Tipo de Puesta'),
                        items: const [
                          DropdownMenuItem(
                            value: 'PERSONA',
                            child: Text('PERSONA'),
                          ),
                          DropdownMenuItem(
                            value: 'VEHICULO',
                            child: Text('VEHICULO'),
                          ),
                          DropdownMenuItem(
                            value: 'OBJETO',
                            child: Text('OBJETO'),
                          ),
                          DropdownMenuItem(
                            value: 'MIXTA',
                            child: Text('MIXTA'),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(
                                () => _tipoPuesta = value ?? 'PERSONA',
                              ),
                      ),
                      const SizedBox(height: 12),
                      _field(_motivo, 'Motivo', validator: _required),
                      const SizedBox(height: 12),
                      _readonly('Estatus', 'ACTIVA'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Fecha y lugar',
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fecha de Puesta'),
                        subtitle: Text(_dmy(_fecha)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _saving ? null : _pickDate,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Hora de Puesta'),
                        subtitle: Text(
                          _hora == null ? 'Sin hora' : _hora!.format(context),
                        ),
                        trailing: const Icon(Icons.schedule),
                        onTap: _saving ? null : _pickTime,
                      ),
                      const SizedBox(height: 12),
                      _field(_lugar, 'Lugar de Puesta'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Datos de autoridad',
                    children: [
                      _field(
                        _policia,
                        'Nombre del Policía',
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      _field(_mp, 'Nombre del MP'),
                      const SizedBox(height: 12),
                      _field(_autoridad, 'Autoridad Receptora'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Área y expediente',
                    children: [
                      DropdownButtonFormField<int>(
                        value: _unidadId,
                        decoration: _decoration('Unidad / Área'),
                        items: [
                          for (final unidad in _unidades)
                            DropdownMenuItem(
                              value: unidad.id,
                              child: Text(unidad.nombre),
                            ),
                        ],
                        validator: (value) =>
                            value == null ? 'Campo requerido' : null,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _unidadId = value),
                      ),
                      const SizedBox(height: 12),
                      _field(_carpeta, 'Carpeta de Investigación'),
                      const SizedBox(height: 12),
                      _field(_oficio, 'Oficio'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Archivo PDF',
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _pdfName ?? 'Sin archivo',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_pdf == null)
                            OutlinedButton(
                              onPressed: _saving ? null : _pickPdf,
                              child: const Text('Elegir'),
                            )
                          else
                            IconButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                      _pdf = null;
                                      _pdfName = null;
                                    }),
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Narrativa',
                    children: [_field(_narrativa, 'Narrativa', maxLines: 4)],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Observaciones',
                    children: [
                      _field(_observaciones, 'Observaciones', maxLines: 3),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _dynamicSection(
                    title: 'Personas',
                    button: 'Agregar Persona',
                    onAdd: () =>
                        setState(() => _personas.add(_PersonaFields())),
                    children: [
                      for (var i = 0; i < _personas.length; i++)
                        _personaCard(_personas[i], i),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _dynamicSection(
                    title: 'Vehículos',
                    button: 'Agregar Vehículo',
                    onAdd: () =>
                        setState(() => _vehiculos.add(_VehiculoFields())),
                    children: [
                      for (var i = 0; i < _vehiculos.length; i++)
                        _vehiculoCard(_vehiculos[i], i),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _dynamicSection(
                    title: 'Objetos',
                    button: 'Agregar Objeto',
                    onAdd: () => setState(() => _objetos.add(_ObjetoFields())),
                    children: [
                      for (var i = 0; i < _objetos.length; i++)
                        _objetoCard(_objetos[i], i),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'Guardando' : 'Registrar'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  Widget _readonly(String label, String value) {
    return TextFormField(
      enabled: false,
      initialValue: value,
      decoration: _decoration(label),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    FormFieldValidator<String>? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _decoration(label),
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.characters,
    );
  }

  Widget _dynamicSection({
    required String title,
    required String button,
    required VoidCallback onAdd,
    required List<Widget> children,
  }) {
    return _Section(
      title: title,
      trailing: OutlinedButton.icon(
        onPressed: _saving ? null : onAdd,
        icon: const Icon(Icons.add),
        label: Text(button),
      ),
      children: children.isEmpty
          ? [
              Text(
                'Sin registros.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ]
          : children,
    );
  }

  Widget _personaCard(_PersonaFields item, int index) {
    return _DynamicBlock(
      title: 'Persona ${index + 1}',
      onRemove: () => setState(() => _personas.removeAt(index).dispose()),
      children: [
        _field(
          item.nombre,
          'Nombre Completo',
          validator: (_) => item.hasAny && item.nombre.text.trim().isEmpty
              ? 'Campo requerido'
              : null,
        ),
        const SizedBox(height: 10),
        _field(item.alias, 'Alias'),
        const SizedBox(height: 10),
        _field(item.edad, 'Edad', keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        _field(item.sexo, 'Sexo'),
        const SizedBox(height: 10),
        _field(item.fechaNacimiento, 'Fecha de Nacimiento (AAAA-MM-DD)'),
        const SizedBox(height: 10),
        _field(item.curp, 'CURP'),
        const SizedBox(height: 10),
        _field(item.rfc, 'RFC'),
        const SizedBox(height: 10),
        _field(item.calidad, 'Calidad'),
        const SizedBox(height: 10),
        _field(item.domicilio, 'Domicilio'),
        const SizedBox(height: 10),
        _field(item.delito, 'Delito o Motivo'),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: item.ordenAprehension,
          title: const Text('Orden de Aprehensión'),
          onChanged: (value) =>
              setState(() => item.ordenAprehension = value ?? false),
        ),
        _field(item.mandamiento, 'Mandamiento Judicial'),
        const SizedBox(height: 10),
        _field(item.observaciones, 'Observaciones'),
      ],
    );
  }

  Widget _vehiculoCard(_VehiculoFields item, int index) {
    return _DynamicBlock(
      title: 'Vehículo ${index + 1}',
      onRemove: () => setState(() => _vehiculos.removeAt(index).dispose()),
      children: [
        _field(item.tipo, 'Tipo'),
        const SizedBox(height: 10),
        _field(item.marca, 'Marca'),
        const SizedBox(height: 10),
        _field(item.submarca, 'Línea'),
        const SizedBox(height: 10),
        _field(item.modelo, 'Modelo'),
        const SizedBox(height: 10),
        _field(item.color, 'Color'),
        const SizedBox(height: 10),
        _field(item.placas, 'Placas'),
        const SizedBox(height: 10),
        _field(item.serie, 'Serie'),
        const SizedBox(height: 10),
        _field(item.calidad, 'Calidad'),
        const SizedBox(height: 10),
        _field(item.motivoRelacion, 'Motivo Relación'),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: item.conReporteRobo,
          title: const Text('Con Reporte de Robo'),
          onChanged: (value) =>
              setState(() => item.conReporteRobo = value ?? false),
        ),
        _field(item.numeroReporteRobo, 'Número Reporte Robo'),
        const SizedBox(height: 10),
        _field(item.observaciones, 'Observaciones'),
      ],
    );
  }

  Widget _objetoCard(_ObjetoFields item, int index) {
    return _DynamicBlock(
      title: 'Objeto ${index + 1}',
      onRemove: () => setState(() => _objetos.removeAt(index).dispose()),
      children: [
        _field(
          item.tipoObjeto,
          'Tipo de Objeto',
          validator: (_) =>
              item.hasAny &&
                  item.tipoObjeto.text.trim().isEmpty &&
                  item.descripcion.text.trim().isEmpty
              ? 'Captura tipo o descripción'
              : null,
        ),
        const SizedBox(height: 10),
        _field(
          item.descripcion,
          'Descripción',
          validator: (_) =>
              item.hasAny &&
                  item.tipoObjeto.text.trim().isEmpty &&
                  item.descripcion.text.trim().isEmpty
              ? 'Captura tipo o descripción'
              : null,
        ),
        const SizedBox(height: 10),
        _field(item.cantidad, 'Cantidad', keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        _field(item.unidadMedida, 'Unidad Medida'),
        const SizedBox(height: 10),
        _field(item.cadenaCustodia, 'Cadena de Custodia'),
        const SizedBox(height: 10),
        _field(item.observaciones, 'Observaciones'),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const _Section({required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DynamicBlock extends StatelessWidget {
  final String title;
  final VoidCallback onRemove;
  final List<Widget> children;

  const _DynamicBlock({
    required this.title,
    required this.onRemove,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Quitar'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _PersonaFields {
  final nombre = TextEditingController();
  final alias = TextEditingController();
  final edad = TextEditingController();
  final sexo = TextEditingController();
  final fechaNacimiento = TextEditingController();
  final curp = TextEditingController();
  final rfc = TextEditingController();
  final calidad = TextEditingController();
  final domicilio = TextEditingController();
  final delito = TextEditingController();
  final mandamiento = TextEditingController();
  final observaciones = TextEditingController();
  bool ordenAprehension = false;

  bool get hasAny => [
    nombre,
    alias,
    edad,
    sexo,
    fechaNacimiento,
    curp,
    rfc,
    calidad,
    domicilio,
    delito,
    mandamiento,
    observaciones,
  ].any((controller) => controller.text.trim().isNotEmpty);

  void write(Map<String, String> fields, int index) {
    void put(String key, TextEditingController controller) {
      final text = controller.text.trim();
      if (text.isNotEmpty) fields['personas[$index][$key]'] = text;
    }

    put('nombre_completo', nombre);
    put('alias', alias);
    put('edad', edad);
    put('sexo', sexo);
    put('fecha_nacimiento', fechaNacimiento);
    put('curp', curp);
    put('rfc', rfc);
    put('calidad', calidad);
    put('domicilio', domicilio);
    put('delito_o_motivo', delito);
    put('mandamiento_judicial', mandamiento);
    put('observaciones', observaciones);
    if (ordenAprehension) fields['personas[$index][orden_aprehension]'] = '1';
  }

  void dispose() {
    for (final controller in [
      nombre,
      alias,
      edad,
      sexo,
      fechaNacimiento,
      curp,
      rfc,
      calidad,
      domicilio,
      delito,
      mandamiento,
      observaciones,
    ]) {
      controller.dispose();
    }
  }
}

class _VehiculoFields {
  final tipo = TextEditingController();
  final marca = TextEditingController();
  final submarca = TextEditingController();
  final modelo = TextEditingController();
  final color = TextEditingController();
  final placas = TextEditingController();
  final serie = TextEditingController();
  final calidad = TextEditingController();
  final motivoRelacion = TextEditingController();
  final numeroReporteRobo = TextEditingController();
  final observaciones = TextEditingController();
  bool conReporteRobo = false;

  bool get hasAny => [
    tipo,
    marca,
    submarca,
    modelo,
    color,
    placas,
    serie,
    calidad,
    motivoRelacion,
    numeroReporteRobo,
    observaciones,
  ].any((controller) => controller.text.trim().isNotEmpty);

  void write(Map<String, String> fields, int index) {
    void put(String key, TextEditingController controller) {
      final text = controller.text.trim();
      if (text.isNotEmpty) fields['vehiculos[$index][$key]'] = text;
    }

    put('tipo', tipo);
    put('marca', marca);
    put('submarca', submarca);
    put('modelo', modelo);
    put('color', color);
    put('placas', placas);
    put('serie', serie);
    put('calidad', calidad);
    put('motivo_relacion', motivoRelacion);
    put('numero_reporte_robo', numeroReporteRobo);
    put('observaciones', observaciones);
    if (conReporteRobo) fields['vehiculos[$index][con_reporte_robo]'] = '1';
  }

  void dispose() {
    for (final controller in [
      tipo,
      marca,
      submarca,
      modelo,
      color,
      placas,
      serie,
      calidad,
      motivoRelacion,
      numeroReporteRobo,
      observaciones,
    ]) {
      controller.dispose();
    }
  }
}

class _ObjetoFields {
  final tipoObjeto = TextEditingController();
  final descripcion = TextEditingController();
  final cantidad = TextEditingController();
  final unidadMedida = TextEditingController();
  final cadenaCustodia = TextEditingController();
  final observaciones = TextEditingController();

  bool get hasAny => [
    tipoObjeto,
    descripcion,
    cantidad,
    unidadMedida,
    cadenaCustodia,
    observaciones,
  ].any((controller) => controller.text.trim().isNotEmpty);

  void write(Map<String, String> fields, int index) {
    void put(String key, TextEditingController controller) {
      final text = controller.text.trim();
      if (text.isNotEmpty) fields['objetos[$index][$key]'] = text;
    }

    put('tipo_objeto', tipoObjeto);
    put('descripcion', descripcion);
    put('cantidad', cantidad);
    put('unidad_medida', unidadMedida);
    put('cadena_custodia', cadenaCustodia);
    put('observaciones', observaciones);
  }

  void dispose() {
    for (final controller in [
      tipoObjeto,
      descripcion,
      cantidad,
      unidadMedida,
      cadenaCustodia,
      observaciones,
    ]) {
      controller.dispose();
    }
  }
}
