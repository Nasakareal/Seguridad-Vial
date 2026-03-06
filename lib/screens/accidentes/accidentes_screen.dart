import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:seguridad_vial_app/app/routes.dart';

import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/app_version_service.dart';
import '../../services/accidentes_service.dart';

import '../../widgets/app_drawer.dart';
import '../../widgets/header_card.dart';

import '../login_screen.dart';
import 'edit_screen.dart';

import 'widgets/hecho_card.dart';

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
  final Set<int> _enviandoWhatsapp = <int>{};

  bool _trackingOn = false;
  bool _bootstrapped = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fechaSeleccionada = _fmtYmd(DateTime.now());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await AppVersionService.enforceUpdateIfNeeded(context);
        if (!mounted) return;
      } catch (_) {}

      try {
        await _bootstrapTrackingStatusOnly();
        if (!mounted) return;
      } catch (_) {}

      try {
        await _obtenerHechos();
        if (!mounted) return;
      } catch (_) {}
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
      try {
        await TrackingService.stop();
      } catch (_) {}
      try {
        await AuthService.logout();
      } catch (_) {}
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

    if (p.startsWith('/storage/')) return '$root$p';
    if (p.startsWith('storage/')) return '$root/$p';

    return '$root/storage/$p';
  }

  List<Map<String, dynamic>> _vehiculosDeHecho(Map<String, dynamic> hecho) {
    final v = hecho['vehiculos'];
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
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

  bool _whatsappYaEnviado(Map<String, dynamic> hecho) {
    final v = hecho['whatsapp_sent_at'];
    if (v == null) return false;
    final s = v.toString().trim();
    return s.isNotEmpty && s != 'null';
  }

  int? _hechoIdFromMap(Map<String, dynamic> hecho) {
    final id = hecho['id'];
    if (id == null) return null;
    if (id is int) return id;
    return int.tryParse('$id');
  }

  Future<void> _obtenerHechos() async {
    if (!mounted) return;
    setState(() => _cargando = true);

    try {
      final hechosMap = await AccidentesService.fetchHechos(
        fecha: _fechaSeleccionada,
        perPage: 100,
      );

      if (!mounted) return;
      setState(() {
        _hechos = hechosMap;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);

      if (!mounted) return;
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

  void _abrirShow(Map<String, dynamic> hecho) {
    final hechoId = _hechoIdFromMap(hecho);
    if (hechoId == null || hechoId <= 0) return;

    Navigator.pushNamed(
      context,
      AppRoutes.accidentesShow,
      arguments: {'hechoId': hechoId},
    );
  }

  void _abrirEdit(Map<String, dynamic> hecho) {
    final hechoId = _hechoIdFromMap(hecho);
    if (hechoId == null || hechoId <= 0) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditHechoScreen(hechoId: hechoId)),
    );
  }

  Future<void> _descargarReporte(int hechoId) async {
    if (_descargando.contains(hechoId)) return;

    setState(() => _descargando.add(hechoId));

    try {
      final Uint8List bytes = await AccidentesService.downloadReporteDoc(
        hechoId: hechoId,
      );

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
      if (mounted) setState(() => _descargando.remove(hechoId));
    }
  }

  Future<bool> _confirmarEnviarWhatsapp() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('¿Enviar este hecho al grupo de WhatsApp?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    return res == true;
  }

  Future<void> _enviarWhatsapp(int hechoId) async {
    if (_enviandoWhatsapp.contains(hechoId)) return;

    final okConfirm = await _confirmarEnviarWhatsapp();
    if (!okConfirm) return;

    setState(() => _enviandoWhatsapp.add(hechoId));

    try {
      final message = await AccidentesService.enviarWhatsapp(hechoId: hechoId);

      if (!mounted) return;

      final idx = _hechos.indexWhere((h) {
        final id = h['id'];
        final hid = (id is int) ? id : int.tryParse('$id');
        return hid == hechoId;
      });

      if (idx != -1) {
        final updated = Map<String, dynamic>.from(_hechos[idx]);
        updated['whatsapp_sent_at'] =
            updated['whatsapp_sent_at'] ?? DateTime.now().toIso8601String();
        final newList = List<Map<String, dynamic>>.from(_hechos);
        newList[idx] = updated;
        setState(() => _hechos = newList);
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('No se pudo enviar a WhatsApp.\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _enviandoWhatsapp.remove(hechoId));
    }
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
                  color: Colors.blue.withValues(alpha: 0.06),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.18),
                  ),
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

                    final hechoId = _hechoIdFromMap(hecho);

                    final isDownloading =
                        hechoId != null && _descargando.contains(hechoId);

                    final yaEnviado = _whatsappYaEnviado(hecho);
                    final isSending =
                        hechoId != null && _enviandoWhatsapp.contains(hechoId);

                    return HechoCard(
                      hecho: hecho,
                      folio: folio,
                      fecha: fecha,
                      hora: hora,
                      situacion: situacion,
                      perito: perito,
                      ubicacion: _ubicacion(hecho),
                      fotoHecho: fotoHecho,
                      fotosVehiculos: fotosVehiculos,
                      fotoConvenio: fotoConvenio,
                      isDownloading: isDownloading,
                      isSending: isSending,
                      yaEnviado: yaEnviado,
                      onTapShow: () => _abrirShow(hecho),
                      onTapEdit: () => _abrirEdit(hecho),
                      onDownload: (hechoId == null || isDownloading)
                          ? null
                          : () => _descargarReporte(hechoId),
                      onEnviarWhatsapp:
                          (hechoId == null || yaEnviado || isSending)
                          ? null
                          : () => _enviarWhatsapp(hechoId),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.accidentesCreate),
        tooltip: 'Crear nuevo hecho',
        child: const Icon(Icons.add),
      ),
    );
  }
}
