import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../models/hecho_form_data.dart';
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

  Future<void> _handleSubmitted(
    OfflineActionResult result,
    HechoFormData data,
  ) async {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));

    final clientUuid = data.clientUuid?.trim() ?? '';
    if (!result.queued || clientUuid.isEmpty) {
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

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Hecho')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomSafe + 18),
        child: HechoForm(
          mode: HechoFormMode.create,
          data: _data,
          initialFotoLugar: _initialFotoLugar,
          initialFotoSituacion: _initialFotoSituacion,
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
