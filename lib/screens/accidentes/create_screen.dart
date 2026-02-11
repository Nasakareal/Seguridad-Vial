import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/auth_service.dart';

class CreateHechoScreen extends StatefulWidget {
  const CreateHechoScreen({super.key});

  @override
  State<CreateHechoScreen> createState() => _CreateHechoScreenState();
}

class _CreateHechoScreenState extends State<CreateHechoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  final _folioCtrl = TextEditingController();
  final _peritoCtrl = TextEditingController();
  final _authPracCtrl = TextEditingController();
  final _unidadCtrl = TextEditingController();

  final _unidadOrgIdCtrl = TextEditingController();

  TimeOfDay? _hora;
  DateTime? _fecha;
  String? _sector;

  final _calleCtrl = TextEditingController();
  final _coloniaCtrl = TextEditingController();
  final _entreCallesCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController();

  String? _tipoHecho;
  final _superficieCtrl = TextEditingController();
  String? _tiempo;
  String? _clima;
  String? _condiciones;

  final _controlTxCtrl = TextEditingController();
  bool _checaronAnt = false;

  final _causasCtrl = TextEditingController();
  final _colisionCtrl = TextEditingController();

  String? _situacion;

  final _oficioMpCtrl = TextEditingController();
  final _vehMpCtrl = TextEditingController(text: '0');
  final _persMpCtrl = TextEditingController(text: '0');

  // ✅ NUEVO: DAÑOS PATRIMONIALES (VAN EN HECHOS)
  bool _danosPatrimoniales = false;
  final _propiedadesAfectadasCtrl = TextEditingController();
  final _montoDanosCtrl = TextEditingController();

  final _picker = ImagePicker();
  File? _fotoLugar;
  File? _fotoSituacion;

  double? _lat;
  double? _lng;
  String? _calidadGeo;
  String? _notaGeo;
  String? _fuenteUbicacion;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacionInicial();
  }

  @override
  void dispose() {
    _folioCtrl.dispose();
    _peritoCtrl.dispose();
    _authPracCtrl.dispose();
    _unidadCtrl.dispose();
    _unidadOrgIdCtrl.dispose();

    _calleCtrl.dispose();
    _coloniaCtrl.dispose();
    _entreCallesCtrl.dispose();
    _municipioCtrl.dispose();

    _superficieCtrl.dispose();
    _controlTxCtrl.dispose();
    _causasCtrl.dispose();
    _colisionCtrl.dispose();

    _oficioMpCtrl.dispose();
    _vehMpCtrl.dispose();
    _persMpCtrl.dispose();

    // ✅ daños
    _propiedadesAfectadasCtrl.dispose();
    _montoDanosCtrl.dispose();

    super.dispose();
  }

  Future<void> _pickHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) setState(() => _hora = picked);
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _fecha = picked);
  }

  String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _horaStr(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _parseBackendError(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);

      if (raw is Map<String, dynamic>) {
        if (raw['message'] is String) {
          final msg = (raw['message'] as String).trim();
          if (msg.isNotEmpty) return msg;
        }

        final errors = raw['errors'];
        if (errors is Map) {
          final sb = StringBuffer();
          errors.forEach((k, v) {
            if (v is List && v.isNotEmpty) {
              sb.writeln('• ${v.first}');
            }
          });
          final out = sb.toString().trim();
          if (out.isNotEmpty) return out;
        }
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }

  Future<void> _pickPhoto({required bool isLugar}) async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;

    final f = File(x.path);
    if (!mounted) return;

    setState(() {
      if (isLugar) {
        _fotoLugar = f;
      } else {
        _fotoSituacion = f;
      }
    });
  }

  Widget _photoPreview({
    required String title,
    required File? file,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (file == null)
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text('Sin imagen'),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image.file(file, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : onPick,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Elegir'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_submitting || file == null) ? null : onClear,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Quitar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _obtenerUbicacionInicial() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _lat = null;
          _lng = null;
          _calidadGeo = 'OFF';
          _notaGeo = 'GPS desactivado';
          _fuenteUbicacion = null;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _lat = null;
          _lng = null;
          _calidadGeo = 'DENIED';
          _notaGeo = 'Permiso de ubicación denegado';
          _fuenteUbicacion = null;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;

        final acc = pos.accuracy;
        _calidadGeo = acc.isFinite ? acc.toStringAsFixed(1) : null;

        _notaGeo = 'ACC:${_calidadGeo ?? ''}';
        _fuenteUbicacion = 'GPS_APP';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lat = null;
        _lng = null;
        _calidadGeo = 'ERR';
        _notaGeo = 'Error GPS: $e';
        _fuenteUbicacion = null;
      });
    }
  }

  Future<void> _refrescarUbicacion() async {
    await _obtenerUbicacionInicial();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (_lat != null && _lng != null)
              ? 'Ubicación lista: $_lat, $_lng'
              : 'No se pudo obtener ubicación',
        ),
      ),
    );
  }

  Widget _ubicacionCard() {
    final has = _lat != null && _lng != null;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ubicación (GPS)',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              has
                  ? 'Lat: $_lat\nLng: $_lng\nCalidad: ${_calidadGeo ?? '-'}'
                  : 'Sin ubicación (revisa GPS/permisos)',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _refrescarUbicacion,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Obtener ubicación'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_submitting || !has)
                        ? null
                        : () {
                            setState(() {
                              _lat = null;
                              _lng = null;
                              _calidadGeo = null;
                              _notaGeo = null;
                              _fuenteUbicacion = null;
                            });
                          },
                    icon: const Icon(Icons.clear),
                    label: const Text('Quitar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NUEVO: tarjeta de daños patrimoniales (en Hechos)
  Widget _danosPatrimonialesCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daños patrimoniales',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('¿Hubo daños patrimoniales?'),
              value: _danosPatrimoniales,
              onChanged: _submitting
                  ? null
                  : (v) {
                      setState(() {
                        _danosPatrimoniales = v;
                        if (!v) {
                          _propiedadesAfectadasCtrl.clear();
                          _montoDanosCtrl.clear();
                        }
                      });
                    },
            ),
            if (_danosPatrimoniales) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _propiedadesAfectadasCtrl,
                decoration: _dec('Propiedades afectadas (opcional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _montoDanosCtrl,
                decoration: _dec('Monto daños patrimoniales (opcional)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (!_danosPatrimoniales) return null;
                  final txt = (v ?? '').trim();
                  if (txt.isEmpty) return null; // opcional
                  final val = double.tryParse(txt.replaceAll(',', ''));
                  if (val == null) return 'Monto inválido';
                  if (val < 0) return 'No puede ser negativo';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Si está activado, captura el monto o describe las propiedades.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_hora == null ||
        _fecha == null ||
        _sector == null ||
        _tipoHecho == null ||
        _tiempo == null ||
        _clima == null ||
        _condiciones == null ||
        _situacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos obligatorios')),
      );
      return;
    }

    if (_situacion == 'TURNADO' && _oficioMpCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oficio MP es requerido cuando es TURNADO'),
        ),
      );
      return;
    }

    // ✅ ya no forzamos GPS obligatorio (el backend permite NULL)
    // Solo validamos par: o vienen las 2 o ninguna (aquí ya lo mantienes con tu UI)
    final hasCoords = _lat != null && _lng != null;

    // ✅ daños patrimoniales: si está activado, debe venir monto o propiedades
    if (_danosPatrimoniales) {
      final props = _propiedadesAfectadasCtrl.text.trim();
      final montoTxt = _montoDanosCtrl.text.trim();
      final hasMonto = montoTxt.isNotEmpty;
      final hasProps = props.isNotEmpty;
      if (!hasMonto && !hasProps) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Si hay daños patrimoniales, captura el monto o describe las propiedades afectadas.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _submitting = true);

    try {
      final token = await AuthService.getToken();

      final uri = Uri.parse('${AuthService.baseUrl}/hechos');
      final req = http.MultipartRequest('POST', uri);

      req.headers['Accept'] = 'application/json';
      if (token != null && token.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $token';
      }

      req.fields['folio_c5i'] = _folioCtrl.text.trim();
      req.fields['perito'] = _peritoCtrl.text.trim();
      req.fields['autorizacion_practico'] = _authPracCtrl.text.trim();
      req.fields['unidad'] = _unidadCtrl.text.trim();

      final unidadOrg = _unidadOrgIdCtrl.text.trim();
      if (unidadOrg.isNotEmpty) {
        req.fields['unidad_org_id'] = unidadOrg;
      }

      req.fields['hora'] = _horaStr(_hora!);
      req.fields['fecha'] = _ymd(_fecha!);

      // ✅ mandar valores que el backend espera (sin acentos)
      req.fields['sector'] = _normalizeSector(_sector!);

      req.fields['calle'] = _calleCtrl.text.trim();
      req.fields['colonia'] = _coloniaCtrl.text.trim();
      req.fields['entre_calles'] = _entreCallesCtrl.text.trim();
      req.fields['municipio'] = _municipioCtrl.text.trim();

      // ✅ tipo hecho: el backend lo normaliza en mayúsculas; mandamos tal cual
      req.fields['tipo_hecho'] = _tipoHecho ?? '';
      req.fields['superficie_via'] = _superficieCtrl.text.trim();

      // ✅ mandar sin acentos (para que calce con Rule::in)
      req.fields['tiempo'] = _normalizeTiempo(_tiempo!);
      req.fields['clima'] = _normalizeClima(_clima!);
      req.fields['condiciones'] = _normalizeCondiciones(_condiciones!);

      req.fields['control_transito'] = _controlTxCtrl.text.trim();
      req.fields['checaron_antecedentes'] = _checaronAnt ? '1' : '0';

      req.fields['causas'] = _causasCtrl.text.trim();
      req.fields['colision_camino'] = _colisionCtrl.text.trim();

      req.fields['situacion'] = _situacion ?? '';
      req.fields['oficio_mp'] = (_situacion == 'TURNADO')
          ? _oficioMpCtrl.text.trim()
          : '';
      req.fields['vehiculos_mp'] = _vehMpCtrl.text.trim();
      req.fields['personas_mp'] = _persMpCtrl.text.trim();

      // ✅ DAÑOS PATRIMONIALES (EN HECHOS)
      req.fields['danos_patrimoniales'] = _danosPatrimoniales ? '1' : '0';
      if (_danosPatrimoniales) {
        final props = _propiedadesAfectadasCtrl.text.trim();
        final montoTxt = _montoDanosCtrl.text.trim();

        if (props.isNotEmpty) {
          req.fields['propiedades_afectadas'] = props;
        }
        if (montoTxt.isNotEmpty) {
          // por si ponen comas
          req.fields['monto_danos_patrimoniales'] = montoTxt.replaceAll(
            ',',
            '',
          );
        }
      }

      // ✅ ubicación opcional (pero si viene, mandamos las dos)
      if (hasCoords) {
        req.fields['lat'] = _lat!.toStringAsFixed(7);
        req.fields['lng'] = _lng!.toStringAsFixed(7);

        if ((_calidadGeo ?? '').trim().isNotEmpty) {
          req.fields['calidad_geo'] = _calidadGeo!.trim();
        }
        if ((_notaGeo ?? '').trim().isNotEmpty) {
          req.fields['nota_geo'] = _notaGeo!.trim();
        }
        if ((_fuenteUbicacion ?? '').trim().isNotEmpty) {
          req.fields['fuente_ubicacion'] = _fuenteUbicacion!.trim();
        }
      }

      if (_fotoLugar != null) {
        req.files.add(
          await http.MultipartFile.fromPath('foto_lugar', _fotoLugar!.path),
        );
      }
      if (_fotoSituacion != null) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'foto_situacion',
            _fotoSituacion!.path,
          ),
        );
      }

      final streamed = await req.send();
      final respBody = await streamed.stream.bytesToString();

      if (streamed.statusCode == 201 || streamed.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      if (streamed.statusCode == 422) {
        final msg = _parseBackendError(respBody, streamed.statusCode);
        throw Exception(msg);
      }

      throw Exception('HTTP ${streamed.statusCode}: $respBody');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fallo al crear: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _dec(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());

  // ✅ helpers para enviar lo que el backend espera (Rule::in)
  String _normalizeSector(String v) {
    final x = v.trim().toUpperCase();
    switch (x) {
      case 'REVOLUCIÓN':
      case 'REVOLUCION':
        return 'REVOLUCION';
      case 'NUEVA ESPAÑA':
      case 'NUEVA ESPANA':
        return 'NUEVA ESPANA';
      case 'REPÚBLICA':
      case 'REPUBLICA':
        return 'REPUBLICA';
      case 'INDEPENDENCIA':
        return 'INDEPENDENCIA';
      case 'CENTRO':
        return 'CENTRO';
      default:
        // fallback: quita acentos rápido
        return _removeAccents(x);
    }
  }

  String _normalizeTiempo(String v) {
    final x = _removeAccents(v.trim().toUpperCase());
    // en UI vienen Día/Noche/Amanecer/Atardecer
    if (x == 'DIA') return 'DIA';
    if (x == 'NOCHE') return 'NOCHE';
    if (x == 'AMANECER') return 'AMANECER';
    if (x == 'ATARDECER') return 'ATARDECER';
    return x;
  }

  String _normalizeClima(String v) {
    final x = _removeAccents(v.trim().toUpperCase());
    if (x == 'BUENO') return 'BUENO';
    if (x == 'MALO') return 'MALO';
    if (x == 'NUBLADO') return 'NUBLADO';
    if (x == 'LLUVIOSO') return 'LLUVIOSO';
    return x;
  }

  String _normalizeCondiciones(String v) {
    final x = _removeAccents(v.trim().toUpperCase());
    if (x == 'BUENO') return 'BUENO';
    if (x == 'REGULAR') return 'REGULAR';
    if (x == 'MALO') return 'MALO';
    return x;
  }

  String _removeAccents(String s) {
    const map = {
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'À': 'A',
      'È': 'E',
      'Ì': 'I',
      'Ò': 'O',
      'Ù': 'U',
      'Â': 'A',
      'Ê': 'E',
      'Î': 'I',
      'Ô': 'O',
      'Û': 'U',
      'Ä': 'A',
      'Ë': 'E',
      'Ï': 'I',
      'Ö': 'O',
      'Ü': 'U',
      'Ñ': 'N',
      'Ç': 'C',
    };
    final up = s.toUpperCase();
    final sb = StringBuffer();
    for (final ch in up.split('')) {
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Hecho')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomSafe + 18),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _ubicacionCard(),

              const SizedBox(height: 12),

              _danosPatrimonialesCard(),

              const SizedBox(height: 12),

              _photoPreview(
                title: 'Foto del hecho (opcional)',
                file: _fotoLugar,
                onPick: () => _pickPhoto(isLugar: true),
                onClear: () => setState(() => _fotoLugar = null),
              ),
              _photoPreview(
                title: 'Foto de la situación (opcional)',
                file: _fotoSituacion,
                onPick: () => _pickPhoto(isLugar: false),
                onClear: () => setState(() => _fotoSituacion = null),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _folioCtrl,
                      decoration: _dec('Folio C5i *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _peritoCtrl,
                      decoration: _dec('Perito *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _authPracCtrl,
                      decoration: _dec('Autorización Práctico'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _unidadCtrl,
                      decoration: _dec('Unidad *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _unidadOrgIdCtrl,
                decoration: _dec('Unidad Org ID (opcional)'),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickHora,
                      child: InputDecorator(
                        decoration: _dec('Hora *'),
                        child: Text(
                          _hora != null ? _horaStr(_hora!) : 'Seleccionar',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: _pickFecha,
                      child: InputDecorator(
                        decoration: _dec('Fecha *'),
                        child: Text(
                          _fecha != null ? _ymd(_fecha!) : 'Seleccionar',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: _dec('Sector *'),
                      value: _sector,
                      items:
                          const [
                                'REVOLUCIÓN',
                                'NUEVA ESPAÑA',
                                'INDEPENDENCIA',
                                'REPÚBLICA',
                                'CENTRO',
                              ]
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _sector = v),
                      validator: (v) => v == null ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _calleCtrl,
                decoration: _dec('Calle *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _coloniaCtrl,
                decoration: _dec('Colonia *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _entreCallesCtrl,
                decoration: _dec('Entre calles'),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _municipioCtrl,
                decoration: _dec('Municipio *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                decoration: _dec('Tipo Hecho *'),
                value: _tipoHecho,
                items:
                    const [
                          'VOLCADURA',
                          'SALIDA DE SUPERFICIE DE RODAMIENTO',
                          'SUBIDA AL CAMELLÓN',
                          'CAIDA DE MOTOCICLETA',
                          'COLISIÓN CON PEATÓN',
                          'COLISIÓN POR ALCANCE',
                          'COLISIÓN POR NO RESPETAR SEMÁFORO',
                          'COLISIÓN POR INVASIÓN DE CARRIL',
                          'COLISIÓN POR CORTE DE CIRCULACIÓN',
                          'COLISIÓN POR CAMBIO DE CARRIL',
                          'COLISIÓN CONTRA OBJETO FIJO',
                          'CAIDA ACUATICA DE VEHÍCULO',
                          'DESBARRANCAMIENTO',
                          'INCENDIO',
                          'EXPLOSIÓN',
                          'Otro',
                        ]
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (v) => setState(() => _tipoHecho = v),
                validator: (v) => v == null ? 'Requerido' : null,
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _superficieCtrl,
                decoration: _dec('Superficie vía *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: _dec('Tiempo *'),
                      value: _tiempo,
                      items: const ['Día', 'Noche', 'Amanecer', 'Atardecer']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _tiempo = v),
                      validator: (v) => v == null ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: _dec('Clima *'),
                      value: _clima,
                      items: const ['Bueno', 'Malo', 'Nublado', 'Lluvioso']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _clima = v),
                      validator: (v) => v == null ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: _dec('Condiciones *'),
                      value: _condiciones,
                      items: const ['Bueno', 'Regular', 'Malo']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _condiciones = v),
                      validator: (v) => v == null ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _controlTxCtrl,
                decoration: _dec('Control tránsito *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),

              const SizedBox(height: 12),

              CheckboxListTile(
                title: const Text('Checaron antecedentes?'),
                value: _checaronAnt,
                onChanged: (v) => setState(() => _checaronAnt = v ?? false),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _causasCtrl,
                decoration: _dec('Causas *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                maxLines: 2,
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _colisionCtrl,
                decoration: _dec('Colisión camino *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                maxLines: 2,
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                decoration: _dec('Situación *'),
                value: _situacion,
                items: const ['RESUELTO', 'PENDIENTE', 'TURNADO', 'REPORTE']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _situacion = v),
                validator: (v) => v == null ? 'Requerido' : null,
              ),

              if (_situacion == 'TURNADO') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _oficioMpCtrl,
                  decoration: _dec('Oficio MP *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ],

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _vehMpCtrl,
                      decoration: _dec('Vehículos MP *'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _persMpCtrl,
                      decoration: _dec('Personas MP *'),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Registrar Hecho'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
