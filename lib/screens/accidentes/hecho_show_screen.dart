import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/app_version_service.dart';

import '../../widgets/app_drawer.dart';
import '../../widgets/header_card.dart';

import '../login_screen.dart';
import '../../main.dart' show AppRoutes;

class HechoShowScreen extends StatefulWidget {
  const HechoShowScreen({super.key});

  @override
  State<HechoShowScreen> createState() => _HechoShowScreenState();
}

class _HechoShowScreenState extends State<HechoShowScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _hecho;
  bool _cargando = true;

  bool _trackingOn = false;
  bool _bootstrapped = false;
  bool _busy = false;

  bool _saving = false;

  final _picker = ImagePicker();

  static const List<String> _sectorOptions = [
    'REVOLUCIÓN',
    'NUEVA ESPAÑA',
    'INDEPENDENCIA',
    'REPÚBLICA',
    'CENTRO',
  ];

  static const List<String> _situacionOptions = [
    'RESUELTO',
    'PENDIENTE',
    'TURNADO',
    'REPORTE',
  ];

  static const List<String> _requiredKeys = [
    'folio_c5i',
    'perito',
    'unidad',
    'hora',
    'fecha',
    'sector',
    'calle',
    'colonia',
    'municipio',
    'tipo_hecho',
    'superficie_via',
    'tiempo',
    'clima',
    'condiciones',
    'control_transito',
    'causas',
    'colision_camino',
    'situacion',
    'vehiculos_mp',
    'personas_mp',
  ];

  static const List<String> _payloadKeys = [
    ..._requiredKeys,
    'unidad_org_id',
    'entre_calles',
    'checaron_antecedentes',
    'danos_patrimoniales',
    'propiedades_afectadas',
    'monto_danos_patrimoniales',
    'oficio_mp',
    'autorizacion_practico',
  ];

  static const Set<String> _noEditKeys = {'hora', 'fecha'};

  int _hechoIdFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    int parse(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    if (args == null) return 0;

    final direct = parse(args);
    if (direct > 0) return direct;

    if (args is Map) {
      final candidates = [
        args['hechoId'],
        args['hecho_id'],
        args['id'],
        args['item_id'],
      ];

      for (final c in candidates) {
        final id = parse(c);
        if (id > 0) return id;
      }
    }

    return 0;
  }

  String _safeText(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '—' : s;
  }

  String _safeBool01(dynamic v) {
    if (v == null) return '—';
    final s = v.toString().trim();
    if (s.isEmpty) return '—';
    if (s == '1' || s.toLowerCase() == 'true') return 'Sí';
    if (s == '0' || s.toLowerCase() == 'false') return 'No';
    return s;
  }

  String _toPublicUrl(String pathOrUrl) {
    final p = pathOrUrl.trim();
    if (p.isEmpty) return '';

    final lower = p.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return p;

    final root = AuthService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

    if (p.startsWith('/storage/')) return '$root$p';
    if (p.startsWith('storage/')) return '$root/$p';

    return '$root/storage/$p';
  }

  List<Map<String, dynamic>> _vehiculosDeHecho() {
    final v = _hecho?['vehiculos'];
    if (v is List) {
      return v
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }

  List<String> _fotosDelHecho() {
    final vehs = _vehiculosDeHecho();
    final out = <String>[];

    for (final v in vehs) {
      final fotosUrl = v['fotos_url'];
      if (fotosUrl is String && fotosUrl.trim().isNotEmpty) {
        out.add(fotosUrl.trim());
        continue;
      }

      final fotos = v['fotos'];
      if (fotos == null) continue;

      if (fotos is List) {
        for (final x in fotos) {
          final s = (x ?? '').toString().trim();
          if (s.isNotEmpty) out.add(_toPublicUrl(s));
        }
        continue;
      }

      if (fotos is String) {
        final s = fotos.trim();
        if (s.isEmpty) continue;

        if (s.startsWith('[') && s.endsWith(']')) {
          try {
            final decoded = jsonDecode(s);
            if (decoded is List) {
              for (final x in decoded) {
                final ss = (x ?? '').toString().trim();
                if (ss.isNotEmpty) out.add(_toPublicUrl(ss));
              }
              continue;
            }
          } catch (_) {}
        }

        out.add(_toPublicUrl(s));
      }
    }

    final uniq = <String>{};
    final cleaned = <String>[];
    for (final u in out) {
      final uu = u.trim();
      if (uu.isEmpty) continue;
      if (uniq.add(uu)) cleaned.add(uu);
    }
    return cleaned;
  }

  Future<void> _bootstrapTrackingStatusOnly() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final running = await FlutterForegroundTask.isRunningService;
    if (!mounted) return;
    setState(() => _trackingOn = running);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AppVersionService.enforceUpdateIfNeeded(context);
      await _bootstrapTrackingStatusOnly();

      final id = _hechoIdFromArgs(context);
      if (id > 0) {
        await _cargarHecho(id);
      } else if (mounted) {
        setState(() => _cargando = false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final running = await FlutterForegroundTask.isRunningService;
      if (!mounted) return;
      setState(() => _trackingOn = running);
    }
  }

  Future<void> _logout(BuildContext context) async {
    if (_busy) return;
    _busy = true;

    try {
      await TrackingService.stop();
      await AuthService.logout();
    } finally {
      _busy = false;
    }

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _cargarHecho(int id) async {
    if (!mounted) return;
    setState(() => _cargando = true);

    final token = await AuthService.getToken();
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = Uri.parse('${AuthService.baseUrl}/hechos/$id');
    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      if (mounted) setState(() => _cargando = false);
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final raw = jsonDecode(res.body);
    Map<String, dynamic> hecho;

    if (raw is Map<String, dynamic> && raw['data'] is Map) {
      hecho = Map<String, dynamic>.from(raw['data']);
    } else if (raw is Map<String, dynamic> && raw['hecho'] is Map) {
      hecho = Map<String, dynamic>.from(raw['hecho']);
    } else if (raw is Map<String, dynamic>) {
      hecho = raw;
    } else {
      hecho = {};
    }

    if (!mounted) return;
    setState(() {
      _hecho = hecho;
      _cargando = false;
    });
  }

  String _normalizeHora(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';

    final m = RegExp(r'(\d{1,2})\s*:\s*(\d{2})').firstMatch(s);
    if (m == null) return s;

    final hh = int.tryParse(m.group(1) ?? '') ?? 0;
    final mm = int.tryParse(m.group(2) ?? '') ?? 0;

    final hh2 = hh.clamp(0, 23).toString().padLeft(2, '0');
    final mm2 = mm.clamp(0, 59).toString().padLeft(2, '0');
    return '$hh2:$mm2';
  }

  String _normalizeFecha(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';

    final mIso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (mIso != null) return s;

    final mLat = RegExp(
      r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$',
    ).firstMatch(s);
    if (mLat != null) {
      final dd = int.tryParse(mLat.group(1) ?? '') ?? 0;
      final mm = int.tryParse(mLat.group(2) ?? '') ?? 0;
      final yyyy = int.tryParse(mLat.group(3) ?? '') ?? 0;
      if (yyyy > 1900 && mm >= 1 && mm <= 12 && dd >= 1 && dd <= 31) {
        final dd2 = dd.toString().padLeft(2, '0');
        final mm2 = mm.toString().padLeft(2, '0');
        return '$yyyy-$mm2-$dd2';
      }
    }

    final mInside = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (mInside != null) {
      return '${mInside.group(1)}-${mInside.group(2)}-${mInside.group(3)}';
    }

    return s;
  }

  String _normalizeSector(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';

    if (_sectorOptions.contains(s)) return s;

    final upper = s.toUpperCase();
    for (final opt in _sectorOptions) {
      if (upper.contains(opt.toUpperCase())) return opt;
    }

    return s;
  }

  String _normalizeSituacion(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';

    if (_situacionOptions.contains(s)) return s;

    final upper = s.toUpperCase();
    for (final opt in _situacionOptions) {
      if (upper.contains(opt)) return opt;
    }
    return s;
  }

  String _valueToStringForPayload(String key, dynamic v) {
    if (v == null) return '';

    if (key == 'hora') return _normalizeHora(v.toString());
    if (key == 'fecha') return _normalizeFecha(v.toString());

    if (key == 'sector') return _normalizeSector(v.toString());
    if (key == 'situacion') return _normalizeSituacion(v.toString());

    if (key == 'checaron_antecedentes') {
      final s = v.toString().trim().toLowerCase();
      if (s == '1' || s == 'true') return '1';
      if (s == '0' || s == 'false') return '0';
      return s;
    }

    if (key == 'danos_patrimoniales') {
      final s = v.toString().trim().toLowerCase();
      if (s == '1' || s == 'true' || s == 'sí' || s == 'si') return '1';
      if (s == '0' || s == 'false' || s == 'no') return '0';
      return s;
    }

    return v.toString().trim();
  }

  Map<String, String> _buildPayloadFromHecho({Map<String, String>? override}) {
    final h = _hecho ?? {};
    final out = <String, String>{};

    for (final key in _payloadKeys) {
      if (!h.containsKey(key)) continue;
      final val = _valueToStringForPayload(key, h[key]);
      out[key] = val;
    }

    if (override != null) {
      override.forEach((k, v) {
        if (_noEditKeys.contains(k)) return;
        out[k] = v;
      });
    }

    if (out.containsKey('hora'))
      out['hora'] = _normalizeHora(out['hora'] ?? '');
    if (out.containsKey('fecha')) {
      out['fecha'] = _normalizeFecha(out['fecha'] ?? '');
    }
    if (out.containsKey('sector')) {
      out['sector'] = _normalizeSector(out['sector'] ?? '');
    }
    if (out.containsKey('situacion')) {
      out['situacion'] = _normalizeSituacion(out['situacion'] ?? '');
    }

    return out;
  }

  List<String> _missingRequiredFromPayload(Map<String, String> payload) {
    final missing = <String>[];
    for (final k in _requiredKeys) {
      final v = (payload[k] ?? '').trim();
      if (v.isEmpty) missing.add(k);
    }
    return missing;
  }

  String _parse422Message(String body) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map<String, dynamic>) {
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
        if (raw['message'] is String) return (raw['message'] as String).trim();
      }
    } catch (_) {}
    return body;
  }

  Future<void> _updateHechoMultipart(
    int hechoId, {
    required Map<String, String> fields,
    File? fotoLugar,
    File? fotoSituacion,
  }) async {
    if (_saving) return;
    _saving = true;

    try {
      if (_hecho == null || _hecho!.isEmpty) {
        throw Exception('No hay datos del hecho cargados todavía.');
      }

      final payload = _buildPayloadFromHecho(override: fields);

      final missing = _missingRequiredFromPayload(payload);
      if (missing.isNotEmpty) {
        final nice = missing.join(', ');
        throw Exception(
          'Faltan campos requeridos para guardar en backend: $nice.\n'
          'Completa esos campos desde la versión web y luego intenta otra vez.',
        );
      }

      final token = await AuthService.getToken();

      final uri = Uri.parse('${AuthService.baseUrl}/hechos/$hechoId');
      final req = http.MultipartRequest('POST', uri);

      req.headers['Accept'] = 'application/json';
      if (token != null && token.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $token';
      }

      req.fields['_method'] = 'PUT';

      payload.forEach((k, v) {
        req.fields[k] = v;
      });

      if (fotoLugar != null) {
        req.files.add(
          await http.MultipartFile.fromPath('foto_lugar', fotoLugar.path),
        );
      }

      if (fotoSituacion != null) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'foto_situacion',
            fotoSituacion.path,
          ),
        );
      }

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        if (streamed.statusCode == 422) {
          final msg = _parse422Message(body);
          throw Exception(msg);
        }
        throw Exception('HTTP ${streamed.statusCode}: $body');
      }

      dynamic raw;
      try {
        raw = jsonDecode(body);
      } catch (_) {
        raw = null;
      }

      if (!mounted) return;

      if (raw is Map<String, dynamic> && raw['data'] is Map) {
        setState(() => _hecho = Map<String, dynamic>.from(raw['data']));
      } else if (raw is Map<String, dynamic> && raw['hecho'] is Map) {
        setState(() => _hecho = Map<String, dynamic>.from(raw['hecho']));
      } else {
        await _cargarHecho(hechoId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Guardado correctamente.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      _saving = false;
    }
  }

  Future<void> _editFieldDialog({
    required int hechoId,
    required _FieldDef field,
    required dynamic currentValue,
  }) async {
    if (_saving) return;
    if (!field.editable) return;

    final key = field.key;

    if (_noEditKeys.contains(key)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hora y fecha solo se editan en la versión web.'),
        ),
      );
      return;
    }

    final label = field.label;

    if (field.type == _FieldType.bool01) {
      final initial =
          (currentValue?.toString() == '1' ||
          currentValue?.toString().toLowerCase() == 'true');

      bool val = initial;

      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Editar $label'),
          content: StatefulBuilder(
            builder: (context, setLocal) => Row(
              children: [
                Expanded(child: Text(val ? 'Sí' : 'No')),
                Switch(value: val, onChanged: (v) => setLocal(() => val = v)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );

      if (ok == true) {
        await _updateHechoMultipart(hechoId, fields: {key: val ? '1' : '0'});
      }
      return;
    }

    if (field.options != null && field.options!.isNotEmpty) {
      String selected = (currentValue ?? '').toString().trim();
      if (selected.isEmpty || !field.options!.contains(selected)) {
        if (key == 'sector') {
          selected = _normalizeSector(selected);
        } else if (key == 'situacion') {
          selected = _normalizeSituacion(selected);
        }
        if (!field.options!.contains(selected)) {
          selected = field.options!.first;
        }
      }

      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Editar $label'),
          content: StatefulBuilder(
            builder: (context, setLocal) => DropdownButtonFormField<String>(
              value: selected,
              items: field.options!
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setLocal(() => selected = v);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );

      if (ok == true) {
        await _updateHechoMultipart(hechoId, fields: {key: selected});
      }
      return;
    }

    final controller = TextEditingController(
      text: (currentValue ?? '').toString(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: field.multiline ? 4 : 1,
          keyboardType: field.keyboardType,
          decoration: const InputDecoration(hintText: 'Escribe el nuevo valor'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final v = controller.text.trim();
      await _updateHechoMultipart(hechoId, fields: {key: v});
    }
  }

  Future<void> _pickAndUploadPhoto({
    required int hechoId,
    required _PhotoKind kind,
  }) async {
    if (_saving) return;

    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;

    final file = File(x.path);

    if (!mounted) return;
    final label = (kind == _PhotoKind.lugar)
        ? 'Foto del hecho'
        : 'Foto de la situación';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Subir $label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(file, height: 160, fit: BoxFit.cover),
            ),
            const SizedBox(height: 10),
            const Text('¿Deseas subir esta imagen?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Subir'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await _updateHechoMultipart(
      hechoId,
      fields: const {},
      fotoLugar: kind == _PhotoKind.lugar ? file : null,
      fotoSituacion: kind == _PhotoKind.situacion ? file : null,
    );
  }

  Widget _fotosStrip(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: urls.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final u = urls[i];
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        insetPadding: const EdgeInsets.all(16),
                        child: InteractiveViewer(
                          child: Image.network(
                            u,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No se pudo cargar la imagen.'),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Image.network(
                    u,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image),
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
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildEditableFields(int hechoId, List<_FieldDef> fields) {
    final hecho = _hecho ?? {};
    final tiles = <Widget>[];

    for (final f in fields) {
      final key = f.key;

      if (!hecho.containsKey(key)) {
        tiles.add(
          _InfoTile(
            f.label,
            '⛔ No viene en API ($key)',
            onDoubleTap: null,
            trailing: null,
          ),
        );
        continue;
      }

      String value;
      if (f.type == _FieldType.bool01) {
        value = _safeBool01(hecho[key]);
      } else {
        value = _safeText(hecho[key]);
      }

      tiles.add(
        _InfoTile(
          f.label,
          value,
          onDoubleTap: f.editable
              ? () => _editFieldDialog(
                  hechoId: hechoId,
                  field: f,
                  currentValue: hecho[key],
                )
              : null,
          trailing: f.editable ? const Icon(Icons.edit, size: 18) : null,
        ),
      );
    }

    return Column(children: tiles);
  }

  Widget _photoCard(int hechoId) {
    final h = _hecho ?? {};

    final fotoLugarRaw =
        (h['foto_lugar_url'] ?? h['foto_lugar_path'] ?? h['foto_lugar'] ?? '')
            .toString()
            .trim();

    final fotoSitRaw =
        (h['foto_situacion_url'] ??
                h['foto_situacion_path'] ??
                h['foto_situacion'] ??
                '')
            .toString()
            .trim();

    final fotoLugarUrl = fotoLugarRaw.isEmpty ? '' : _toPublicUrl(fotoLugarRaw);
    final fotoSitUrl = fotoSitRaw.isEmpty ? '' : _toPublicUrl(fotoSitRaw);

    Widget thumb(String url) {
      if (url.isEmpty) {
        return Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Text('Sin imagen'),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  insetPadding: const EdgeInsets.all(16),
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No se pudo cargar la imagen.'),
                      ),
                    ),
                  ),
                ),
              );
            },
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image),
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
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fotos del hecho y situación',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Foto del hecho',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      thumb(fotoLugarUrl),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _pickAndUploadPhoto(
                                  hechoId: hechoId,
                                  kind: _PhotoKind.lugar,
                                ),
                          icon: const Icon(Icons.photo_library),
                          label: Text(_saving ? 'Guardando...' : 'Subir'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Foto de la situación',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      thumb(fotoSitUrl),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _pickAndUploadPhoto(
                                  hechoId: hechoId,
                                  kind: _PhotoKind.situacion,
                                ),
                          icon: const Icon(Icons.photo_camera_back),
                          label: Text(_saving ? 'Guardando...' : 'Subir'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomActions(int hechoId) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, -6),
              color: Colors.black.withOpacity(0.08),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/accidentes/vehiculos',
                    arguments: {'hechoId': hechoId},
                  );
                },
                icon: const Icon(Icons.directions_car),
                label: const Text('Vehículos y Conductores del hecho'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.lesionados,
                    arguments: {'hechoId': hechoId},
                  );
                },
                icon: const Icon(Icons.personal_injury),
                label: const Text('Lesionados'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pendiente: conectar descargo'),
                    ),
                  );
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Subir/Ver descargo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hechoId = _hechoIdFromArgs(context);

    final fotos = _fotosDelHecho();
    final vehiculos = _vehiculosDeHecho();

    final camposIdentificacion = <_FieldDef>[
      _FieldDef('ID', 'id', editable: false),
      _FieldDef('Folio C5i', 'folio_c5i'),
      _FieldDef('Perito', 'perito'),
      _FieldDef('Unidad', 'unidad'),
      _FieldDef('Situación', 'situacion', options: _situacionOptions),
    ];

    final camposTiempoLugar = <_FieldDef>[
      _FieldDef(
        'Fecha',
        'fecha',
        keyboardType: TextInputType.datetime,
        editable: false,
      ),
      _FieldDef(
        'Hora',
        'hora',
        keyboardType: TextInputType.datetime,
        editable: false,
      ),
      _FieldDef('Sector', 'sector', options: _sectorOptions),
      _FieldDef('Calle', 'calle', multiline: true),
      _FieldDef('Colonia', 'colonia', multiline: true),
      _FieldDef('Entre calles', 'entre_calles', multiline: true),
      _FieldDef('Municipio', 'municipio'),
    ];

    final camposClasificacion = <_FieldDef>[
      _FieldDef(
        'Tipo de hecho',
        'tipo_hecho',
        options: const [
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
          'COLISIÓN POR CORTE DE CIRCULACIÓN',
          'COLISIÓN POR MANIOBRA DE REVERSA',
          'COLISIÓN CONTRA OBJETO FIJO',
          'CAIDA ACUATICA DE VEHÍCULO',
          'DESBARRANCAMIENTO',
          'INCENDIO',
          'EXPLOSIÓN',
          'Otro',
        ],
      ),
      _FieldDef('Superficie de vía', 'superficie_via'),
      _FieldDef(
        'Tiempo (día/noche)',
        'tiempo',
        options: const ['Día', 'Noche', 'Amanecer', 'Atardecer'],
      ),
      _FieldDef(
        'Clima',
        'clima',
        options: const ['Bueno', 'Malo', 'Nublado', 'Lluvioso'],
      ),
      _FieldDef(
        'Condiciones',
        'condiciones',
        options: const ['Bueno', 'Regular', 'Malo'],
      ),
      _FieldDef('Control de tránsito', 'control_transito', multiline: true),
      _FieldDef(
        'Checaron antecedentes',
        'checaron_antecedentes',
        type: _FieldType.bool01,
      ),
      _FieldDef('Causas', 'causas', multiline: true),
      _FieldDef('Colisión/camino', 'colision_camino', multiline: true),
    ];

    final camposDanos = <_FieldDef>[
      _FieldDef(
        'Daños patrimoniales',
        'danos_patrimoniales',
        type: _FieldType.bool01,
      ),
      _FieldDef(
        'Propiedades afectadas',
        'propiedades_afectadas',
        multiline: true,
      ),
      _FieldDef(
        'Monto daños patrimoniales',
        'monto_danos_patrimoniales',
        keyboardType: TextInputType.number,
      ),
    ];

    final camposMP = <_FieldDef>[
      _FieldDef('Oficio MP', 'oficio_mp'),
      _FieldDef(
        'Vehículos MP',
        'vehiculos_mp',
        keyboardType: TextInputType.number,
      ),
      _FieldDef(
        'Personas MP',
        'personas_mp',
        keyboardType: TextInputType.number,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: Text('Hecho #$hechoId'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.hechosBuscar),
          ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _bootstrapTrackingStatusOnly();
              await _cargarHecho(hechoId);
            },
          ),
        ],
      ),
      drawer: AppDrawer(
        trackingOn: _trackingOn,
        onLogout: () => _logout(context),
      ),
      bottomNavigationBar: (_cargando || _hecho == null || _hecho!.isEmpty)
          ? null
          : _bottomActions(hechoId),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _bootstrapTrackingStatusOnly();
            await _cargarHecho(hechoId);
          },
          child: _cargando
              ? ListView(
                  children: const [
                    SizedBox(height: 140),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : (_hecho == null || _hecho!.isEmpty)
              ? const Center(child: Text('No se pudo cargar el hecho.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 190),
                  children: [
                    if (_trackingOn) HeaderCard(trackingOn: _trackingOn),
                    if (_trackingOn) const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fotos del hecho (vehículos)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (fotos.isEmpty)
                              Text(
                                'Sin fotos registradas.',
                                style: TextStyle(color: Colors.grey.shade700),
                              )
                            else ...[
                              Text(
                                'Total: ${fotos.length} (vehículos: ${vehiculos.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              _fotosStrip(fotos),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _photoCard(hechoId),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: const [
                            Icon(Icons.touch_app),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tip: doble tap para editar. Hora y fecha solo se editan en la web.',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _sectionTitle('Identificación'),
                    _buildEditableFields(hechoId, camposIdentificacion),
                    _sectionTitle('Tiempo y lugar'),
                    _buildEditableFields(hechoId, camposTiempoLugar),
                    _sectionTitle('Clasificación'),
                    _buildEditableFields(hechoId, camposClasificacion),
                    _sectionTitle('Daños'),
                    _buildEditableFields(hechoId, camposDanos),
                    _sectionTitle('Ministerio Público'),
                    _buildEditableFields(hechoId, camposMP),
                    const SizedBox(height: 18),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onDoubleTap;
  final Widget? trailing;

  const _InfoTile(this.label, this.value, {this.onDoubleTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final isMissing = value.startsWith('⛔');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onDoubleTap: onDoubleTap,
        child: ListTile(
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            value,
            style: TextStyle(color: isMissing ? Colors.red : null),
          ),
          trailing: trailing,
        ),
      ),
    );
  }
}

enum _FieldType { text, bool01 }

class _FieldDef {
  final String label;
  final String key;
  final _FieldType type;

  final bool editable;
  final bool multiline;
  final TextInputType keyboardType;
  final List<String>? options;

  const _FieldDef(
    this.label,
    this.key, {
    this.type = _FieldType.text,
    this.editable = true,
    this.multiline = false,
    this.keyboardType = TextInputType.text,
    this.options,
  });
}

enum _PhotoKind { lugar, situacion }
