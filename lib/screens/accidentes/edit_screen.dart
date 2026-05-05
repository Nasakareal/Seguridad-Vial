import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/routes.dart';
import '../../core/hechos/hechos_catalogos.dart';
import '../../models/hecho_form_data.dart';
import '../../services/auth_service.dart';
import '../../services/hecho_access_service.dart';
import '../../services/hechos_form_service.dart';
import '../../services/hechos_service.dart';
import '../../services/reportes_service.dart';
import 'widgets/hecho_form.dart';

class EditHechoScreen extends StatefulWidget {
  final int hechoId;

  const EditHechoScreen({super.key, required this.hechoId});

  @override
  State<EditHechoScreen> createState() => _EditHechoScreenState();
}

class _EditHechoScreenState extends State<EditHechoScreen> {
  HechoFormData? _data;
  bool _loading = true;
  String? _error;
  HechoEditAccess _editAccess = HechoEditAccess.none;
  bool _downloadingReporte = false;
  bool _canUploadDelegacionesIph = false;
  bool _uploadingIph = false;
  String? _iphArchivoName;

  @override
  void initState() {
    super.initState();
    _loadHecho();
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  bool _asBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'si' || s == 'sí';
  }

  Future<void> _loadEditAccess() async {
    _editAccess = await HechoAccessService.loadEditAccess(refresh: true);
    _canUploadDelegacionesIph = await AuthService.isDelegacionesUser(
      refresh: true,
    );
  }

  bool _puedeEditarHecho(Map<String, dynamic> raw) {
    return _editAccess.canEditHecho(raw);
  }

  TimeOfDay? _parseHora(dynamic v) {
    final s = _asString(v);
    if (s == null) return null;

    final parts = s.split(':');
    if (parts.length < 2) return null;

    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);

    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;

    return TimeOfDay(hour: h, minute: m);
  }

  DateTime? _parseFecha(dynamic v) {
    final s = _asString(v);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  String? _pickMatchingValue(String? raw, List<String> options) {
    if (raw == null) return null;

    final rawNorm = _normalize(raw);
    for (final option in options) {
      if (_normalize(option) == rawNorm) return option;
    }

    return null;
  }

  String _normalize(String s) {
    return s
        .trim()
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N');
  }

  HechoFormData _mapHecho(Map<String, dynamic> raw) {
    final d = HechoFormData();

    d.clientUuid = _asString(raw['client_uuid']);
    d.folioC5i = _asString(raw['folio_c5i']) ?? '';
    d.perito = _asString(raw['perito']) ?? '';
    d.autorizacionPractico = _asString(raw['autorizacion_practico']) ?? '';
    d.unidad = _asString(raw['unidad']) ?? '';
    d.unidadOrgId = _asString(raw['unidad_org_id']) ?? '';

    d.hora = _parseHora(raw['hora']);
    d.fecha = _parseFecha(raw['fecha']);

    d.sector = _pickMatchingValue(
      _asString(raw['sector']),
      HechosCatalogos.sectoresUi,
    );

    d.calle = _asString(raw['calle']) ?? '';
    d.colonia = _asString(raw['colonia']) ?? '';
    d.entreCalles = _asString(raw['entre_calles']) ?? '';
    d.municipio = _asString(raw['municipio']) ?? '';

    d.tipoHecho = _pickMatchingValue(
      _asString(raw['tipo_hecho']),
      HechosCatalogos.tiposHecho,
    );

    d.superficieVia = _pickMatchingValue(
      _asString(raw['superficie_via']),
      HechosCatalogos.superficiesViaUi,
    );

    d.tiempo = _pickMatchingValue(
      _asString(raw['tiempo']),
      HechosCatalogos.tiemposUi,
    );

    d.clima = _pickMatchingValue(
      _asString(raw['clima']),
      HechosCatalogos.climasUi,
    );

    d.condiciones = _pickMatchingValue(
      _asString(raw['condiciones']),
      HechosCatalogos.condicionesUi,
    );

    d.controlTransito = _pickMatchingValue(
      _asString(raw['control_transito']),
      HechosCatalogos.controlesTransitoUi,
    );

    d.checaronAntecedentes = _asBool(raw['checaron_antecedentes']);

    d.causa = _pickMatchingValue(
      _asString(raw['causas']),
      HechosCatalogos.causasUi,
    );

    d.responsable =
        _pickMatchingValue(
          _asString(raw['responsable']),
          HechosCatalogos.responsablesUi,
        ) ??
        (_asString(raw['responsable']) ?? '');

    d.colisionCamino = _pickMatchingValue(
      _asString(raw['colision_camino']),
      HechosCatalogos.colisionCaminoUi,
    );

    d.situacion = _pickMatchingValue(
      _asString(raw['situacion']),
      HechosCatalogos.situaciones,
    );

    d.vehiculosMp = _asString(raw['vehiculos_mp']) ?? '0';
    d.personasMp = _asString(raw['personas_mp']) ?? '0';
    d.vehiculosEsperados = _asString(raw['vehiculos_esperados']) ?? '0';
    d.conductoresEsperados = _asString(raw['conductores_esperados']) ?? '0';
    d.lesionadosEsperados = _asString(raw['lesionados_esperados']) ?? '0';

    d.danosPatrimoniales = _asBool(raw['danos_patrimoniales']);
    d.propiedadesAfectadas = _asString(raw['propiedades_afectadas']) ?? '';
    d.montoDanos = _asString(raw['monto_danos_patrimoniales']) ?? '';

    d.lat = _asDouble(raw['lat']);
    d.lng = _asDouble(raw['lng']);
    d.calidadGeo = _asString(raw['calidad_geo']);
    d.notaGeo = _asString(raw['nota_geo']);
    d.fuenteUbicacion = _asString(raw['fuente_ubicacion']);
    d.ubicacionFormateada = _asString(raw['ubicacion_formateada']);
    d.placeId = _asString(raw['place_id']);

    d.dictamenId = _asInt(raw['dictamen_id']);
    d.hasFotoSituacionActual =
        (_asString(raw['foto_situacion']) ?? '').isNotEmpty ||
        (_asString(raw['foto_situacion_url']) ?? '').isNotEmpty;

    return d;
  }

  bool _esTurnadoActual() {
    final situacion = (_data?.situacion ?? '').trim().toUpperCase();
    return situacion == 'TURNADO';
  }

  String? _iphArchivoUrlFromRaw(Map<String, dynamic> raw) {
    final direct =
        _asString(raw['iph_delegaciones_url']) ??
        _asString(raw['descargo_url']);
    if (direct != null) return direct;

    return null;
  }

  String? _iphArchivoNameFromRaw(Map<String, dynamic> raw) {
    final direct =
        _asString(raw['iph_delegaciones_path']) ??
        _asString(raw['descargo_path']) ??
        _asString(raw['archivo_iph']);
    if (direct != null) return p.basename(direct);

    final url = _iphArchivoUrlFromRaw(raw);
    if (url == null) return null;

    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments;
    if (segments != null && segments.isNotEmpty) {
      return segments.last;
    }

    return p.basename(url);
  }

  Future<void> _subirIphDelegacion() async {
    if (_uploadingIph) return;

    final data = _data;
    if (data == null) return;

    if (!_esTurnadoActual()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guarda el hecho como TURNADO antes de subir el PDF.'),
        ),
      );
      return;
    }

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: false,
        withData: false,
      );

      if (picked == null || picked.files.isEmpty) return;

      final path = picked.files.single.path;
      if (path == null || path.trim().isEmpty) {
        throw Exception('No se pudo leer la ruta del PDF seleccionado.');
      }

      final file = File(path);
      if (!await file.exists()) {
        throw Exception('No se encontró el PDF seleccionado.');
      }

      final size = await file.length();
      if (size > 10 * 1024 * 1024) {
        throw Exception('El PDF es muy pesado (máximo 10 MB).');
      }

      if (!mounted) return;
      setState(() => _uploadingIph = true);

      final res = await HechosService.uploadIphDelegacion(
        hechoId: widget.hechoId,
        archivoPdf: file,
        nombrePolicia: data.perito,
      );

      final raw = res['data'];
      if (raw is Map) {
        final mappedRaw = Map<String, dynamic>.from(raw);
        setState(() {
          _data = _mapHecho(mappedRaw);
          _iphArchivoName = _iphArchivoNameFromRaw(mappedRaw);
        });
      } else {
        await _loadHecho();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IPH PDF subido correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = HechosFormService.cleanExceptionMessage(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _uploadingIph = false);
    }
  }

  Future<void> _loadHecho() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadEditAccess();
      final raw = await HechosService.fetchById(widget.hechoId);
      if (!_puedeEditarHecho(raw)) {
        if (!mounted) return;
        setState(() {
          _data = null;
          _error = 'No tienes permiso para editar este hecho.';
          _loading = false;
        });
        return;
      }

      final mapped = _mapHecho(raw);

      if (!mounted) return;
      setState(() {
        _data = mapped;
        _iphArchivoName = _iphArchivoNameFromRaw(raw);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el hecho: $e';
        _loading = false;
      });
    }
  }

  Future<void> _irVehiculos() async {
    await Navigator.pushNamed(
      context,
      '/accidentes/vehiculos',
      arguments: {'hechoId': widget.hechoId},
    );

    if (!mounted) return;
    await _loadHecho();
  }

  Future<void> _irLesionados() async {
    await Navigator.pushNamed(
      context,
      AppRoutes.lesionados,
      arguments: {'hechoId': widget.hechoId},
    );

    if (!mounted) return;
    await _loadHecho();
  }

  Future<void> _irCroquis() async {
    await Navigator.pushNamed(
      context,
      AppRoutes.accidentesCroquis,
      arguments: {'hechoId': widget.hechoId},
    );

    if (!mounted) return;
    await _loadHecho();
  }

  Future<void> _irDescargo() async {
    if (_downloadingReporte) return;

    setState(() => _downloadingReporte = true);

    try {
      await ReporteHechoService.descargarYCompartirHecho(
        hechoId: widget.hechoId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe guardado y listo para compartir'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('No se pudo descargar el reporte.\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _downloadingReporte = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final puedeSubirIph = _canUploadDelegacionesIph && _esTurnadoActual();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Hecho'),
        actions: [
          IconButton(
            tooltip: 'Vehículos',
            onPressed: _loading || _data == null ? null : _irVehiculos,
            icon: const Icon(Icons.directions_car),
          ),
          IconButton(
            tooltip: 'Recargar',
            onPressed: _loading ? null : _loadHecho,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadHecho,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomSafe + 18),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _irVehiculos,
                                  icon: const Icon(Icons.directions_car),
                                  label: const Text('Vehículos'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _irLesionados,
                                  icon: const Icon(Icons.personal_injury),
                                  label: const Text('Lesionados'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _irCroquis,
                                  icon: const Icon(Icons.draw),
                                  label: const Text('Croquis'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _downloadingReporte
                                      ? null
                                      : _irDescargo,
                                  icon: _downloadingReporte
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.upload_file),
                                  label: const Text('Descargo'),
                                ),
                              ),
                            ],
                          ),
                          if (puedeSubirIph) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _uploadingIph
                                    ? null
                                    : _subirIphDelegacion,
                                icon: _uploadingIph
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.picture_as_pdf),
                                label: Text(
                                  _iphArchivoName == null
                                      ? 'Subir IPH PDF'
                                      : 'Reemplazar IPH PDF',
                                ),
                              ),
                            ),
                            if (_iphArchivoName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _iphArchivoName!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  HechoForm(
                    mode: HechoFormMode.edit,
                    data: _data!,
                    draftId: 'hechos:edit:${widget.hechoId}',
                    onSubmit:
                        ({
                          required data,
                          required dictamenSelected,
                          required fotoLugar,
                          required fotoSituacion,
                        }) {
                          return HechosFormService.update(
                            hechoId: widget.hechoId,
                            data: data,
                            dictamenSelected: dictamenSelected,
                            fotoLugar: fotoLugar,
                            fotoSituacion: fotoSituacion,
                          );
                        },
                    onSubmitted: _canUploadDelegacionesIph
                        ? (result, data) async {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message)),
                            );
                            await _loadHecho();
                          }
                        : null,
                  ),
                ],
              ),
            ),
    );
  }
}
