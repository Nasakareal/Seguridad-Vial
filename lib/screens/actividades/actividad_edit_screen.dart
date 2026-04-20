import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/actividad.dart';
import '../../models/actividad_categoria.dart';
import '../../models/actividad_subcategoria.dart';
import '../../services/actividades_service.dart';
import '../../widgets/landscape_photo_crop_screen.dart';
import '../../widgets/safe_network_image.dart';
import 'widgets/actividad_vehiculo_modal.dart';

class ActividadEditScreen extends StatefulWidget {
  const ActividadEditScreen({super.key});

  @override
  State<ActividadEditScreen> createState() => _ActividadEditScreenState();
}

class _ActividadEditScreenState extends State<ActividadEditScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  Actividad? _actividad;

  List<ActividadCategoria> _categorias = [];
  List<ActividadSubcategoria> _subcategorias = [];

  int? _categoriaId;
  int? _subcategoriaId;
  File? _fotoNueva;

  final _fechaCtrl = TextEditingController();
  final _horaCtrl = TextEditingController();
  final _lugarCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _coordenadasCtrl = TextEditingController();
  final _fuenteUbicacionCtrl = TextEditingController();
  final _notaGeoCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _narrativaCtrl = TextEditingController();
  final _accionesCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  final _personasAlcanzadasCtrl = TextEditingController();
  final _personasParticipantesCtrl = TextEditingController();
  final _personasDetenidasCtrl = TextEditingController();
  final _elementosCtrl = TextEditingController();
  final _patrullasCtrl = TextEditingController();

  bool _bootstrapped = false;

  int? _idFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final v = args['actividad_id'] ?? args['id'];
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '');
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    _bootstrap();
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

  Future<void> _bootstrap() async {
    final id = _idFromArgs();
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Falta actividad_id';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cats = await ActividadesService.fetchCategorias();
      final a = await ActividadesService.fetchShow(id);

      if (!mounted) return;

      _fillControllers(a);

      setState(() {
        _categorias = cats;
        _actividad = a;
        _categoriaId = a.actividadCategoriaId;
        _subcategoriaId = a.actividadSubcategoriaId;
        _loading = false;
      });

      if (_categoriaId != null) {
        await _loadSubcategorias(_categoriaId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar.\n$e';
      });
    }
  }

  void _fillControllers(Actividad a) {
    _fechaCtrl.text = a.fecha ?? '';
    _horaCtrl.text = a.hora == null
        ? ''
        : a.hora!.substring(0, a.hora!.length >= 5 ? 5 : a.hora!.length);
    _lugarCtrl.text = a.lugar ?? '';
    _municipioCtrl.text = a.municipio ?? '';
    _latCtrl.text = a.lat?.toString() ?? '';
    _lngCtrl.text = a.lng?.toString() ?? '';
    _coordenadasCtrl.text = a.coordenadasTexto ?? '';
    _fuenteUbicacionCtrl.text = a.fuenteUbicacion ?? '';
    _notaGeoCtrl.text = a.notaGeo ?? '';
    _motivoCtrl.text = a.motivo ?? '';
    _narrativaCtrl.text = a.narrativa ?? '';
    _accionesCtrl.text = a.accionesRealizadas ?? '';
    _observacionesCtrl.text = a.observaciones ?? '';
    _personasAlcanzadasCtrl.text = a.personasAlcanzadas.toString();
    _personasParticipantesCtrl.text = a.personasParticipantes.toString();
    _personasDetenidasCtrl.text = a.personasDetenidas.toString();
    _elementosCtrl.text = a.elementosParticipantesTexto ?? '';
    _patrullasCtrl.text = a.patrullasParticipantesTexto ?? '';
  }

  Future<void> _loadSubcategorias(int categoriaId) async {
    try {
      final subs = await ActividadesService.fetchSubcategorias(categoriaId);
      if (!mounted) return;

      setState(() {
        _subcategorias = subs;
        if (_subcategoriaId != null &&
            !subs.any((s) => s.id == _subcategoriaId)) {
          _subcategoriaId = null;
        }
        if (_subcategoriaId == null && subs.length == 1) {
          _subcategoriaId = subs.first.id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subcategorias = [];
        _subcategoriaId = null;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (x == null || !mounted) return;

    final file = await LandscapePhotoCropScreen.cropIfNeeded(
      context,
      File(x.path),
    );
    if (file == null) return;
    if (!mounted) return;

    setState(() {
      _fotoNueva = file;
    });
  }

  String? _trim(TextEditingController ctrl) {
    final value = ctrl.text.trim();
    return value.isEmpty ? null : value;
  }

  ActividadUpsertData _buildPayload() {
    return ActividadUpsertData(
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
      accionesRealizadas: null,
      observaciones: null,
      personasAlcanzadas: _trim(_personasAlcanzadasCtrl),
      personasParticipantes: _trim(_personasParticipantesCtrl),
      personasDetenidas: _trim(_personasDetenidasCtrl),
      elementosParticipantesTexto: _trim(_elementosCtrl),
      patrullasParticipantesTexto: _trim(_patrullasCtrl),
    );
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    final a = _actividad;
    if (a == null) return;

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

    final personasAlcanzadas = int.tryParse(
      _personasAlcanzadasCtrl.text.trim(),
    );
    if (personasAlcanzadas == null || personasAlcanzadas < 1) {
      setState(() => _error = 'Captura al menos 1 persona alcanzada.');
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);

    try {
      final result = await ActividadesService.update(
        id: a.id,
        data: _buildPayload(),
        foto: _fotoNueva,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo actualizar.\n$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _agregarVehiculo() async {
    final a = _actividad;
    if (a == null || _saving) return;

    final vehiculo = await showActividadVehiculoModal(context);
    if (vehiculo == null || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await ActividadesService.storeVehiculo(
        actividadId: a.id,
        vehiculo: vehiculo,
      );
      if (!mounted) return;
      setState(() => _actividad = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehiculo agregado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo agregar el vehiculo.\n$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _quitarVehiculo(ActividadVehiculo vehiculo) async {
    final a = _actividad;
    final vehiculoId = vehiculo.id;
    if (a == null || vehiculoId == null || _saving) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desvincular vehiculo'),
        content: const Text('¿Desvincular este vehiculo de la actividad?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await ActividadesService.destroyVehiculo(
        actividadId: a.id,
        vehiculoId: vehiculoId,
      );
      if (!mounted) return;
      setState(() => _actividad = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehiculo desvinculado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo desvincular el vehiculo.\n$e');
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
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _dec(label, hint: hint),
    );
  }

  Widget _currentPhoto(Actividad a) {
    if (_fotoNueva != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.file(_fotoNueva!, fit: BoxFit.cover),
        ),
      );
    }

    final photoPaths = a.allPhotoPaths;
    if (photoPaths.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            'Sin foto',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final url = ActividadesService.toPublicUrl(photoPaths.first);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: SafeNetworkImage(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade200,
            child: const Center(child: Text('No se pudo cargar la imagen.')),
          ),
          loadingBuilder: (context, progress) {
            return Container(
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = _actividad;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Editar actividad'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _bootstrap),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && a == null)
              Text(_error!)
            else if (a == null)
              const Text('Sin datos.')
            else ...[
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
                title: 'Clasificacion',
                child: Column(
                  children: [
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
                title: 'Ubicacion y tiempo',
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
                    const SizedBox(height: 12),
                    _textField(_lugarCtrl, 'Lugar'),
                    const SizedBox(height: 12),
                    _textField(_municipioCtrl, 'Municipio'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _textField(
                            _latCtrl,
                            'Latitud',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _textField(
                            _lngCtrl,
                            'Longitud',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _textField(_coordenadasCtrl, 'Coordenadas texto'),
                    const SizedBox(height: 12),
                    _textField(_fuenteUbicacionCtrl, 'Fuente de ubicacion'),
                    const SizedBox(height: 12),
                    _textField(_notaGeoCtrl, 'Nota geo'),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _card(
                title: 'Contenido',
                child: Column(
                  children: [
                    _textField(_motivoCtrl, 'Asunto', maxLines: 2),
                    const SizedBox(height: 12),
                    _textField(_narrativaCtrl, 'Narrativa', maxLines: 6),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _card(
                title: 'Totales y participantes',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _textField(
                            _personasAlcanzadasCtrl,
                            'Personas alcanzadas *',
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
                            'Total: ${a.vehiculos.length}',
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
                    if (a.vehiculos.isEmpty)
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
                          'No hay vehiculos vinculados a esta actividad.',
                        ),
                      )
                    else
                      ...a.vehiculos.map((vehiculo) {
                        return ActividadVehiculoCard(
                          vehiculo: vehiculo,
                          onRemove: _saving || vehiculo.id == null
                              ? null
                              : () => _quitarVehiculo(vehiculo),
                        );
                      }),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _card(
                title: 'Foto',
                child: Column(
                  children: [
                    _currentPhoto(a),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galeria'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _pickImage(ImageSource.camera),
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
                    : const Text('Guardar cambios'),
              ),
            ],
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
