import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/auth_service.dart';

class EditHechoScreen extends StatefulWidget {
  final int hechoId;

  const EditHechoScreen({super.key, required this.hechoId});

  @override
  State<EditHechoScreen> createState() => _EditHechoScreenState();
}

class DictamenItem {
  final int id;

  final String? numeroDictamen;
  final int? anio;
  final String? nombrePolicia;
  final String? nombreMp;
  final String? area;
  final String? archivoDictamen;
  final int? createdBy;
  final int? updatedBy;

  final String label;

  const DictamenItem({
    required this.id,
    required this.label,
    this.numeroDictamen,
    this.anio,
    this.nombrePolicia,
    this.nombreMp,
    this.area,
    this.archivoDictamen,
    this.createdBy,
    this.updatedBy,
  });
}

class _EditHechoScreenState extends State<EditHechoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  bool _loadingHecho = true;
  bool _loadingDictamenes = false;

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

  final _vehMpCtrl = TextEditingController(text: '0');
  final _persMpCtrl = TextEditingController(text: '0');

  int? _dictamenId;
  DictamenItem? _dictamenSelected;
  List<DictamenItem> _dictamenes = const [];

  bool _danosPatrimoniales = false;
  final _propiedadesAfectadasCtrl = TextEditingController();
  final _montoDanosCtrl = TextEditingController();

  final _picker = ImagePicker();
  File? _fotoLugar;
  File? _fotoSituacion;

  String? _fotoLugarUrl;
  String? _fotoSituacionUrl;

  bool _removeFotoLugar = false;
  bool _removeFotoSituacion = false;

  double? _lat;
  double? _lng;
  String? _calidadGeo;
  String? _notaGeo;
  String? _fuenteUbicacion;

  @override
  void initState() {
    super.initState();
    _loadHecho();
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

    _vehMpCtrl.dispose();
    _persMpCtrl.dispose();

    _propiedadesAfectadasCtrl.dispose();
    _montoDanosCtrl.dispose();

    super.dispose();
  }

  Uri _hechoUrl(int id) => Uri.parse('${AuthService.baseUrl}/hechos/$id');
  Uri _dictamenesUrl() => Uri.parse('${AuthService.baseUrl}/dictamenes');

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

  TimeOfDay? _parseHora(dynamic v) {
    final s = _asString(v);
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    if (hh == null || mm == null) return null;
    return TimeOfDay(hour: hh, minute: mm);
  }

  DateTime? _parseFecha(dynamic v) {
    final s = _asString(v);
    if (s == null) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
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
        return _removeAccents(x);
    }
  }

  String _normalizeTiempo(String v) {
    final x = _removeAccents(v.trim().toUpperCase());
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

  String _denormalizeTiempo(String v) {
    final x = _removeAccents(v.trim().toUpperCase());
    if (x == 'DIA') return 'Día';
    if (x == 'NOCHE') return 'Noche';
    if (x == 'AMANECER') return 'Amanecer';
    if (x == 'ATARDECER') return 'Atardecer';
    return v;
  }

  String _denormalizeClima(String v) {
    final x = _removeAccents(v.trim().toUpperCase());
    if (x == 'BUENO') return 'Bueno';
    if (x == 'MALO') return 'Malo';
    if (x == 'NUBLADO') return 'Nublado';
    if (x == 'LLUVIOSO') return 'Lluvioso';
    return v;
  }

  String _denormalizeCondiciones(String v) {
    final x = _removeAccents(v.trim().toUpperCase());
    if (x == 'BUENO') return 'Bueno';
    if (x == 'REGULAR') return 'Regular';
    if (x == 'MALO') return 'Malo';
    return v;
  }

  // =========================
  // ✅ FIX: resolver URL pública para fotos (evitar file:// en Image.network)
  // =========================
  String _publicRootFromApiBase() {
    // AuthService.baseUrl suele ser .../api
    return AuthService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  }

  String _toPublicUrlFlexible(String pathOrUrl) {
    final p = pathOrUrl.trim();
    if (p.isEmpty) return '';

    final lower = p.toLowerCase();

    // ❌ Si es file://, NO es para Image.network
    if (lower.startsWith('file://')) return '';

    // ✅ Si ya es http(s)
    if (lower.startsWith('http://') || lower.startsWith('https://')) return p;

    final root = _publicRootFromApiBase();

    // ✅ Si ya viene /storage/...
    if (p.startsWith('/storage/')) return '$root$p';
    if (p.startsWith('storage/')) return '$root/$p';

    // ✅ Si viene /hechos/... o hechos/... (tu caso)
    if (p.startsWith('/hechos/')) return '$root$p';
    if (p.startsWith('hechos/')) return '$root/$p';

    // ✅ fallback: si el backend guarda "hechos/..", "uploads/..", etc.
    // Si viene con "/" al inicio, lo pegamos directo.
    if (p.startsWith('/')) return '$root$p';

    return '$root/$p';
  }

  String _buildDictamenLabel(Map<String, dynamic> m) {
    final num = _asString(
      m['numero_dictamen'] ?? m['numero'] ?? m['no_dictamen'],
    );
    final anio = _asInt(m['anio']);
    final mp = _asString(m['nombre_mp']);
    final parts = <String>[];

    if (num != null && anio != null) {
      parts.add('$num/$anio');
    } else if (num != null) {
      parts.add(num);
    } else {
      parts.add('SIN NÚMERO');
    }

    if (mp != null) parts.add(mp);

    return parts.join(' ');
  }

  DictamenItem? _mapDictamenItem(Map<String, dynamic> m) {
    final id = _asInt(m['id']);
    if (id == null) return null;

    final numero = _asString(
      m['numero_dictamen'] ?? m['numero'] ?? m['no_dictamen'],
    );
    final anio = _asInt(m['anio']);
    final nombrePolicia = _asString(m['nombre_policia']);
    final nombreMp = _asString(m['nombre_mp']);
    final area = _asString(m['area']);
    final archivo = _asString(m['archivo_dictamen']);
    final createdBy = _asInt(m['created_by']);
    final updatedBy = _asInt(m['updated_by']);

    final label = _buildDictamenLabel(m);

    return DictamenItem(
      id: id,
      label: label,
      numeroDictamen: numero,
      anio: anio,
      nombrePolicia: nombrePolicia,
      nombreMp: nombreMp,
      area: area,
      archivoDictamen: archivo,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }

  Future<void> _loadDictamenes() async {
    if (_loadingDictamenes) return;

    setState(() => _loadingDictamenes = true);

    try {
      final token = await AuthService.getToken();
      final resp = await http.get(
        _dictamenesUrl(),
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode != 200) {
        throw Exception(_parseBackendError(resp.body, resp.statusCode));
      }

      final raw = jsonDecode(resp.body);

      List list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map<String, dynamic> && raw['data'] is List) {
        list = raw['data'] as List;
      } else {
        list = const [];
      }

      final items = <DictamenItem>[];
      for (final it in list) {
        if (it is! Map) continue;
        final m = Map<String, dynamic>.from(it as Map);
        final item = _mapDictamenItem(m);
        if (item != null) items.add(item);
      }

      items.sort((a, b) => a.label.compareTo(b.label));

      if (!mounted) return;
      setState(() {
        _dictamenes = items;

        if (_dictamenId != null) {
          final found = _dictamenes.where((d) => d.id == _dictamenId).toList();
          _dictamenSelected = found.isEmpty ? null : found.first;
          if (found.isEmpty) _dictamenId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dictamenes = const [];
        _dictamenId = null;
        _dictamenSelected = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar dictámenes: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loadingDictamenes = false);
    }
  }

  String _buildOficioFromSelected() {
    final d = _dictamenSelected;
    if (d == null) return '';
    final num = (d.numeroDictamen ?? '').trim();
    final anio = d.anio;
    final mp = (d.nombreMp ?? '').trim();

    final parts = <String>[];
    if (num.isNotEmpty && anio != null) {
      parts.add('$num/$anio');
    } else if (num.isNotEmpty) {
      parts.add(num);
    }
    if (mp.isNotEmpty) parts.add(mp);

    return parts.join(' ').trim();
  }

  Future<void> _loadHecho() async {
    setState(() => _loadingHecho = true);

    try {
      final token = await AuthService.getToken();
      final resp = await http.get(
        _hechoUrl(widget.hechoId),
        headers: {
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode != 200) {
        throw Exception(_parseBackendError(resp.body, resp.statusCode));
      }

      final raw = jsonDecode(resp.body);

      Map<String, dynamic> data;
      if (raw is Map<String, dynamic> && raw['data'] is Map) {
        data = Map<String, dynamic>.from(raw['data'] as Map);
      } else if (raw is Map<String, dynamic>) {
        data = raw;
      } else {
        throw Exception('Respuesta inválida del servidor');
      }

      _folioCtrl.text = _asString(data['folio_c5i']) ?? '';
      _peritoCtrl.text = _asString(data['perito']) ?? '';
      _authPracCtrl.text = _asString(data['autorizacion_practico']) ?? '';
      _unidadCtrl.text = _asString(data['unidad']) ?? '';
      _unidadOrgIdCtrl.text = (_asInt(data['unidad_org_id'])?.toString()) ?? '';

      _hora = _parseHora(data['hora']);
      _fecha = _parseFecha(data['fecha']);

      final sectorRaw = _asString(data['sector']);
      if (sectorRaw != null && sectorRaw.isNotEmpty) {
        final norm = _normalizeSector(sectorRaw);
        if (norm == 'REVOLUCION') {
          _sector = 'REVOLUCIÓN';
        } else if (norm == 'NUEVA ESPANA') {
          _sector = 'NUEVA ESPAÑA';
        } else if (norm == 'INDEPENDENCIA') {
          _sector = 'INDEPENDENCIA';
        } else if (norm == 'REPUBLICA') {
          _sector = 'REPÚBLICA';
        } else if (norm == 'CENTRO') {
          _sector = 'CENTRO';
        } else {
          _sector = sectorRaw;
        }
      } else {
        _sector = null;
      }

      _calleCtrl.text = _asString(data['calle']) ?? '';
      _coloniaCtrl.text = _asString(data['colonia']) ?? '';
      _entreCallesCtrl.text = _asString(data['entre_calles']) ?? '';
      _municipioCtrl.text = _asString(data['municipio']) ?? '';

      _tipoHecho = _asString(data['tipo_hecho']);
      _superficieCtrl.text = _asString(data['superficie_via']) ?? '';

      final tiempoRaw = _asString(data['tiempo']);
      final climaRaw = _asString(data['clima']);
      final condRaw = _asString(data['condiciones']);

      _tiempo = tiempoRaw != null ? _denormalizeTiempo(tiempoRaw) : null;
      _clima = climaRaw != null ? _denormalizeClima(climaRaw) : null;
      _condiciones = condRaw != null ? _denormalizeCondiciones(condRaw) : null;

      _controlTxCtrl.text = _asString(data['control_transito']) ?? '';
      _checaronAnt = (_asInt(data['checaron_antecedentes']) ?? 0) == 1;

      _causasCtrl.text = _asString(data['causas']) ?? '';
      _colisionCtrl.text = _asString(data['colision_camino']) ?? '';

      _situacion = _asString(data['situacion']);

      _vehMpCtrl.text = (_asInt(data['vehiculos_mp']) ?? 0).toString();
      _persMpCtrl.text = (_asInt(data['personas_mp']) ?? 0).toString();

      final dp = _asInt(data['danos_patrimoniales']);
      _danosPatrimoniales = (dp ?? 0) == 1;
      _propiedadesAfectadasCtrl.text =
          _asString(data['propiedades_afectadas']) ?? '';
      _montoDanosCtrl.text = _asString(data['monto_danos_patrimoniales']) ?? '';

      _lat = _asDouble(data['lat']);
      _lng = _asDouble(data['lng']);
      _calidadGeo = _asString(data['calidad_geo']);
      _notaGeo = _asString(data['nota_geo']);
      _fuenteUbicacion = _asString(data['fuente_ubicacion']);

      _fotoLugarUrl = _asString(
        data['foto_lugar'] ?? data['foto_lugar_url'] ?? data['foto_lugar_path'],
      );
      _fotoSituacionUrl = _asString(
        data['foto_situacion'] ??
            data['foto_situacion_url'] ??
            data['foto_situacion_path'],
      );

      _removeFotoLugar = false;
      _removeFotoSituacion = false;
      _fotoLugar = null;
      _fotoSituacion = null;

      final dictId = _asInt(data['dictamen_id']);
      _dictamenId = dictId;

      if (_situacion == 'TURNADO') {
        await _loadDictamenes();
      } else {
        _dictamenSelected = null;
        _dictamenId = null;
      }

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo cargar el hecho: $e')));
      Navigator.pop(context, false);
    } finally {
      if (!mounted) return;
      setState(() => _loadingHecho = false);
    }
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
        _removeFotoLugar = false;
      } else {
        _fotoSituacion = f;
        _removeFotoSituacion = false;
      }
    });
  }

  Widget _photoPreview({
    required String title,
    required File? file,
    required String? url,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasLocal = file != null;
    final rawUrl = (url ?? '').trim();
    final resolved = rawUrl.isEmpty ? '' : _toPublicUrlFlexible(rawUrl);
    final hasResolved = resolved.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (!hasLocal && !hasResolved)
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text('Sin imagen'),
              )
            else if (hasLocal)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image.file(file, fit: BoxFit.cover),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image.network(
                    resolved,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Text('No se pudo cargar la imagen'),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
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
                    onPressed: _submitting ? null : onClear,
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

  // ---- GPS (solo cuando el usuario lo pide en EDIT) ----
  Future<void> _obtenerUbicacionAhora() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _calidadGeo = 'OFF';
          _notaGeo = 'GPS desactivado';
          _fuenteUbicacion = null;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('GPS desactivado')));
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
          _calidadGeo = 'DENIED';
          _notaGeo = 'Permiso de ubicación denegado';
          _fuenteUbicacion = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado')),
        );
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ubicación lista: $_lat, $_lng')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _calidadGeo = 'ERR';
        _notaGeo = 'Error GPS';
        _fuenteUbicacion = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener ubicación: $e')),
      );
    }
  }

  Widget _ubicacionCard() {
    final has = _lat != null && _lng != null;

    final extra = <String>[];
    if ((_fuenteUbicacion ?? '').trim().isNotEmpty)
      extra.add('Fuente: $_fuenteUbicacion');
    if ((_notaGeo ?? '').trim().isNotEmpty) extra.add('Nota: $_notaGeo');

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
                  ? 'Lat: $_lat\nLng: $_lng\nCalidad: ${_calidadGeo ?? '-'}${extra.isNotEmpty ? '\n${extra.join('\n')}' : ''}'
                  : 'Sin ubicación guardada.\nPuedes obtener una nueva con el botón.',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : _obtenerUbicacionAhora,
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
                  if (txt.isEmpty) return null;
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

  void _onSituacionChanged(String? v) {
    setState(() {
      _situacion = v;
      if (_situacion != 'TURNADO') {
        _dictamenId = null;
        _dictamenSelected = null;
      }
    });

    if (_situacion == 'TURNADO') {
      _loadDictamenes();
    }
  }

  void _onDictamenChanged(int? id) {
    setState(() {
      _dictamenId = id;
      if (id == null) {
        _dictamenSelected = null;
      } else {
        final found = _dictamenes.where((d) => d.id == id).toList();
        _dictamenSelected = found.isEmpty ? null : found.first;
      }
    });
  }

  Widget _dictamenSelect() {
    if (_situacion != 'TURNADO') return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                decoration: _dec('Dictamen *'),
                value: _dictamenId,
                items: _dictamenes
                    .map(
                      (d) => DropdownMenuItem<int>(
                        value: d.id,
                        child: Text(d.label, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _submitting || _loadingDictamenes
                    ? null
                    : _onDictamenChanged,
                validator: (v) {
                  if (_situacion == 'TURNADO' && v == null) return 'Requerido';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: (_submitting || _loadingDictamenes)
                    ? null
                    : _loadDictamenes,
                icon: _loadingDictamenes
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text(''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _loadingDictamenes
              ? 'Cargando dictámenes...'
              : (_dictamenes.isEmpty
                    ? 'No hay dictámenes para seleccionar.'
                    : 'Selecciona el dictamen (Oficio MP se llena automático).'),
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  InputDecoration _dec(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());

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

    if (_situacion == 'TURNADO' &&
        (_dictamenId == null || _dictamenSelected == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona el dictamen')));
      return;
    }

    if (_danosPatrimoniales) {
      final props = _propiedadesAfectadasCtrl.text.trim();
      final montoTxt = _montoDanosCtrl.text.trim();
      if (props.isEmpty && montoTxt.isEmpty) {
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

      final uri = _hechoUrl(widget.hechoId);
      final req = http.MultipartRequest('POST', uri);

      req.headers['Accept'] = 'application/json';
      if (token != null && token.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $token';
      }

      req.fields['_method'] = 'PUT';

      req.fields['folio_c5i'] = _folioCtrl.text.trim();
      req.fields['perito'] = _peritoCtrl.text.trim();
      req.fields['autorizacion_practico'] = _authPracCtrl.text.trim();
      req.fields['unidad'] = _unidadCtrl.text.trim();

      final unidadOrg = _unidadOrgIdCtrl.text.trim();
      if (unidadOrg.isNotEmpty) req.fields['unidad_org_id'] = unidadOrg;

      req.fields['hora'] = _horaStr(_hora!);
      req.fields['fecha'] = _ymd(_fecha!);

      req.fields['sector'] = _normalizeSector(_sector!);

      req.fields['calle'] = _calleCtrl.text.trim();
      req.fields['colonia'] = _coloniaCtrl.text.trim();
      req.fields['entre_calles'] = _entreCallesCtrl.text.trim();
      req.fields['municipio'] = _municipioCtrl.text.trim();

      req.fields['tipo_hecho'] = _tipoHecho ?? '';
      req.fields['superficie_via'] = _superficieCtrl.text.trim();

      req.fields['tiempo'] = _normalizeTiempo(_tiempo!);
      req.fields['clima'] = _normalizeClima(_clima!);
      req.fields['condiciones'] = _normalizeCondiciones(_condiciones!);

      req.fields['control_transito'] = _controlTxCtrl.text.trim();
      req.fields['checaron_antecedentes'] = _checaronAnt ? '1' : '0';

      req.fields['causas'] = _causasCtrl.text.trim();
      req.fields['colision_camino'] = _colisionCtrl.text.trim();

      req.fields['situacion'] = _situacion ?? '';

      if (_situacion == 'TURNADO' && _dictamenSelected != null) {
        req.fields['dictamen_id'] = _dictamenSelected!.id.toString();

        final oficio = _buildOficioFromSelected();
        req.fields['oficio_mp'] = oficio;

        if ((_dictamenSelected!.numeroDictamen ?? '').trim().isNotEmpty) {
          req.fields['dictamen_numero'] = _dictamenSelected!.numeroDictamen!
              .trim();
        }
        if (_dictamenSelected!.anio != null) {
          req.fields['dictamen_anio'] = _dictamenSelected!.anio.toString();
        }
        if ((_dictamenSelected!.nombrePolicia ?? '').trim().isNotEmpty) {
          req.fields['dictamen_nombre_policia'] = _dictamenSelected!
              .nombrePolicia!
              .trim();
        }
        if ((_dictamenSelected!.nombreMp ?? '').trim().isNotEmpty) {
          req.fields['dictamen_nombre_mp'] = _dictamenSelected!.nombreMp!
              .trim();
        }
        if ((_dictamenSelected!.area ?? '').trim().isNotEmpty) {
          req.fields['dictamen_area'] = _dictamenSelected!.area!.trim();
        }
        if ((_dictamenSelected!.archivoDictamen ?? '').trim().isNotEmpty) {
          req.fields['dictamen_archivo'] = _dictamenSelected!.archivoDictamen!
              .trim();
        }
        if (_dictamenSelected!.createdBy != null) {
          req.fields['dictamen_created_by'] = _dictamenSelected!.createdBy
              .toString();
        }
        if (_dictamenSelected!.updatedBy != null) {
          req.fields['dictamen_updated_by'] = _dictamenSelected!.updatedBy
              .toString();
        }
      } else {
        req.fields['oficio_mp'] = '';
      }

      req.fields['vehiculos_mp'] = _vehMpCtrl.text.trim();
      req.fields['personas_mp'] = _persMpCtrl.text.trim();

      req.fields['danos_patrimoniales'] = _danosPatrimoniales ? '1' : '0';
      if (_danosPatrimoniales) {
        final props = _propiedadesAfectadasCtrl.text.trim();
        final montoTxt = _montoDanosCtrl.text.trim();

        if (props.isNotEmpty) req.fields['propiedades_afectadas'] = props;
        if (montoTxt.isNotEmpty) {
          req.fields['monto_danos_patrimoniales'] = montoTxt.replaceAll(
            ',',
            '',
          );
        }
      }

      final hasCoords = _lat != null && _lng != null;
      if (hasCoords) {
        req.fields['lat'] = _lat!.toStringAsFixed(7);
        req.fields['lng'] = _lng!.toStringAsFixed(7);

        if ((_calidadGeo ?? '').trim().isNotEmpty)
          req.fields['calidad_geo'] = _calidadGeo!.trim();
        if ((_notaGeo ?? '').trim().isNotEmpty)
          req.fields['nota_geo'] = _notaGeo!.trim();
        if ((_fuenteUbicacion ?? '').trim().isNotEmpty)
          req.fields['fuente_ubicacion'] = _fuenteUbicacion!.trim();
      }

      if (_removeFotoLugar) req.fields['remove_foto_lugar'] = '1';
      if (_removeFotoSituacion) req.fields['remove_foto_situacion'] = '1';

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

      if (streamed.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      if (streamed.statusCode == 422) {
        throw Exception(_parseBackendError(respBody, streamed.statusCode));
      }

      throw Exception('HTTP ${streamed.statusCode}: $respBody');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fallo al actualizar: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Hecho'),
        actions: [
          IconButton(
            onPressed: (_submitting || _loadingHecho) ? null : _loadHecho,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loadingHecho
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                      url: _fotoLugarUrl,
                      onPick: () => _pickPhoto(isLugar: true),
                      onClear: () {
                        setState(() {
                          _fotoLugar = null;
                          _fotoLugarUrl = null;
                          _removeFotoLugar = true;
                        });
                      },
                    ),
                    _photoPreview(
                      title: 'Foto de la situación (opcional)',
                      file: _fotoSituacion,
                      url: _fotoSituacionUrl,
                      onPick: () => _pickPhoto(isLugar: false),
                      onClear: () {
                        setState(() {
                          _fotoSituacion = null;
                          _fotoSituacionUrl = null;
                          _removeFotoSituacion = true;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _folioCtrl,
                            decoration: _dec('Folio C5i *'),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _peritoCtrl,
                            decoration: _dec('Perito *'),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
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
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
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
                            onTap: _submitting ? null : _pickHora,
                            child: InputDecorator(
                              decoration: _dec('Hora *'),
                              child: Text(
                                _hora != null
                                    ? _horaStr(_hora!)
                                    : 'Seleccionar',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: _submitting ? null : _pickFecha,
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
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v),
                                      ),
                                    )
                                    .toList(),
                            onChanged: _submitting
                                ? null
                                : (v) => setState(() => _sector = v),
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
                                'COLISIÓN POR MANIOBRA DE REVERSA',
                                'COLISIÓN CONTRA OBJETO FIJO',
                                'CAIDA ACUATICA DE VEHÍCULO',
                                'DESBARRANCAMIENTO',
                                'INCENDIO',
                                'EXPLOSIÓN',
                              ]
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _tipoHecho = v),
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
                            items:
                                const ['Día', 'Noche', 'Amanecer', 'Atardecer']
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v),
                                      ),
                                    )
                                    .toList(),
                            onChanged: _submitting
                                ? null
                                : (v) => setState(() => _tiempo = v),
                            validator: (v) => v == null ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: _dec('Clima *'),
                            value: _clima,
                            items:
                                const ['Bueno', 'Malo', 'Nublado', 'Lluvioso']
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v),
                                      ),
                                    )
                                    .toList(),
                            onChanged: _submitting
                                ? null
                                : (v) => setState(() => _clima = v),
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
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(v),
                                  ),
                                )
                                .toList(),
                            onChanged: _submitting
                                ? null
                                : (v) => setState(() => _condiciones = v),
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
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _checaronAnt = v ?? false),
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
                      items:
                          const ['RESUELTO', 'PENDIENTE', 'TURNADO', 'REPORTE']
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                      onChanged: _submitting ? null : _onSituacionChanged,
                      validator: (v) => v == null ? 'Requerido' : null,
                    ),
                    _dictamenSelect(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _vehMpCtrl,
                            decoration: _dec('Vehículos MP *'),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _persMpCtrl,
                            decoration: _dec('Personas MP *'),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
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
                            : const Text('Guardar cambios'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
