import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/vialidades_urbanas_dispositivo.dart';
import '../../services/auth_service.dart';
import '../../services/local_draft_service.dart';
import '../../services/vialidades_urbanas_form_service.dart';
import '../../services/vialidades_urbanas_service.dart';
import '../../widgets/landscape_photo_crop_screen.dart';

class VialidadesUrbanasCreateScreen extends StatefulWidget {
  const VialidadesUrbanasCreateScreen({super.key});

  @override
  State<VialidadesUrbanasCreateScreen> createState() =>
      _VialidadesUrbanasCreateScreenState();
}

class _VialidadesUrbanasCreateScreenState
    extends State<VialidadesUrbanasCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  bool _hasAccess = false;
  String? _error;

  List<VialidadesUrbanasCatalogo> _catalogos =
      const <VialidadesUrbanasCatalogo>[];
  int? _catalogoId;

  DateTime _fecha = DateTime.now();
  TimeOfDay _hora = TimeOfDay.now();

  final _asuntoCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController(text: 'MORELIA, MICHOACAN');
  final _lugarCtrl = TextEditingController();
  final _eventoCtrl = TextEditingController();
  final _supervisionCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _objetivoCtrl = TextEditingController();
  final _narrativaCtrl = TextEditingController();
  final _accionesCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  final _elementosCtrl = TextEditingController(text: '0');
  final _crpCtrl = TextEditingController(text: '0');
  final _motopatrullasCtrl = TextEditingController(text: '0');
  final _fenixCtrl = TextEditingController(text: '0');
  final _unidadesMotorizadasCtrl = TextEditingController(text: '0');
  final _patrullasCtrl = TextEditingController(text: '0');
  final _gruasCtrl = TextEditingController(text: '0');
  final _otrosApoyosCtrl = TextEditingController(text: '0');

  List<File> _fotos = <File>[];
  late final LocalDraftAutosave _draft;

  @override
  void initState() {
    super.initState();
    _draft =
        LocalDraftAutosave(
          draftId: 'vialidades_urbanas:create',
          collect: _draftValues,
        )..attachTextControllers({
          'asunto': _asuntoCtrl,
          'municipio': _municipioCtrl,
          'lugar': _lugarCtrl,
          'evento': _eventoCtrl,
          'supervision': _supervisionCtrl,
          'descripcion': _descripcionCtrl,
          'objetivo': _objetivoCtrl,
          'narrativa': _narrativaCtrl,
          'acciones': _accionesCtrl,
          'observaciones': _observacionesCtrl,
          'elementos': _elementosCtrl,
          'crp': _crpCtrl,
          'motopatrullas': _motopatrullasCtrl,
          'fenix': _fenixCtrl,
          'unidades_motorizadas': _unidadesMotorizadasCtrl,
          'patrullas': _patrullasCtrl,
          'gruas': _gruasCtrl,
          'otros_apoyos': _otrosApoyosCtrl,
        });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrap();
    });
  }

  @override
  void dispose() {
    _draft.dispose();
    _asuntoCtrl.dispose();
    _municipioCtrl.dispose();
    _lugarCtrl.dispose();
    _eventoCtrl.dispose();
    _supervisionCtrl.dispose();
    _descripcionCtrl.dispose();
    _objetivoCtrl.dispose();
    _narrativaCtrl.dispose();
    _accionesCtrl.dispose();
    _observacionesCtrl.dispose();
    _elementosCtrl.dispose();
    _crpCtrl.dispose();
    _motopatrullasCtrl.dispose();
    _fenixCtrl.dispose();
    _unidadesMotorizadasCtrl.dispose();
    _patrullasCtrl.dispose();
    _gruasCtrl.dispose();
    _otrosApoyosCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final isVialidadesUser = await AuthService.isVialidadesUrbanasUser(
        refresh: true,
      );
      final hasFullOperationalAccess =
          await AuthService.hasFullOperationalAccess();
      final canCreate =
          hasFullOperationalAccess ||
          await AuthService.can('crear operativos vialidades');

      if (!isVialidadesUser || !canCreate) {
        throw Exception(
          'Este modulo es exclusivo para la Unidad de Proteccion en Vialidades Urbanas.',
        );
      }

      final catalogos = await VialidadesUrbanasService.fetchCatalogos(
        fecha: _fecha,
      );

      if (!mounted) return;
      setState(() {
        _hasAccess = true;
        _catalogos = catalogos;
        _catalogoId = catalogos.isNotEmpty ? catalogos.first.id : null;
        _loading = false;
      });
      await _restoreLocalDraft();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasAccess = false;
        _loading = false;
        _error = '$e';
      });
    }
  }

  String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _fmtHm(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> _draftValues() {
    return <String, dynamic>{
      'catalogo_id': _catalogoId,
      'fecha': _fmtYmd(_fecha),
      'hora': _fmtHm(_hora),
      'asunto': _asuntoCtrl.text,
      'municipio': _municipioCtrl.text,
      'lugar': _lugarCtrl.text,
      'evento': _eventoCtrl.text,
      'supervision': _supervisionCtrl.text,
      'descripcion': _descripcionCtrl.text,
      'objetivo': _objetivoCtrl.text,
      'narrativa': _narrativaCtrl.text,
      'acciones': _accionesCtrl.text,
      'observaciones': _observacionesCtrl.text,
      'elementos': _elementosCtrl.text,
      'crp': _crpCtrl.text,
      'motopatrullas': _motopatrullasCtrl.text,
      'fenix': _fenixCtrl.text,
      'unidades_motorizadas': _unidadesMotorizadasCtrl.text,
      'patrullas': _patrullasCtrl.text,
      'gruas': _gruasCtrl.text,
      'otros_apoyos': _otrosApoyosCtrl.text,
      'fotos': _fotos.map((file) => file.path).toList(),
    };
  }

  Future<void> _restoreLocalDraft() async {
    final restored = await _draft.restore(_applyLocalDraft);
    if (!mounted || !restored) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Borrador local recuperado.')));
  }

  void _applyLocalDraft(Map<String, dynamic> draft) {
    _catalogoId = _intValue(draft['catalogo_id']) ?? _catalogoId;
    _fecha = DateTime.tryParse((draft['fecha'] ?? '').toString()) ?? _fecha;
    _hora = _parseTime(draft['hora']) ?? _hora;
    _asuntoCtrl.text = (draft['asunto'] ?? '').toString();
    _municipioCtrl.text = (draft['municipio'] ?? '').toString();
    _lugarCtrl.text = (draft['lugar'] ?? '').toString();
    _eventoCtrl.text = (draft['evento'] ?? '').toString();
    _supervisionCtrl.text = (draft['supervision'] ?? '').toString();
    _descripcionCtrl.text = (draft['descripcion'] ?? '').toString();
    _objetivoCtrl.text = (draft['objetivo'] ?? '').toString();
    _narrativaCtrl.text = (draft['narrativa'] ?? '').toString();
    _accionesCtrl.text = (draft['acciones'] ?? '').toString();
    _observacionesCtrl.text = (draft['observaciones'] ?? '').toString();
    _elementosCtrl.text = (draft['elementos'] ?? '0').toString();
    _crpCtrl.text = (draft['crp'] ?? '0').toString();
    _motopatrullasCtrl.text = (draft['motopatrullas'] ?? '0').toString();
    _fenixCtrl.text = (draft['fenix'] ?? '0').toString();
    _unidadesMotorizadasCtrl.text = (draft['unidades_motorizadas'] ?? '0')
        .toString();
    _patrullasCtrl.text = (draft['patrullas'] ?? '0').toString();
    _gruasCtrl.text = (draft['gruas'] ?? '0').toString();
    _otrosApoyosCtrl.text = (draft['otros_apoyos'] ?? '0').toString();
    _fotos = _filesFromPaths(draft['fotos']);
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString().trim());
  }

  TimeOfDay? _parseTime(dynamic value) {
    final parts = (value ?? '').toString().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  List<File> _filesFromPaths(dynamic value) {
    if (value is! List) return const <File>[];
    return value
        .map((item) => File(item.toString()))
        .where((file) => file.existsSync())
        .toList();
  }

  void _markDraftChanged() {
    _draft.notifyChanged();
  }

  int _readInt(TextEditingController controller) {
    return int.tryParse(controller.text.trim()) ?? 0;
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _card({required String title, required Widget child}) {
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
    _markDraftChanged();
  }

  Future<void> _pickHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    setState(() => _hora = picked);
    _markDraftChanged();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (picked == null || !mounted) return;
    final file = await LandscapePhotoCropScreen.cropIfNeeded(
      context,
      File(picked.path),
    );
    if (file == null) return;
    if (!mounted) return;
    setState(() => _fotos = <File>[..._fotos, file]);
    _markDraftChanged();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    final payload = VialidadesUrbanasFormPayload(
      catalogoId: _catalogoId ?? 0,
      fecha: _fecha,
      hora: _hora,
      asunto: _asuntoCtrl.text,
      municipio: _municipioCtrl.text,
      lugar: _lugarCtrl.text,
      evento: _eventoCtrl.text,
      objetivo: _objetivoCtrl.text,
      descripcion: _descripcionCtrl.text,
      narrativa: _narrativaCtrl.text,
      accionesRealizadas: _accionesCtrl.text,
      observaciones: _observacionesCtrl.text,
      supervision: _supervisionCtrl.text,
      elementos: _readInt(_elementosCtrl),
      crp: _readInt(_crpCtrl),
      motopatrullas: _readInt(_motopatrullasCtrl),
      fenix: _readInt(_fenixCtrl),
      unidadesMotorizadas: _readInt(_unidadesMotorizadasCtrl),
      patrullas: _readInt(_patrullasCtrl),
      gruas: _readInt(_gruasCtrl),
      otrosApoyos: _readInt(_otrosApoyosCtrl),
      fotos: _fotos,
    );

    final validation = await VialidadesUrbanasFormService.validateBeforeSubmit(
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
      final result = await VialidadesUrbanasFormService.create(
        payload: payload,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      await _draft.discard();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildForceField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: _dec(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Nuevo Dispositivo Vialidades Urbanas'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : !_hasAccess
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error ?? 'No tienes acceso a este modulo.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _card(
                      title: 'Datos base',
                      child: Column(
                        children: [
                          DropdownButtonFormField<int>(
                            value: _catalogoId,
                            items: _catalogos
                                .map(
                                  (catalogo) => DropdownMenuItem<int>(
                                    value: catalogo.id,
                                    child: Text(catalogo.nombre),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _catalogoId = value);
                              _markDraftChanged();
                            },
                            decoration: _dec('Catalogo'),
                            validator: (value) {
                              if ((value ?? 0) <= 0) {
                                return 'Selecciona un catalogo.';
                              }
                              return null;
                            },
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
                                  onTap: _pickHora,
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
                          TextFormField(
                            controller: _asuntoCtrl,
                            decoration: _dec('Asunto'),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'El asunto es obligatorio.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _municipioCtrl,
                            decoration: _dec('Municipio'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _lugarCtrl,
                            decoration: _dec('Lugar'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _eventoCtrl,
                            decoration: _dec('Evento'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _supervisionCtrl,
                            decoration: _dec('Supervision'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descripcionCtrl,
                            minLines: 4,
                            maxLines: 5,
                            decoration: _dec('Descripcion principal'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _objetivoCtrl,
                            minLines: 3,
                            maxLines: 4,
                            decoration: _dec('Objetivo'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      title: 'Notas adicionales',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _narrativaCtrl,
                            minLines: 3,
                            maxLines: 5,
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
                      title: 'Estado de fuerza',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildForceField(
                                  'Elementos',
                                  _elementosCtrl,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildForceField('CRP', _crpCtrl),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildForceField(
                                  'Motopatrullas',
                                  _motopatrullasCtrl,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildForceField('Fenix', _fenixCtrl),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildForceField(
                                  'Unid. motorizadas',
                                  _unidadesMotorizadasCtrl,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildForceField(
                                  'Patrullas',
                                  _patrullasCtrl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildForceField('Gruas', _gruasCtrl),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildForceField(
                                  'Otros apoyos',
                                  _otrosApoyosCtrl,
                                ),
                              ),
                            ],
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
                                  onPressed: () =>
                                      _pickPhoto(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Galeria'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _pickPhoto(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Camara'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_fotos.isEmpty)
                            const Text('Todavia no agregas fotos.')
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
                                            _markDraftChanged();
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
                      onPressed: _saving ? null : _submit,
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
                      label: Text(_saving ? 'Guardando...' : 'Guardar'),
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
