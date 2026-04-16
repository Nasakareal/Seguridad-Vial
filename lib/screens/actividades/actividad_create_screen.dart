import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/actividad.dart';
import '../../models/actividad_categoria.dart';
import '../../models/actividad_subcategoria.dart';
import '../../services/actividades_service.dart';
import '../../services/auth_service.dart';
import '../../services/geo_service.dart';
import 'widgets/actividad_vehiculo_modal.dart';

class ActividadCreateScreen extends StatefulWidget {
  const ActividadCreateScreen({super.key});

  @override
  State<ActividadCreateScreen> createState() => _ActividadCreateScreenState();
}

class _ActividadCreateScreenState extends State<ActividadCreateScreen> {
  bool _saving = false;
  bool _locating = false;
  bool _draftHydrated = false;
  String? _error;
  String? _userLabel;
  String? _clientUuid;
  String _locationStatus = 'Aun no se ha capturado la ubicacion.';

  List<ActividadCategoria> _categorias = [];
  List<ActividadSubcategoria> _subcategorias = [];

  int? _categoriaId;
  int? _subcategoriaId;
  final List<File> _fotos = [];
  final List<ActividadVehiculo> _vehiculos = [];

  final _fechaCtrl = TextEditingController();
  final _horaCtrl = TextEditingController();
  final _lugarCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController(text: 'MORELIA');
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _coordenadasCtrl = TextEditingController();
  final _fuenteUbicacionCtrl = TextEditingController();
  final _notaGeoCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _narrativaCtrl = TextEditingController();
  final _accionesCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  final _personasAlcanzadasCtrl = TextEditingController(text: '0');
  final _personasParticipantesCtrl = TextEditingController(text: '0');
  final _personasDetenidasCtrl = TextEditingController(text: '0');
  final _elementosCtrl = TextEditingController();
  final _patrullasCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _setNow();
    _loadCategorias();
    _loadUserLabel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draftHydrated) return;
    _draftHydrated = true;
    _hydrateDraftFromArgs();
  }

  @override
  void dispose() {
    _fechaCtrl.dispose();
    _horaCtrl.dispose();
    _lugarCtrl.dispose();
    _municipioCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _coordenadasCtrl.dispose();
    _fuenteUbicacionCtrl.dispose();
    _notaGeoCtrl.dispose();
    _motivoCtrl.dispose();
    _narrativaCtrl.dispose();
    _accionesCtrl.dispose();
    _observacionesCtrl.dispose();
    _personasAlcanzadasCtrl.dispose();
    _personasParticipantesCtrl.dispose();
    _personasDetenidasCtrl.dispose();
    _elementosCtrl.dispose();
    _patrullasCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserLabel() async {
    final name = await AuthService.getUserName();
    final email = await AuthService.getUserEmail();
    if (!mounted) return;
    setState(() {
      final cleanedName = (name ?? '').trim();
      final cleanedEmail = (email ?? '').trim();
      _userLabel = cleanedName.isNotEmpty
          ? cleanedName
          : (cleanedEmail.isNotEmpty ? cleanedEmail : 'Usuario actual');
    });
  }

  void _setNow() {
    final now = DateTime.now();
    _fechaCtrl.text =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _horaCtrl.text =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _loadCategorias() async {
    try {
      final cats = await ActividadesService.fetchCategorias();
      if (!mounted) return;
      setState(() => _categorias = cats);
      if (_categoriaId != null && _categoriaId! > 0) {
        await _loadSubcategorias(
          _categoriaId!,
          preferredSubcategoriaId: _subcategoriaId,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudieron cargar categorias.\n$e');
    }
  }

  Future<void> _loadSubcategorias(
    int categoriaId, {
    int? preferredSubcategoriaId,
  }) async {
    final targetSubcategoriaId = preferredSubcategoriaId ?? _subcategoriaId;
    setState(() {
      _subcategorias = [];
      if (preferredSubcategoriaId == null) {
        _subcategoriaId = null;
      }
    });

    try {
      final subs = await ActividadesService.fetchSubcategorias(categoriaId);
      if (!mounted) return;
      setState(() {
        _subcategorias = subs;
        if (targetSubcategoriaId != null &&
            subs.any((item) => item.id == targetSubcategoriaId)) {
          _subcategoriaId = targetSubcategoriaId;
        } else if (subs.length == 1) {
          _subcategoriaId = subs.first.id;
        } else if (preferredSubcategoriaId == null) {
          _subcategoriaId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudieron cargar subcategorias.\n$e');
    }
  }

  void _hydrateDraftFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map || args['offlineDraft'] is! Map) return;

    final draft = Map<String, dynamic>.from(args['offlineDraft'] as Map);
    final fields = _stringMapFrom(draft['fields']);
    final files = _listMapFrom(draft['files']);

    _clientUuid = _firstNonEmpty(<String?>[
      (draft['id'] ?? '').toString(),
      fields['client_uuid'],
    ]);

    _categoriaId = int.tryParse(
      (fields['actividad_categoria_id'] ?? '').trim(),
    );
    _subcategoriaId = int.tryParse(
      (fields['actividad_subcategoria_id'] ?? '').trim(),
    );

    _fechaCtrl.text = (fields['fecha'] ?? '').trim();
    _horaCtrl.text = (fields['hora'] ?? '').trim();
    _lugarCtrl.text = (fields['lugar'] ?? '').trim();
    _municipioCtrl.text = (fields['municipio'] ?? '').trim();
    _latCtrl.text = (fields['lat'] ?? '').trim();
    _lngCtrl.text = (fields['lng'] ?? '').trim();
    _coordenadasCtrl.text = (fields['coordenadas_texto'] ?? '').trim();
    _fuenteUbicacionCtrl.text = (fields['fuente_ubicacion'] ?? '').trim();
    _notaGeoCtrl.text = (fields['nota_geo'] ?? '').trim();
    _motivoCtrl.text = (fields['motivo'] ?? '').trim();
    _narrativaCtrl.text = (fields['narrativa'] ?? '').trim();
    _accionesCtrl.text = (fields['acciones_realizadas'] ?? '').trim();
    _observacionesCtrl.text = (fields['observaciones'] ?? '').trim();
    _personasAlcanzadasCtrl.text = (fields['personas_alcanzadas'] ?? '0')
        .trim();
    _personasParticipantesCtrl.text = (fields['personas_participantes'] ?? '0')
        .trim();
    _personasDetenidasCtrl.text = (fields['personas_detenidas'] ?? '0').trim();
    _elementosCtrl.text = (fields['elementos_participantes_texto'] ?? '')
        .trim();
    _patrullasCtrl.text = (fields['patrullas_participantes_texto'] ?? '')
        .trim();

    _fotos
      ..clear()
      ..addAll(_filesForDraft(files));
    _vehiculos
      ..clear()
      ..addAll(_vehiculosFromFields(fields));

    if (_latCtrl.text.trim().isNotEmpty && _lngCtrl.text.trim().isNotEmpty) {
      _locationStatus = 'Ubicacion recuperada del borrador offline.';
    } else if (_notaGeoCtrl.text.trim().isNotEmpty) {
      _locationStatus = _notaGeoCtrl.text.trim();
    }
  }

  Map<String, String> _stringMapFrom(dynamic value) {
    if (value is! Map) return const <String, String>{};
    return value.map(
      (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
    );
  }

  List<Map<String, dynamic>> _listMapFrom(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<File> _filesForDraft(List<Map<String, dynamic>> files) {
    final restored = <File>[];
    for (final item in files) {
      final field = (item['field'] ?? '').toString().trim();
      if (field != 'fotos[]' && field != 'foto') continue;

      final path = (item['path'] ?? '').toString().trim();
      if (path.isEmpty) continue;

      final file = File(path);
      if (!file.existsSync()) continue;
      if (restored.any((existing) => existing.path == file.path)) continue;
      restored.add(file);
    }
    return restored;
  }

  List<ActividadVehiculo> _vehiculosFromFields(Map<String, String> fields) {
    final grouped = <int, Map<String, String>>{};
    final pattern = RegExp(r'^vehiculos\[(\d+)\]\[([^\]]+)\]$');

    for (final entry in fields.entries) {
      final match = pattern.firstMatch(entry.key);
      if (match == null) continue;

      final index = int.tryParse(match.group(1) ?? '');
      final field = match.group(2);
      if (index == null || field == null) continue;

      grouped.putIfAbsent(index, () => <String, String>{})[field] = entry.value;
    }

    final indexes = grouped.keys.toList()..sort();

    return indexes
        .map((index) => _vehiculoFromMap(grouped[index] ?? const {}))
        .where((vehiculo) => vehiculo.marca.trim().isNotEmpty)
        .toList();
  }

  ActividadVehiculo _vehiculoFromMap(Map<String, String> data) {
    String? str(String key) {
      final clean = (data[key] ?? '').trim();
      return clean.isEmpty ? null : clean;
    }

    bool boolValue(String key) {
      final raw = (data[key] ?? '').trim().toLowerCase();
      return raw == '1' || raw == 'true' || raw == 'si' || raw == 'sí';
    }

    return ActividadVehiculo(
      marca: str('marca') ?? '',
      modelo: str('modelo'),
      tipoGeneral: str('tipo_general'),
      tipo: str('tipo') ?? '',
      linea: str('linea') ?? '',
      color: str('color') ?? '',
      placas: str('placas'),
      estadoPlacas: str('estado_placas'),
      serie: str('serie'),
      capacidadPersonas: int.tryParse(str('capacidad_personas') ?? '') ?? 0,
      tipoServicio: str('tipo_servicio') ?? 'PARTICULAR',
      tarjetaCirculacionNombre: str('tarjeta_circulacion_nombre'),
      grua: str('grua'),
      corralon: str('corralon'),
      aseguradora: str('aseguradora'),
      antecedenteVehiculo: boolValue('antecedente_vehiculo'),
      montoDanos: double.tryParse(str('monto_danos') ?? ''),
      partesDanadas: str('partes_danadas'),
    );
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final item in values) {
      final clean = (item ?? '').trim();
      if (clean.isNotEmpty) return clean;
    }
    return null;
  }

  Future<void> _pickFromGallery() async {
    setState(() => _error = null);

    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    setState(() {
      for (final item in picked) {
        final file = File(item.path);
        if (!_fotos.any((f) => f.path == file.path)) {
          _fotos.add(file);
        }
      }
    });
  }

  Future<void> _pickFromCamera() async {
    setState(() => _error = null);

    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (x == null) return;

    setState(() {
      final file = File(x.path);
      if (!_fotos.any((f) => f.path == file.path)) {
        _fotos.add(file);
      }
    });
  }

  Future<void> _captureLocation() async {
    if (_locating) return;

    setState(() {
      _locating = true;
      _locationStatus = 'Obteniendo ubicacion...';
      _error = null;
    });

    final geo = await GeoService.getCurrent();
    if (!mounted) return;

    if (geo.lat == null || geo.lng == null) {
      setState(() {
        _locating = false;
        _locationStatus = geo.notaGeo ?? 'No se pudo obtener la ubicacion.';
      });
      return;
    }

    final lat = geo.lat!.toStringAsFixed(7);
    final lng = geo.lng!.toStringAsFixed(7);

    setState(() {
      _locating = false;
      _latCtrl.text = lat;
      _lngCtrl.text = lng;
      _coordenadasCtrl.text = '$lat, $lng';
      _fuenteUbicacionCtrl.text = geo.fuenteUbicacion ?? 'GPS_APP';
      _notaGeoCtrl.text = geo.notaGeo ?? '';
      _locationStatus = 'Ubicacion capturada correctamente.';
    });
  }

  String? _trim(TextEditingController ctrl) {
    final value = ctrl.text.trim();
    return value.isEmpty ? null : value;
  }

  ActividadUpsertData _buildPayload() {
    return ActividadUpsertData(
      clientUuid: _clientUuid,
      actividadCategoriaId: _categoriaId ?? 0,
      actividadSubcategoriaId: _subcategoriaId,
      fecha: _trim(_fechaCtrl),
      hora: _trim(_horaCtrl),
      lugar: _trim(_lugarCtrl),
      municipio: _trim(_municipioCtrl),
      lat: _trim(_latCtrl),
      lng: _trim(_lngCtrl),
      coordenadasTexto: _trim(_coordenadasCtrl),
      fuenteUbicacion: _trim(_fuenteUbicacionCtrl),
      notaGeo: _trim(_notaGeoCtrl),
      motivo: _trim(_motivoCtrl),
      narrativa: _trim(_narrativaCtrl),
      accionesRealizadas: _trim(_accionesCtrl),
      observaciones: _trim(_observacionesCtrl),
      personasAlcanzadas: _trim(_personasAlcanzadasCtrl),
      personasParticipantes: _trim(_personasParticipantesCtrl),
      personasDetenidas: _trim(_personasDetenidasCtrl),
      elementosParticipantesTexto: _trim(_elementosCtrl),
      patrullasParticipantesTexto: _trim(_patrullasCtrl),
      vehiculos: List<ActividadVehiculo>.from(_vehiculos),
    );
  }

  Future<void> _agregarVehiculo() async {
    final vehiculo = await showActividadVehiculoModal(context);
    if (vehiculo == null || !mounted) return;

    setState(() => _vehiculos.add(vehiculo));
  }

  void _quitarVehiculo(int index) {
    setState(() => _vehiculos.removeAt(index));
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (_categoriaId == null || _categoriaId! <= 0) {
      setState(() => _error = 'Selecciona una categoria.');
      return;
    }

    if (_subcategorias.isEmpty) {
      setState(
        () => _error =
            'La categoria seleccionada no tiene subcategorias disponibles.',
      );
      return;
    }

    if (_subcategoriaId == null || _subcategoriaId! <= 0) {
      setState(() => _error = 'Selecciona una subcategoria.');
      return;
    }

    if (_fechaCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Captura la fecha.');
      return;
    }

    if (_fotos.isEmpty) {
      setState(() => _error = 'Selecciona al menos una foto.');
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);

    try {
      final result = await ActividadesService.create(
        data: _buildPayload(),
        fotos: List<File>.from(_fotos),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo crear.\n$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: _dec(label, hint: hint),
    );
  }

  Widget _previewFotos() {
    if (_fotos.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            'Sin fotos',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _fotos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final foto = _fotos[index];
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(foto, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: InkWell(
                onTap: _saving
                    ? null
                    : () => setState(() => _fotos.removeAt(index)),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords =
        _latCtrl.text.trim().isNotEmpty && _lngCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Crear actividad'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withValues(alpha: .2)),
                ),
                child: Text(_error!),
              ),
            if (_error != null) const SizedBox(height: 12),

            _card(
              title: 'Datos generales',
              child: Column(
                children: [
                  _textField(
                    TextEditingController(text: _userLabel ?? 'Usuario actual'),
                    'Nombre',
                    readOnly: true,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Se toma automaticamente del usuario. No se puede editar.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _categoriaId,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Seleccione categoria...'),
                      ),
                      ..._categorias.map(
                        (c) => DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(c.nombre),
                        ),
                      ),
                    ],
                    onChanged: (v) async {
                      setState(() {
                        _categoriaId = v;
                        _subcategoriaId = null;
                        _subcategorias = [];
                      });
                      if (v != null) {
                        await _loadSubcategorias(v);
                      }
                    },
                    decoration: _dec('Categoria'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _subcategoriaId,
                    items: [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Text(
                          _subcategorias.isEmpty
                              ? 'No hay subcategorias disponibles'
                              : 'Seleccione subcategoria...',
                        ),
                      ),
                      ..._subcategorias.map(
                        (s) => DropdownMenuItem<int>(
                          value: s.id,
                          child: Text(s.nombre),
                        ),
                      ),
                    ],
                    onChanged: _subcategorias.isEmpty
                        ? null
                        : (v) => setState(() => _subcategoriaId = v),
                    decoration: _dec('Subcategoria'),
                  ),
                  if (_categoriaId != null && _subcategorias.isEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No puedes guardar la actividad hasta que esa categoria tenga subcategorias en el servidor.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            _card(
              title: 'Fecha, hora y lugar',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          _fechaCtrl,
                          'Fecha',
                          hint: 'YYYY-MM-DD',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _textField(_horaCtrl, 'Hora', hint: 'HH:mm'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _setNow()),
                      icon: const Icon(Icons.access_time),
                      label: const Text('Usar fecha y hora actual'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _textField(_lugarCtrl, 'Lugar'),
                  const SizedBox(height: 12),
                  _textField(_municipioCtrl, 'Municipio'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _card(
              title: 'Ubicacion',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: (_saving || _locating)
                            ? null
                            : _captureLocation,
                        icon: _locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(
                          _locating ? 'Obteniendo...' : 'Usar mi ubicacion',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _locationStatus,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  if (hasCoords) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(_coordenadasCtrl.text),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            _card(
              title: 'Contenido',
              child: Column(
                children: [
                  _textField(_motivoCtrl, 'Que ocasiona o motivo', maxLines: 3),
                  const SizedBox(height: 12),
                  _textField(_narrativaCtrl, 'Narrativa', maxLines: 3),
                  const SizedBox(height: 12),
                  _textField(_accionesCtrl, 'Acciones realizadas', maxLines: 3),
                  const SizedBox(height: 12),
                  _textField(_observacionesCtrl, 'Observaciones', maxLines: 3),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _card(
              title: 'Personas y participantes',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          _personasAlcanzadasCtrl,
                          'Personas alcanzadas',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _textField(
                          _personasParticipantesCtrl,
                          'Personas participantes',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    _personasDetenidasCtrl,
                    'Personas detenidas',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    _elementosCtrl,
                    'Elementos participantes',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    _patrullasCtrl,
                    'Patrullas participantes',
                    maxLines: 3,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _card(
              title: 'Vehiculos relacionados',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total: ${_vehiculos.length}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _agregarVehiculo,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar vehiculo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_vehiculos.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: .16),
                        ),
                      ),
                      child: const Text(
                        'No hay vehiculos agregados para esta actividad.',
                      ),
                    )
                  else
                    ..._vehiculos.asMap().entries.map((entry) {
                      return ActividadVehiculoCard(
                        vehiculo: entry.value,
                        onRemove: _saving
                            ? null
                            : () => _quitarVehiculo(entry.key),
                      );
                    }),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _card(
              title: 'Fotos',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_fotos.length} archivo(s) seleccionado(s)',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 10),
                  _previewFotos(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _pickFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galeria'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _pickFromCamera,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camara'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: .06),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
