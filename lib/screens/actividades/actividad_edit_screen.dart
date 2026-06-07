import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/municipios_michoacan.dart';
import '../../models/actividad.dart';
import '../../models/actividad_categoria.dart';
import '../../models/actividad_fomento.dart';
import '../../models/actividad_subcategoria.dart';
import '../../services/actividades_service.dart';
import '../../services/auth_service.dart';
import '../../services/photo_picker_service.dart';
import '../../widgets/actividad_count_field.dart';
import '../../widgets/actividad_detenidos_field.dart';
import '../../widgets/actividad_people_count_guard.dart';
import '../../widgets/municipio_autocomplete_field.dart';
import '../../widgets/normalized_integer_input_formatter.dart';
import '../../widgets/safe_network_image.dart';
import 'widgets/actividad_vehiculo_modal.dart';
import 'widgets/fomento_cultura_vial_panel.dart';

class ActividadEditScreen extends StatefulWidget {
  const ActividadEditScreen({super.key});

  @override
  State<ActividadEditScreen> createState() => _ActividadEditScreenState();
}

class _ActividadEditScreenState extends State<ActividadEditScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _canEditCaptureTimestamp = false;
  bool _isFomentoUser = false;
  String? _error;
  Map<ActividadValidationTarget, String> _fieldErrors = {};

  Actividad? _actividad;

  List<ActividadCategoria> _categorias = [];
  List<ActividadSubcategoria> _subcategorias = [];

  int? _categoriaId;
  int? _subcategoriaId;
  int? _fomentoProgramaId;
  String? _fomentoNivelEducativo;
  String? _fomentoSector;
  final List<File> _fotosNuevas = [];
  final Set<int> _fotoIdsEliminar = <int>{};

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
  final _fomentoEscuelaCtrl = TextEditingController();
  final _fomentoDomicilioCtrl = TextEditingController();
  final _fomentoNinasCtrl = TextEditingController(text: '0');
  final _fomentoNinosCtrl = TextEditingController(text: '0');
  final _fomentoAdolescentesMujeresCtrl = TextEditingController(text: '0');
  final _fomentoAdolescentesHombresCtrl = TextEditingController(text: '0');
  final _fomentoDocentesHombresCtrl = TextEditingController(text: '0');
  final _fomentoDocentesMujeresCtrl = TextEditingController(text: '0');
  final _fomentoHombresCtrl = TextEditingController(text: '0');
  final _fomentoMujeresCtrl = TextEditingController(text: '0');
  final _fomentoTotalCtrl = TextEditingController(text: '0');

  final _categoriaFieldKey = GlobalKey();
  final _subcategoriaFieldKey = GlobalKey();
  final _fechaFieldKey = GlobalKey();
  final _horaFieldKey = GlobalKey();
  final _lugarFieldKey = GlobalKey();
  final _municipioFieldKey = GlobalKey();
  final _latFieldKey = GlobalKey();
  final _lngFieldKey = GlobalKey();
  final _fuenteUbicacionFieldKey = GlobalKey();
  final _notaGeoFieldKey = GlobalKey();
  final _personasAlcanzadasFieldKey = GlobalKey();
  final _personasParticipantesFieldKey = GlobalKey();
  final _personasDetenidasFieldKey = GlobalKey();
  final _fomentoCardKey = GlobalKey();
  final _vehiculosCardKey = GlobalKey();
  final _fotosCardKey = GlobalKey();

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
    _fomentoEscuelaCtrl.dispose();
    _fomentoDomicilioCtrl.dispose();
    _fomentoNinasCtrl.dispose();
    _fomentoNinosCtrl.dispose();
    _fomentoAdolescentesMujeresCtrl.dispose();
    _fomentoAdolescentesHombresCtrl.dispose();
    _fomentoDocentesHombresCtrl.dispose();
    _fomentoDocentesMujeresCtrl.dispose();
    _fomentoHombresCtrl.dispose();
    _fomentoMujeresCtrl.dispose();
    _fomentoTotalCtrl.dispose();
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
      _fieldErrors = {};
    });

    try {
      final cats = await ActividadesService.fetchCategorias();
      final a = await ActividadesService.fetchShow(id);
      final canEditTimestamp = await AuthService.canEditCaptureTimestamp();
      final unidadId = await AuthService.getUnidadId();

      if (!mounted) return;

      _fillControllers(a);
      _fotosNuevas.clear();
      _fotoIdsEliminar.clear();

      setState(() {
        _categorias = cats;
        _actividad = a;
        _categoriaId = a.actividadCategoriaId;
        _subcategoriaId = a.actividadSubcategoriaId;
        _canEditCaptureTimestamp = canEditTimestamp;
        _isFomentoUser = unidadId == AuthService.unidadCulturaVialId;
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
    _fillFomentoControllers(a.fomentoCulturaVialDetalle);
    _syncFomentoTotal();
  }

  void _fillFomentoControllers(ActividadFomentoDetalle? fomento) {
    _fomentoProgramaId = fomento?.programaId;
    _fomentoEscuelaCtrl.text = fomento?.escuela ?? '';
    _fomentoDomicilioCtrl.text = fomento?.domicilio ?? '';
    _fomentoNivelEducativo = fomento?.nivelEducativo;
    _fomentoSector = fomento?.sector;
    _fomentoNinasCtrl.text = (fomento?.ninas ?? 0).toString();
    _fomentoNinosCtrl.text = (fomento?.ninos ?? 0).toString();
    _fomentoAdolescentesMujeresCtrl.text = (fomento?.adolescentesMujeres ?? 0)
        .toString();
    _fomentoAdolescentesHombresCtrl.text = (fomento?.adolescentesHombres ?? 0)
        .toString();
    _fomentoDocentesHombresCtrl.text = (fomento?.docentesHombres ?? 0)
        .toString();
    _fomentoDocentesMujeresCtrl.text = (fomento?.docentesMujeres ?? 0)
        .toString();
    _fomentoHombresCtrl.text = (fomento?.hombres ?? 0).toString();
    _fomentoMujeresCtrl.text = (fomento?.mujeres ?? 0).toString();
    _fomentoTotalCtrl.text =
        (fomento?.computedTotal ?? fomento?.totalPoblacionAtendida ?? 0)
            .toString();
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
        _ensureFomentoProgramValid();
      });
      _syncFomentoTotal();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subcategorias = [];
        _subcategoriaId = null;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _error = null;
      _removeFieldError(ActividadValidationTarget.fotos);
    });

    final files = await PhotoPickerService.pickAndCropMultiImage(
      context,
      ImagePicker(),
    );

    if (files.isEmpty) return;

    setState(() {
      for (final file in files) {
        _addNewPhoto(file);
      }
      _removeFieldError(ActividadValidationTarget.fotos);
    });
  }

  Future<void> _pickFromCamera() async {
    setState(() {
      _error = null;
      _removeFieldError(ActividadValidationTarget.fotos);
    });

    final file = await PhotoPickerService.pickAndCropImage(
      context,
      ImagePicker(),
      source: ImageSource.camera,
    );
    if (file == null) return;
    if (!mounted) return;

    setState(() {
      _addNewPhoto(file);
      _removeFieldError(ActividadValidationTarget.fotos);
    });
  }

  void _addNewPhoto(File file) {
    if (!_fotosNuevas.any((current) => current.path == file.path)) {
      _fotosNuevas.add(file);
    }
  }

  int _activePhotoCount(Actividad a) {
    final activeExisting = a.fotos
        .where((foto) => !_fotoIdsEliminar.contains(foto.id))
        .length;
    final legacy = a.fotos.isEmpty && a.allPhotoPaths.isNotEmpty ? 1 : 0;
    return activeExisting + legacy + _fotosNuevas.length;
  }

  String? _trim(TextEditingController ctrl) {
    final value = ctrl.text.trim();
    return value.isEmpty ? null : value;
  }

  String? _trimMunicipio(TextEditingController ctrl) {
    final canonical = MunicipiosMichoacan.canonical(ctrl.text);
    return canonical ?? _trim(ctrl);
  }

  String? _trimInteger(TextEditingController ctrl) {
    final value = NormalizedIntegerInputFormatter.normalize(ctrl.text.trim());
    return value.isEmpty ? null : value;
  }

  ActividadCategoria? _selectedCategoria() {
    final id = _categoriaId;
    if (id == null) return null;
    for (final categoria in _categorias) {
      if (categoria.id == id) return categoria;
    }
    return null;
  }

  ActividadSubcategoria? _selectedSubcategoria() {
    final id = _subcategoriaId;
    if (id == null) return null;
    for (final subcategoria in _subcategorias) {
      if (subcategoria.id == id) return subcategoria;
    }
    return null;
  }

  bool get _showFomentoPanel {
    return _selectedCategoria()?.requiereFomentoCulturaVial ?? false;
  }

  bool get _useFomentoUserLayout {
    return _isFomentoUser && _showFomentoPanel;
  }

  List<ActividadFomentoPrograma> get _fomentoProgramas {
    return _selectedSubcategoria()?.programasFomento ??
        const <ActividadFomentoPrograma>[];
  }

  Map<String, TextEditingController> get _fomentoCountControllers => {
    'ninas': _fomentoNinasCtrl,
    'ninos': _fomentoNinosCtrl,
    'adolescentes_mujeres': _fomentoAdolescentesMujeresCtrl,
    'adolescentes_hombres': _fomentoAdolescentesHombresCtrl,
    'docentes_hombres': _fomentoDocentesHombresCtrl,
    'docentes_mujeres': _fomentoDocentesMujeresCtrl,
    'hombres': _fomentoHombresCtrl,
    'mujeres': _fomentoMujeresCtrl,
  };

  void _ensureFomentoProgramValid() {
    if (_fomentoProgramaId == null) return;
    if (_fomentoProgramas.any(
      (programa) => programa.id == _fomentoProgramaId,
    )) {
      return;
    }
    _fomentoProgramaId = null;
  }

  int _readFomentoCount(TextEditingController controller) {
    final normalized = NormalizedIntegerInputFormatter.normalize(
      controller.text,
    );
    return (int.tryParse(normalized) ?? 0)
        .clamp(0, ActividadFomentoDetalle.maxCount)
        .toInt();
  }

  int _fomentoTotal() {
    return _fomentoCountControllers.values.fold<int>(
      0,
      (sum, controller) => sum + _readFomentoCount(controller),
    );
  }

  void _syncFomentoTotal() {
    final total = _fomentoTotal();
    final totalText = total.toString();
    if (_fomentoTotalCtrl.text != totalText) {
      _fomentoTotalCtrl.text = totalText;
    }
    if (_showFomentoPanel && _personasAlcanzadasCtrl.text != totalText) {
      _personasAlcanzadasCtrl.text = totalText;
    }
  }

  ActividadFomentoDetalle _buildFomentoPayload() {
    final total = _fomentoTotal();
    return ActividadFomentoDetalle(
      programaId: _fomentoProgramaId,
      escuela: _trim(_fomentoEscuelaCtrl),
      domicilio: _trim(_fomentoDomicilioCtrl),
      nivelEducativo: _fomentoNivelEducativo,
      sector: _fomentoSector,
      ninas: _readFomentoCount(_fomentoNinasCtrl),
      ninos: _readFomentoCount(_fomentoNinosCtrl),
      adolescentesMujeres: _readFomentoCount(_fomentoAdolescentesMujeresCtrl),
      adolescentesHombres: _readFomentoCount(_fomentoAdolescentesHombresCtrl),
      docentesHombres: _readFomentoCount(_fomentoDocentesHombresCtrl),
      docentesMujeres: _readFomentoCount(_fomentoDocentesMujeresCtrl),
      hombres: _readFomentoCount(_fomentoHombresCtrl),
      mujeres: _readFomentoCount(_fomentoMujeresCtrl),
      totalPoblacionAtendida: total,
    );
  }

  ActividadUpsertData _buildPayload() {
    final fomento = _showFomentoPanel ? _buildFomentoPayload() : null;
    return ActividadUpsertData(
      actividadCategoriaId: _categoriaId ?? 0,
      actividadSubcategoriaId: _subcategoriaId,
      fecha: _trim(_fechaCtrl),
      hora: _trim(_horaCtrl),
      lugar: _trim(_lugarCtrl),
      municipio: _trimMunicipio(_municipioCtrl),
      lat: _trim(_latCtrl),
      lng: _trim(_lngCtrl),
      coordenadasTexto: _trim(_coordenadasCtrl),
      fuenteUbicacion: _trim(_fuenteUbicacionCtrl),
      notaGeo: _trim(_notaGeoCtrl),
      motivo: _useFomentoUserLayout ? null : _trim(_motivoCtrl),
      narrativa: _trim(_narrativaCtrl),
      accionesRealizadas: null,
      observaciones: _trim(_observacionesCtrl),
      personasAlcanzadas: fomento == null
          ? _trimInteger(_personasAlcanzadasCtrl)
          : fomento.computedTotal.toString(),
      personasParticipantes: _trimInteger(_personasParticipantesCtrl),
      personasDetenidas: _trimInteger(_personasDetenidasCtrl),
      elementosParticipantesTexto: _trim(_elementosCtrl),
      patrullasParticipantesTexto: _trim(_patrullasCtrl),
      fomento: fomento,
    );
  }

  String? _fieldError(ActividadValidationTarget target) {
    return _fieldErrors[target];
  }

  void _removeFieldError(ActividadValidationTarget target) {
    if (!_fieldErrors.containsKey(target)) return;
    _fieldErrors = Map<ActividadValidationTarget, String>.from(_fieldErrors)
      ..remove(target);
    if (_fieldErrors.isEmpty) _error = null;
  }

  void _clearFieldError(ActividadValidationTarget target) {
    if (!_fieldErrors.containsKey(target)) return;
    setState(() => _removeFieldError(target));
  }

  void _clearValidationErrors() {
    _fieldErrors = {};
    _error = null;
  }

  Map<ActividadValidationTarget, String> _groupValidationIssues(
    List<ActividadValidationIssue> issues,
  ) {
    final grouped = <ActividadValidationTarget, List<String>>{};
    for (final issue in issues) {
      grouped.putIfAbsent(issue.target, () => <String>[]).add(issue.message);
    }
    return grouped.map(
      (target, messages) => MapEntry(target, messages.join('\n')),
    );
  }

  GlobalKey? _keyForValidationTarget(ActividadValidationTarget target) {
    switch (target) {
      case ActividadValidationTarget.categoria:
        return _categoriaFieldKey;
      case ActividadValidationTarget.subcategoria:
        return _subcategoriaFieldKey;
      case ActividadValidationTarget.fecha:
        return _fechaFieldKey;
      case ActividadValidationTarget.hora:
        return _horaFieldKey;
      case ActividadValidationTarget.lugar:
        return _lugarFieldKey;
      case ActividadValidationTarget.municipio:
        return _municipioFieldKey;
      case ActividadValidationTarget.ubicacion:
        return _latFieldKey;
      case ActividadValidationTarget.fuenteUbicacion:
        return _fuenteUbicacionFieldKey;
      case ActividadValidationTarget.notaGeo:
        return _notaGeoFieldKey;
      case ActividadValidationTarget.carretera:
      case ActividadValidationTarget.tramo:
      case ActividadValidationTarget.kilometro:
        return _lugarFieldKey;
      case ActividadValidationTarget.personasAlcanzadas:
        return _personasAlcanzadasFieldKey;
      case ActividadValidationTarget.personasParticipantes:
        return _personasParticipantesFieldKey;
      case ActividadValidationTarget.personasDetenidas:
        return _personasDetenidasFieldKey;
      case ActividadValidationTarget.fomento:
        return _fomentoCardKey;
      case ActividadValidationTarget.fotos:
        return _fotosCardKey;
      case ActividadValidationTarget.vehiculos:
        return _vehiculosCardKey;
    }
  }

  Future<void> _scrollToKey(GlobalKey key) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    final targetContext = key.currentContext;
    if (targetContext == null || !targetContext.mounted) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  Future<void> _showValidationIssues(
    List<ActividadValidationIssue> issues,
  ) async {
    if (!mounted) return;
    setState(() {
      _fieldErrors = _groupValidationIssues(issues);
      _error = ActividadesService.formatValidationIssues(issues);
    });

    final targetKey = _keyForValidationTarget(issues.first.target);
    if (targetKey != null) {
      await _scrollToKey(targetKey);
    }
  }

  Future<void> _submit() async {
    setState(_clearValidationErrors);

    final a = _actividad;
    if (a == null) return;

    final payload = _buildPayload();
    if (_activePhotoCount(a) < 1) {
      await _showValidationIssues(const <ActividadValidationIssue>[
        ActividadValidationIssue(
          target: ActividadValidationTarget.fotos,
          message: 'La actividad debe conservar al menos una foto.',
        ),
      ]);
      return;
    }

    final validationIssues =
        await ActividadesService.validateBeforeSubmitIssues(
          data: payload,
          fotos: List<File>.from(_fotosNuevas),
          requirePhotos: false,
          requireCoords: false,
        );
    if (!mounted) return;
    if (validationIssues.isNotEmpty) {
      await _showValidationIssues(validationIssues);
      return;
    }

    if (!mounted) return;
    final confirmedCounts = await ActividadPeopleCountGuard.confirmIfNeeded(
      context,
      payload,
    );
    if (!confirmedCounts || !mounted) return;

    if (_saving) return;
    setState(() => _saving = true);

    try {
      final result = await ActividadesService.update(
        id: a.id,
        data: payload,
        fotos: List<File>.from(_fotosNuevas),
        eliminarFotos: _fotoIdsEliminar.toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = {};
        _error =
            'No se pudo actualizar.\n${ActividadesService.cleanExceptionMessage(e)}';
      });
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
      setState(() {
        _actividad = updated;
        _removeFieldError(ActividadValidationTarget.vehiculos);
      });
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

  InputDecoration _dec(
    String label, {
    String? hint,
    ActividadValidationTarget? validationTarget,
  }) {
    final errorText = validationTarget == null
        ? null
        : _fieldError(validationTarget);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      errorMaxLines: 4,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 3),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    ActividadValidationTarget? validationTarget,
    Key? fieldKey,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      onChanged: validationTarget == null
          ? null
          : (_) => _clearFieldError(validationTarget),
      decoration: _dec(label, hint: hint, validationTarget: validationTarget),
    );
  }

  Widget _photosEditor(Actividad a) {
    final existingFotos = a.fotos;
    final hasLegacyPhoto = existingFotos.isEmpty && a.allPhotoPaths.isNotEmpty;
    final totalVisible =
        existingFotos.length + (hasLegacyPhoto ? 1 : 0) + _fotosNuevas.length;

    if (totalVisible == 0) {
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

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      children: [
        if (hasLegacyPhoto) _legacyPhotoTile(a.allPhotoPaths.first),
        ...existingFotos.map(_existingPhotoTile),
        ..._fotosNuevas.asMap().entries.map((entry) {
          return _newPhotoTile(entry.key, entry.value);
        }),
      ],
    );
  }

  Widget _legacyPhotoTile(String path) {
    final url = ActividadesService.toPublicUrl(path);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
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
    );
  }

  Widget _existingPhotoTile(ActividadFoto foto) {
    final marked = _fotoIdsEliminar.contains(foto.id);
    final path = foto.fotoPreviewPath ?? foto.fotoPath ?? '';
    final url = ActividadesService.toPublicUrl(path);

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SafeNetworkImage(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Center(child: Text('No se pudo cargar.')),
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
        ),
        if (marked)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .58),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Se quitara',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        Positioned(
          right: 8,
          top: 8,
          child: InkWell(
            onTap: _saving
                ? null
                : () {
                    setState(() {
                      if (marked) {
                        _fotoIdsEliminar.remove(foto.id);
                      } else {
                        _fotoIdsEliminar.add(foto.id);
                      }
                      final current = _actividad;
                      if (current != null && _activePhotoCount(current) > 0) {
                        _removeFieldError(ActividadValidationTarget.fotos);
                      }
                    });
                  },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .64),
                shape: BoxShape.circle,
              ),
              child: Icon(
                marked ? Icons.undo : Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _newPhotoTile(int index, File file) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(file, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: .88),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Nueva',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: InkWell(
            onTap: _saving
                ? null
                : () => setState(() {
                    _fotosNuevas.removeAt(index);
                    final current = _actividad;
                    if (current != null && _activePhotoCount(current) > 0) {
                      _removeFieldError(ActividadValidationTarget.fotos);
                    }
                  }),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .64),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
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
                      key: _categoriaFieldKey,
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
                          _fomentoProgramaId = null;
                          _subcategorias = [];
                          _removeFieldError(
                            ActividadValidationTarget.categoria,
                          );
                          _removeFieldError(
                            ActividadValidationTarget.subcategoria,
                          );
                        });
                        _syncFomentoTotal();
                        if (v != null) {
                          await _loadSubcategorias(v);
                        }
                      },
                      decoration: _dec(
                        'Categoria',
                        validationTarget: ActividadValidationTarget.categoria,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: _subcategoriaFieldKey,
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
                          : (v) => setState(() {
                              _subcategoriaId = v;
                              _fomentoProgramaId = null;
                              _removeFieldError(
                                ActividadValidationTarget.subcategoria,
                              );
                              _syncFomentoTotal();
                            }),
                      decoration: _dec(
                        'Subcategoria',
                        validationTarget:
                            ActividadValidationTarget.subcategoria,
                      ),
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
                            readOnly: !_canEditCaptureTimestamp,
                            validationTarget: ActividadValidationTarget.fecha,
                            fieldKey: _fechaFieldKey,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _textField(
                            _horaCtrl,
                            'Hora',
                            hint: 'HH:mm',
                            readOnly: !_canEditCaptureTimestamp,
                            validationTarget: ActividadValidationTarget.hora,
                            fieldKey: _horaFieldKey,
                          ),
                        ),
                      ],
                    ),
                    if (!_canEditCaptureTimestamp) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Solo Administrador y Superadmin pueden modificar fecha u hora.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _textField(
                      _lugarCtrl,
                      'Lugar',
                      validationTarget: ActividadValidationTarget.lugar,
                      fieldKey: _lugarFieldKey,
                    ),
                    const SizedBox(height: 12),
                    MunicipioAutocompleteField(
                      key: _municipioFieldKey,
                      controller: _municipioCtrl,
                      decoration: _dec(
                        'Municipio',
                        validationTarget: ActividadValidationTarget.municipio,
                      ),
                      enabled: !_saving,
                      onChanged: (_) =>
                          _clearFieldError(ActividadValidationTarget.municipio),
                      onSelected: (_) =>
                          _clearFieldError(ActividadValidationTarget.municipio),
                    ),
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
                            validationTarget:
                                ActividadValidationTarget.ubicacion,
                            fieldKey: _latFieldKey,
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
                            validationTarget:
                                ActividadValidationTarget.ubicacion,
                            fieldKey: _lngFieldKey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _textField(_coordenadasCtrl, 'Coordenadas texto'),
                    const SizedBox(height: 12),
                    _textField(
                      _fuenteUbicacionCtrl,
                      'Fuente de ubicacion',
                      validationTarget:
                          ActividadValidationTarget.fuenteUbicacion,
                      fieldKey: _fuenteUbicacionFieldKey,
                    ),
                    const SizedBox(height: 12),
                    _textField(
                      _notaGeoCtrl,
                      'Nota geo',
                      validationTarget: ActividadValidationTarget.notaGeo,
                      fieldKey: _notaGeoFieldKey,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              if (_showFomentoPanel) ...[
                _card(
                  title: 'Fomento a la Cultura Vial',
                  cardKey: _fomentoCardKey,
                  validationTarget: ActividadValidationTarget.fomento,
                  child: FomentoCulturaVialPanel(
                    programas: _fomentoProgramas,
                    programaId: _fomentoProgramaId,
                    onProgramaChanged: (value) {
                      setState(() => _fomentoProgramaId = value);
                    },
                    escuelaController: _fomentoEscuelaCtrl,
                    domicilioController: _fomentoDomicilioCtrl,
                    onTextChanged: (_) {
                      _clearFieldError(ActividadValidationTarget.fomento);
                    },
                    nivelEducativo: _fomentoNivelEducativo,
                    onNivelEducativoChanged: (value) {
                      setState(() => _fomentoNivelEducativo = value);
                    },
                    sector: _fomentoSector,
                    onSectorChanged: (value) {
                      setState(() => _fomentoSector = value);
                    },
                    countControllers: _fomentoCountControllers,
                    totalController: _fomentoTotalCtrl,
                    onCountChanged: (_) {
                      _syncFomentoTotal();
                      _clearFieldError(ActividadValidationTarget.fomento);
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],

              _card(
                title: 'Contenido',
                child: Column(
                  children: [
                    if (!_useFomentoUserLayout) ...[
                      _textField(_motivoCtrl, 'Asunto', maxLines: 2),
                      const SizedBox(height: 12),
                    ],
                    _textField(_narrativaCtrl, 'Narrativa', maxLines: 6),
                    if (_useFomentoUserLayout) ...[
                      const SizedBox(height: 12),
                      _textField(
                        _observacionesCtrl,
                        'Observaciones',
                        maxLines: 3,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _card(
                title: 'Totales y participantes',
                child: Column(
                  children: [
                    if (!_useFomentoUserLayout)
                      Row(
                        children: [
                          Expanded(
                            child: KeyedSubtree(
                              key: _personasAlcanzadasFieldKey,
                              child: ActividadCountField(
                                controller: _personasAlcanzadasCtrl,
                                label: 'Personas alcanzadas *',
                                icon: Icons.diversity_3_rounded,
                                color: const Color(0xFF0284C7),
                                helperText: _showFomentoPanel
                                    ? 'Se actualiza con el total de Fomento'
                                    : 'Minimo 1',
                                errorText: _fieldError(
                                  ActividadValidationTarget.personasAlcanzadas,
                                ),
                                onChanged: (_) => _clearFieldError(
                                  ActividadValidationTarget.personasAlcanzadas,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: KeyedSubtree(
                              key: _personasParticipantesFieldKey,
                              child: ActividadCountField(
                                controller: _personasParticipantesCtrl,
                                label: 'Personas participantes',
                                icon: Icons.groups_2_rounded,
                                color: const Color(0xFF7C3AED),
                                helperText: 'Maximo 15 por actividad',
                                badgeText: 'MAX 15',
                                max: ActividadesService.maxParticipantsCount,
                                errorText: _fieldError(
                                  ActividadValidationTarget
                                      .personasParticipantes,
                                ),
                                onChanged: (_) => _clearFieldError(
                                  ActividadValidationTarget
                                      .personasParticipantes,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: KeyedSubtree(
                              key: _personasParticipantesFieldKey,
                              child: ActividadCountField(
                                controller: _personasParticipantesCtrl,
                                label: 'Personas participantes',
                                icon: Icons.groups_2_rounded,
                                color: const Color(0xFF7C3AED),
                                helperText: 'Maximo 15 por actividad',
                                badgeText: 'MAX 15',
                                max: ActividadesService.maxParticipantsCount,
                                errorText: _fieldError(
                                  ActividadValidationTarget
                                      .personasParticipantes,
                                ),
                                onChanged: (_) => _clearFieldError(
                                  ActividadValidationTarget
                                      .personasParticipantes,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: KeyedSubtree(
                              key: _personasDetenidasFieldKey,
                              child: ActividadDetenidosField(
                                controller: _personasDetenidasCtrl,
                                errorText: _fieldError(
                                  ActividadValidationTarget.personasDetenidas,
                                ),
                                onChanged: (_) => _clearFieldError(
                                  ActividadValidationTarget.personasDetenidas,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (!_useFomentoUserLayout) ...[
                      const SizedBox(height: 12),
                      KeyedSubtree(
                        key: _personasDetenidasFieldKey,
                        child: ActividadDetenidosField(
                          controller: _personasDetenidasCtrl,
                          errorText: _fieldError(
                            ActividadValidationTarget.personasDetenidas,
                          ),
                          onChanged: (_) => _clearFieldError(
                            ActividadValidationTarget.personasDetenidas,
                          ),
                        ),
                      ),
                    ],
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

              if (!_useFomentoUserLayout) ...[
                _card(
                  title: 'Vehiculos relacionados',
                  cardKey: _vehiculosCardKey,
                  validationTarget: ActividadValidationTarget.vehiculos,
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
              ],

              _card(
                title: 'Fotos',
                cardKey: _fotosCardKey,
                validationTarget: ActividadValidationTarget.fotos,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_activePhotoCount(a)} foto(s) activas',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 10),
                    _photosEditor(a),
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
                    : const Text('Guardar cambios'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required Widget child,
    Key? cardKey,
    ActividadValidationTarget? validationTarget,
  }) {
    final errorText = validationTarget == null
        ? null
        : _fieldError(validationTarget);
    final hasError = errorText != null;
    return Container(
      key: cardKey,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasError ? Colors.red : Colors.grey.shade200,
          width: hasError ? 2 : 1,
        ),
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
            if (hasError) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorText,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
