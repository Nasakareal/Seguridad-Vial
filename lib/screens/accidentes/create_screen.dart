import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../models/hecho_form_data.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/hechos_form_service.dart';
import 'widgets/hecho_form.dart';

enum _PendingHechoAction { continueCapture, close }

class CreateHechoScreen extends StatefulWidget {
  const CreateHechoScreen({super.key});

  @override
  State<CreateHechoScreen> createState() => _CreateHechoScreenState();
}

class _CreateHechoScreenState extends State<CreateHechoScreen> {
  final HechoFormData _data = HechoFormData();
  File? _initialFotoLugar;
  File? _initialFotoSituacion;
  bool _draftHydrated = false;
  bool _usingOfflineDraft = false;
  bool _checkingAccess = true;
  bool _canCreateHechos = false;
  bool _needsDelegacionesCaptureTotals = false;
  bool _captureTotalsReady = false;
  bool _captureTotalsPromptScheduled = false;
  bool _captureTotalsDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    final canCreate = await AuthService.canCreateHechos(refresh: true);
    final needsCaptureTotals =
        canCreate && await AuthService.isDelegacionesUser();
    if (!mounted) return;
    setState(() {
      _canCreateHechos = canCreate;
      _needsDelegacionesCaptureTotals = needsCaptureTotals;
      _checkingAccess = false;
    });

    if (needsCaptureTotals) {
      _scheduleCaptureTotalsPrompt();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draftHydrated) return;
    _draftHydrated = true;
    _hydrateDraftFromArgs();
  }

  void _hydrateDraftFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map || args['offlineDraft'] is! Map) return;
    _usingOfflineDraft = true;

    final draft = Map<String, dynamic>.from(args['offlineDraft'] as Map);
    final fields = _stringMapFrom(draft['fields']);
    final files = _listMapFrom(draft['files']);

    _data.clientUuid = (draft['id'] ?? '').toString().trim();
    _data.folioC5i = (fields['folio_c5i'] ?? '').trim();
    _data.perito = (fields['perito'] ?? '').trim();
    _data.autorizacionPractico = (fields['autorizacion_practico'] ?? '').trim();
    _data.unidad = (fields['unidad'] ?? '').trim();
    _data.unidadOrgId = (fields['unidad_org_id'] ?? '').trim();
    _data.hora = _parseTime(fields['hora']);
    _data.fecha = _parseDate(fields['fecha']);
    _data.sector = _blankToNull(fields['sector']);
    _data.calle = (fields['calle'] ?? '').trim();
    _data.colonia = (fields['colonia'] ?? '').trim();
    _data.entreCalles = (fields['entre_calles'] ?? '').trim();
    _data.municipio = (fields['municipio'] ?? '').trim();
    _data.tipoHecho = _blankToNull(fields['tipo_hecho']);
    _data.superficieVia = _blankToNull(fields['superficie_via']);
    _data.tiempo = _blankToNull(fields['tiempo']);
    _data.clima = _blankToNull(fields['clima']);
    _data.condiciones = _blankToNull(fields['condiciones']);
    _data.controlTransito = _blankToNull(fields['control_transito']);
    _data.checaronAntecedentes = _isTrue(fields['checaron_antecedentes']);
    _data.causa = _blankToNull(fields['causas']);
    _data.responsable = (fields['responsable'] ?? '').trim();
    _data.colisionCamino = _blankToNull(fields['colision_camino']);
    _data.situacion = _blankToNull(fields['situacion']);
    _data.vehiculosMp = (fields['vehiculos_mp'] ?? '').trim();
    _data.personasMp = (fields['personas_mp'] ?? '').trim();

    final hasCaptureTotals =
        fields.containsKey('vehiculos_esperados') ||
        fields.containsKey('conductores_esperados') ||
        fields.containsKey('lesionados_esperados');
    _data.vehiculosEsperados =
        (fields['vehiculos_esperados'] ?? _data.vehiculosEsperados).trim();
    _data.conductoresEsperados =
        (fields['conductores_esperados'] ?? _data.conductoresEsperados).trim();
    _data.lesionadosEsperados =
        (fields['lesionados_esperados'] ?? _data.lesionadosEsperados).trim();
    if (hasCaptureTotals) {
      _captureTotalsReady = true;
    }

    _data.danosPatrimoniales = _isTrue(fields['danos_patrimoniales']);
    _data.propiedadesAfectadas = (fields['propiedades_afectadas'] ?? '').trim();
    _data.montoDanos = (fields['monto_danos_patrimoniales'] ?? '').trim();
    _data.lat = _parseDouble(fields['lat']);
    _data.lng = _parseDouble(fields['lng']);
    _data.calidadGeo = _blankToNull(fields['calidad_geo']);
    _data.notaGeo = _blankToNull(fields['nota_geo']);
    _data.fuenteUbicacion = _blankToNull(fields['fuente_ubicacion']);
    _data.ubicacionFormateada = _blankToNull(fields['ubicacion_formateada']);
    _data.placeId = _blankToNull(fields['place_id']);
    _data.dictamenId = int.tryParse((fields['dictamen_id'] ?? '').trim());

    _initialFotoLugar = _fileForField(files, 'foto_lugar');
    _initialFotoSituacion = _fileForField(files, 'foto_situacion');
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

  File? _fileForField(List<Map<String, dynamic>> files, String field) {
    for (final item in files) {
      if ((item['field'] ?? '').toString() != field) continue;
      final path = (item['path'] ?? '').toString().trim();
      if (path.isEmpty) return null;
      return File(path);
    }
    return null;
  }

  String? _blankToNull(String? value) {
    final cleaned = (value ?? '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  TimeOfDay? _parseTime(String? value) {
    final raw = (value ?? '').trim();
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  DateTime? _parseDate(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  double? _parseDouble(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  bool _isTrue(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    return raw == '1' || raw == 'true' || raw == 'si' || raw == 'sí';
  }

  void _scheduleCaptureTotalsPrompt() {
    if (_captureTotalsReady ||
        _captureTotalsPromptScheduled ||
        _captureTotalsDialogOpen) {
      return;
    }

    _captureTotalsPromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _captureTotalsPromptScheduled = false;
      if (!mounted ||
          !_needsDelegacionesCaptureTotals ||
          _captureTotalsReady ||
          _captureTotalsDialogOpen) {
        return;
      }

      _captureTotalsDialogOpen = true;
      try {
        final completed = await _showCaptureTotalsDialog();
        if (!mounted) return;

        if (completed != true) {
          Navigator.pop(context);
        }
      } finally {
        _captureTotalsDialogOpen = false;
      }
    });
  }

  Future<bool> _showCaptureTotalsDialog() async {
    final result = await showDialog<_CaptureTotalsInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CaptureTotalsDialog(
        vehiculos: _data.vehiculosEsperados,
        conductores: _data.conductoresEsperados,
        lesionados: _data.lesionadosEsperados,
      ),
    );

    if (result == null) return false;

    _data.vehiculosEsperados = result.vehiculos;
    _data.conductoresEsperados = result.conductores;
    _data.lesionadosEsperados = result.lesionados;
    _captureTotalsReady = true;
    return true;
  }

  Future<void> _handleSubmitted(
    OfflineActionResult result,
    HechoFormData data,
  ) async {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));

    if (!result.queued) {
      final hechoId = HechosFormService.hechoIdFromCreateResult(result);
      if (hechoId != null && hechoId > 0) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.vehiculos,
          arguments: {'hechoId': hechoId},
        );
      } else {
        Navigator.pop(context, true);
      }
      return;
    }

    final clientUuid = data.clientUuid?.trim() ?? '';
    if (clientUuid.isEmpty) {
      Navigator.pop(context, true);
      return;
    }

    final action = await showModalBottomSheet<_PendingHechoAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hecho guardado sin conexión',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ya puedes seguir capturando vehículos y lesionados para este hecho usando el UUID local mientras regresa internet.',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      _PendingHechoAction.continueCapture,
                    ),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Seguir capturando offline'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(sheetContext, _PendingHechoAction.close),
                    child: const Text('Terminar por ahora'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    switch (action) {
      case _PendingHechoAction.continueCapture:
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.pendingHechoCapture,
          arguments: {'hechoClientUuid': clientUuid},
        );
        return;
      case _PendingHechoAction.close:
      case null:
        Navigator.pop(context, true);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    if (_checkingAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Crear Hecho')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_canCreateHechos) {
      return Scaffold(
        appBar: AppBar(title: const Text('Crear Hecho')),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No tienes permiso para crear hechos.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    if (_needsDelegacionesCaptureTotals && !_captureTotalsReady) {
      _scheduleCaptureTotalsPrompt();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Hecho')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomSafe + 18),
        child: HechoForm(
          mode: HechoFormMode.create,
          data: _data,
          initialFotoLugar: _initialFotoLugar,
          initialFotoSituacion: _initialFotoSituacion,
          draftId: _usingOfflineDraft ? null : 'hechos:create',
          onSubmit:
              ({
                required data,
                required dictamenSelected,
                required fotoLugar,
                required fotoSituacion,
              }) {
                return HechosFormService.create(
                  data: data,
                  dictamenSelected: dictamenSelected,
                  fotoLugar: fotoLugar,
                  fotoSituacion: fotoSituacion,
                );
              },
          onSubmitted: _handleSubmitted,
        ),
      ),
    );
  }
}

class _CaptureTotalsInput {
  const _CaptureTotalsInput({
    required this.vehiculos,
    required this.conductores,
    required this.lesionados,
  });

  final String vehiculos;
  final String conductores;
  final String lesionados;
}

class _CaptureTotalsDialog extends StatefulWidget {
  const _CaptureTotalsDialog({
    required this.vehiculos,
    required this.conductores,
    required this.lesionados,
  });

  final String vehiculos;
  final String conductores;
  final String lesionados;

  @override
  State<_CaptureTotalsDialog> createState() => _CaptureTotalsDialogState();
}

class _CaptureTotalsDialogState extends State<_CaptureTotalsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _vehiculosCtrl;
  late final TextEditingController _conductoresCtrl;
  late final TextEditingController _lesionadosCtrl;

  @override
  void initState() {
    super.initState();
    _vehiculosCtrl = TextEditingController(text: widget.vehiculos);
    _conductoresCtrl = TextEditingController(text: widget.conductores);
    _lesionadosCtrl = TextEditingController(text: widget.lesionados);
  }

  @override
  void dispose() {
    _vehiculosCtrl.dispose();
    _conductoresCtrl.dispose();
    _lesionadosCtrl.dispose();
    super.dispose();
  }

  String? _requiredInt(String? value) {
    final text = (value ?? '').trim();
    final parsed = int.tryParse(text);
    if (text.isEmpty || parsed == null) return 'Requerido';
    if (parsed < 0) return 'No puede ser negativo';
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Navigator.pop(
      context,
      _CaptureTotalsInput(
        vehiculos: _vehiculosCtrl.text.trim(),
        conductores: _conductoresCtrl.text.trim(),
        lesionados: _lesionadosCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Participantes del hecho'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Captura estos totales antes de iniciar. Esto ayuda a saber si el hecho ya quedó completo.',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _vehiculosCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Vehículos participantes',
                    prefixIcon: Icon(Icons.directions_car),
                  ),
                  validator: _requiredInt,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _conductoresCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Conductores participantes',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    final base = _requiredInt(value);
                    if (base != null) return base;

                    final vehiculos =
                        int.tryParse(_vehiculosCtrl.text.trim()) ?? 0;
                    final conductores =
                        int.tryParse(_conductoresCtrl.text.trim()) ?? 0;
                    if (conductores > vehiculos) {
                      return 'No puede ser mayor que vehículos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _lesionadosCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Lesionados',
                    prefixIcon: Icon(Icons.personal_injury),
                  ),
                  validator: _requiredInt,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar captura'),
          ),
          ElevatedButton(onPressed: _submit, child: const Text('Continuar')),
        ],
      ),
    );
  }
}
