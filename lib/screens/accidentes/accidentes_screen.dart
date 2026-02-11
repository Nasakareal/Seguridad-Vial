import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/app_version_service.dart';

import '../../widgets/app_drawer.dart';
import '../../widgets/header_card.dart';

import '../login_screen.dart';
import '../../main.dart' show AppRoutes;

class AccidentesScreen extends StatefulWidget {
  const AccidentesScreen({super.key});

  @override
  State<AccidentesScreen> createState() => _AccidentesScreenState();
}

class _AccidentesScreenState extends State<AccidentesScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _hechos = [];
  bool _cargando = true;

  late String _fechaSeleccionada;

  final Set<int> _descargando = <int>{};

  bool _trackingOn = false;
  bool _bootstrapped = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fechaSeleccionada = _fmtYmd(DateTime.now());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AppVersionService.enforceUpdateIfNeeded(context);
      await _bootstrapTrackingStatusOnly();
      await _obtenerHechos();
    });
  }

  Future<void> _bootstrapTrackingStatusOnly() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final running = await FlutterForegroundTask.isRunningService;
    if (!mounted) return;
    setState(() => _trackingOn = running);
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

  void _go(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }

  String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  bool get _isHoy => _fechaSeleccionada == _fmtYmd(DateTime.now());

  String _safeText(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '—' : s;
  }

  String _ubicacion(Map<String, dynamic> h) {
    final calle = _safeText(h['calle']);
    final col = _safeText(h['colonia']);
    final mun = _safeText(h['municipio']);

    final partes = <String>[];
    if (calle != '—') partes.add(calle);
    if (col != '—') partes.add(col);
    if (mun != '—') partes.add(mun);

    return partes.isEmpty ? '—' : partes.join(', ');
  }

  String _toPublicUrl(String pathOrUrl) {
    final p = pathOrUrl.trim();
    if (p.isEmpty) return '';

    final lower = p.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return p;

    final root = AuthService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

    if (p.startsWith('/storage/')) {
      return '$root$p';
    }

    if (p.startsWith('storage/')) {
      return '$root/$p';
    }

    return '$root/storage/$p';
  }

  List<Map<String, dynamic>> _vehiculosDeHecho(Map<String, dynamic> hecho) {
    final v = hecho['vehiculos'];
    if (v is List) {
      return v
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }

  String _fotoHechoUrl(Map<String, dynamic> hecho) {
    final candidates = [
      'foto_lugar_url',
      'foto_lugar_path',
      'foto_lugar',
      'foto_hecho_url',
      'foto_hecho_path',
      'foto_hecho',
    ];

    for (final k in candidates) {
      final v = (hecho[k] ?? '').toString().trim();
      if (v.isNotEmpty) return _toPublicUrl(v);
    }

    return '';
  }

  String _fotoConvenioUrl(Map<String, dynamic> hecho) {
    final candidates = [
      'convenio_url',
      'convenio_path',
      'convenio',
      'descargo_url',
      'descargo_path',
      'descargo',
    ];

    for (final k in candidates) {
      final v = (hecho[k] ?? '').toString().trim();
      if (v.isNotEmpty) return _toPublicUrl(v);
    }

    return '';
  }

  List<String> _fotosDeVehiculos(Map<String, dynamic> hecho) {
    final vehs = _vehiculosDeHecho(hecho);
    final out = <String>[];

    for (final v in vehs) {
      final fotosUrl = v['fotos_url'];
      if (fotosUrl is String && fotosUrl.trim().isNotEmpty) {
        out.add(fotosUrl.trim());
        continue;
      }

      final fotosUrls = v['fotos_urls'];
      if (fotosUrls is List) {
        for (final x in fotosUrls) {
          final s = (x ?? '').toString().trim();
          if (s.isNotEmpty) out.add(s);
        }
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

  Future<void> _obtenerHechos() async {
    if (!mounted) return;
    setState(() => _cargando = true);

    final token = await AuthService.getToken();

    try {
      final uri = Uri.parse('${AuthService.baseUrl}/hechos').replace(
        queryParameters: {'per_page': '100', 'fecha': _fechaSeleccionada},
      );

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final raw = jsonDecode(response.body);
      List<dynamic> datos;

      if (raw is List) {
        datos = raw;
      } else if (raw is Map<String, dynamic> && raw['data'] is List) {
        datos = raw['data'] as List<dynamic>;
      } else if (raw is Map<String, dynamic> && raw['hechos'] is List) {
        datos = raw['hechos'] as List<dynamic>;
      } else {
        datos = [];
      }

      final List<Map<String, dynamic>> hechosMap = datos
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _hechos = hechosMap;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('No se pudieron obtener los hechos.\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _seleccionarFecha() async {
    final now = DateTime.now();

    if (!_isHoy) {
      setState(() => _fechaSeleccionada = _fmtYmd(now));
      await _obtenerHechos();
      return;
    }

    final initial = DateTime.tryParse(_fechaSeleccionada) ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (!mounted) return;

    if (picked != null) {
      setState(() => _fechaSeleccionada = _fmtYmd(picked));
      await _obtenerHechos();
    }
  }

  void _abrirEdit(Map<String, dynamic> hecho) {
    final id = hecho['id'];
    if (id == null) return;

    Navigator.pushNamed(
      context,
      '/accidentes/show',
      arguments: {'hechoId': id},
    );
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

  Future<void> _descargarReporte(int hechoId) async {
    if (_descargando.contains(hechoId)) return;

    setState(() => _descargando.add(hechoId));

    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
      }

      final uri = Uri.parse(
        '${AuthService.baseUrl}/hechos/$hechoId/reporte-doc',
      );

      final headers = <String, String>{
        'Accept': 'application/octet-stream',
        'Authorization': 'Bearer $token',
      };

      final resp = await http.get(uri, headers: headers);

      if (resp.statusCode != 200) {
        final msg = _parseBackendError(resp.body, resp.statusCode);
        throw Exception(msg);
      }

      final Uint8List bytes = resp.bodyBytes;
      const ext = 'doc';
      final baseName = 'hecho_$hechoId';

      await FileSaver.instance.saveFile(
        name: baseName,
        bytes: bytes,
        ext: ext,
        mimeType: MimeType.microsoftWord,
      );

      final tmpDir = await getTemporaryDirectory();
      final tmpPath = '${tmpDir.path}/$baseName.$ext';
      final tmpFile = File(tmpPath);
      await tmpFile.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles([
        XFile(tmpFile.path),
      ], text: 'Informe del hecho $hechoId');

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
      if (mounted) {
        setState(() => _descargando.remove(hechoId));
      }
    }
  }

  Widget _fotosStrip(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 72,
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

  Widget _onePhotoBlock(String label, String url) {
    if (url.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoy = _fmtYmd(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Hechos / Accidentes'),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed: () => _go(context, AppRoutes.hechosBuscar),
          ),
          IconButton(
            icon: Icon(_isHoy ? Icons.date_range : Icons.clear),
            tooltip: _isHoy ? 'Filtrar por fecha' : 'Volver a hoy ($hoy)',
            onPressed: _seleccionarFecha,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _obtenerHechos,
          ),
        ],
      ),
      drawer: AppDrawer(
        trackingOn: _trackingOn,
        onLogout: () => _logout(context),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _bootstrapTrackingStatusOnly();
            await _obtenerHechos();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (_trackingOn) HeaderCard(trackingOn: _trackingOn),
              if (_trackingOn) const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.blue.withOpacity(.06),
                  border: Border.all(color: Colors.blue.withOpacity(.18)),
                ),
                child: Text(
                  'Mostrando hechos del día: $_fechaSeleccionada',
                  style: TextStyle(color: Colors.blue.shade900),
                ),
              ),
              const SizedBox(height: 12),
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_hechos.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text('No hay hechos para esta fecha.')),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _hechos.length,
                  itemBuilder: (context, index) {
                    final hecho = _hechos[index];

                    final folio = _safeText(hecho['folio_c5i']);
                    final fecha = _safeText(hecho['fecha']);
                    final hora = _safeText(hecho['hora']);
                    final situacion = _safeText(hecho['situacion']);
                    final perito = _safeText(hecho['perito']);

                    final fotoHecho = _fotoHechoUrl(hecho);
                    final fotosVehiculos = _fotosDeVehiculos(hecho);
                    final fotoConvenio = _fotoConvenioUrl(hecho);

                    final id = hecho['id'];
                    final hechoId = (id is int) ? id : int.tryParse('$id');
                    final isDownloading =
                        hechoId != null && _descargando.contains(hechoId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.directions_car),
                          title: Text('Folio: $folio'),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fecha: $fecha ${hora == '—' ? '' : hora}'
                                      .trim(),
                                ),
                                Text('Ubicación: ${_ubicacion(hecho)}'),
                                Text('Situación: $situacion'),
                                Text('Perito: $perito'),

                                _onePhotoBlock('Foto del hecho', fotoHecho),

                                if (fotosVehiculos.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      'Fotos de vehículos: ${fotosVehiculos.length}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                _fotosStrip(fotosVehiculos),

                                _onePhotoBlock(
                                  'Convenio / Descargo',
                                  fotoConvenio,
                                ),
                              ],
                            ),
                          ),
                          isThreeLine: true,
                          onTap: () => _abrirEdit(hecho),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: isDownloading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.download),
                                tooltip: 'Descargar informe',
                                onPressed: (hechoId == null || isDownloading)
                                    ? null
                                    : () => _descargarReporte(hechoId),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Editar',
                                onPressed: () => _abrirEdit(hecho),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/accidentes/create'),
        tooltip: 'Crear nuevo hecho',
        child: const Icon(Icons.add),
      ),
    );
  }
}
