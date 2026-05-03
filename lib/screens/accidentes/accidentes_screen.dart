import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:seguridad_vial_app/app/routes.dart';

import '../../core/hechos/hecho_capture_status.dart';
import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/app_version_service.dart';
import '../../services/accidentes_service.dart';
import '../../services/hecho_access_service.dart';
import '../../services/hecho_share_service.dart';
import '../../services/reportes_service.dart';

import '../../widgets/app_drawer.dart';
import '../../widgets/account_drawer.dart';
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
  List<Map<String, dynamic>> _delegaciones = [];
  bool _cargando = true;
  bool _cargandoDelegaciones = false;

  late String _fechaSeleccionada;

  final Set<int> _descargando = <int>{};
  final Set<int> _enviandoWhatsapp = <int>{};

  bool _trackingOn = false;
  bool _bootstrapped = false;
  bool _busy = false;
  bool _canCreateHechos = false;
  bool _canChooseUnidadFiltro = false;
  int _unidadFiltroId = 1;
  int? _delegacionFiltroId;
  HechoEditAccess _editAccess = HechoEditAccess.none;

  static const int _unidadSiniestrosId = 1;
  static const int _soloDelegacionesConHechosId = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fechaSeleccionada = _fmtYmd(DateTime.now());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await AppVersionService.enforceUpdateIfNeeded(context);
        if (!mounted) return;
      } catch (_) {}

      try {
        await _bootstrapTrackingStatusOnly();
        if (!mounted) return;
      } catch (_) {}

      try {
        await _bootstrapFiltrosHechos();
        if (!mounted) return;
      } catch (_) {}

      try {
        await _loadCreateAccess(refresh: true);
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

    final running = await TrackingService.isRunning();
    if (!mounted) return;
    setState(() => _trackingOn = running);
  }

  Future<void> _bootstrapFiltrosHechos() async {
    final canChooseUnidad = await AuthService.hasFullOperationalAccess();
    final unidadId = await AuthService.getUnidadId();
    final isDelegaciones = await AuthService.isDelegacionesUser();

    if (!mounted) return;
    setState(() {
      _canChooseUnidadFiltro = canChooseUnidad;
      if (!canChooseUnidad) {
        _unidadFiltroId = isDelegaciones
            ? AuthService.unidadDelegacionesId
            : (unidadId == AuthService.unidadDelegacionesId
                  ? AuthService.unidadDelegacionesId
                  : _unidadSiniestrosId);
      }
    });

    await _cargarDelegaciones();
  }

  Future<void> _cargarDelegaciones() async {
    if (_cargandoDelegaciones) return;

    if (!mounted) return;
    setState(() => _cargandoDelegaciones = true);

    try {
      final delegaciones = await AccidentesService.fetchDelegacionesCatalogo();
      if (!mounted) return;
      setState(() => _delegaciones = delegaciones);
    } catch (_) {
      if (!mounted) return;
      setState(() => _delegaciones = <Map<String, dynamic>>[]);
    } finally {
      if (mounted) setState(() => _cargandoDelegaciones = false);
    }
  }

  Future<void> _loadCreateAccess({bool refresh = false}) async {
    final canCreate = await AuthService.canCreateHechos(refresh: refresh);
    final editAccess = await HechoAccessService.loadEditAccess();

    if (!mounted) return;
    setState(() {
      _canCreateHechos = canCreate;
      _editAccess = editAccess;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final running = await TrackingService.isRunning();
      await HechoShareService.onAppResumed();
      await _loadCreateAccess(refresh: true);

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

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = (v ?? '').toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'si' || s == 'sí' || s == 'yes';
  }

  String _normalize(String value) {
    return value
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

  int _unidadOrgId(Map<String, dynamic> hecho) {
    final direct = _toInt(
      hecho['unidad_org_id'] ??
          hecho['unidadOrganizacionalId'] ??
          hecho['unidad_id'],
    );
    if (direct > 0) return direct;

    final unidad = _normalize((hecho['unidad'] ?? '').toString());
    if (unidad.contains('DELEGACIONES')) {
      return AuthService.unidadDelegacionesId;
    }
    if (unidad.contains('SINIESTROS')) return _unidadSiniestrosId;

    return 0;
  }

  int _delegacionId(Map<String, dynamic> hecho) {
    final direct = _toInt(hecho['delegacion_id'] ?? hecho['delegacionId']);
    if (direct > 0) return direct;

    final delegacion = hecho['delegacion'];
    if (delegacion is Map) {
      return _toInt(delegacion['id'] ?? delegacion['delegacion_id']);
    }

    return 0;
  }

  bool _esHechoDelegaciones(Map<String, dynamic> hecho) {
    final unidadId = _unidadOrgId(hecho);
    if (unidadId == AuthService.unidadDelegacionesId) return true;
    return unidadId == 0 && _delegacionId(hecho) > 0;
  }

  bool _esDelegacionesIncompleto(Map<String, dynamic> hecho) {
    return _esHechoDelegaciones(hecho) && !_asBool(hecho['captura_completa']);
  }

  String _unidadFiltroLabel() {
    if (_unidadFiltroId == AuthService.unidadDelegacionesId) {
      return 'Delegaciones';
    }
    return 'Siniestros';
  }

  String _delegacionNombre(Map<String, dynamic> delegacion) {
    final nombreConClave = (delegacion['nombre_con_clave'] ?? '')
        .toString()
        .trim();
    if (nombreConClave.isNotEmpty) return nombreConClave;

    final nombre = (delegacion['nombre'] ?? '').toString().trim();
    final clave = (delegacion['clave'] ?? '').toString().trim();
    if (nombre.isEmpty) return 'Delegación';
    if (clave.isEmpty) return nombre;
    return '$nombre ($clave)';
  }

  String _delegacionLabel(Map<String, dynamic> hecho) {
    final nested = hecho['delegacion'];
    if (nested is Map) {
      final label = _delegacionNombre(Map<String, dynamic>.from(nested));
      if (label.trim().isNotEmpty && label != 'Delegación') return label;
    }

    final direct =
        (hecho['delegacion_nombre_con_clave'] ??
                hecho['delegacion_nombre'] ??
                hecho['nombre_delegacion'] ??
                '')
            .toString()
            .trim();
    if (direct.isNotEmpty) return direct;

    final id = _delegacionId(hecho);
    if (id <= 0) return '';

    for (final delegacion in _delegacionesVisiblesParaSelect()) {
      if (_toInt(delegacion['id']) == id) {
        return _delegacionNombre(delegacion);
      }
    }

    return 'Delegación #$id';
  }

  Set<int> _delegacionesConHechosIds() {
    return _hechos
        .where(_esHechoDelegaciones)
        .map(_delegacionId)
        .where((id) => id > 0)
        .toSet();
  }

  List<Map<String, dynamic>> _delegacionesVisiblesParaSelect() {
    final byId = <int, Map<String, dynamic>>{};

    for (final d in _delegaciones) {
      final id = _toInt(d['id']);
      if (id > 0) byId[id] = d;
    }

    for (final hecho in _hechos.where(_esHechoDelegaciones)) {
      final id = _delegacionId(hecho);
      if (id <= 0 || byId.containsKey(id)) continue;
      final label = _delegacionLabelFromRawHecho(hecho);
      byId[id] = {
        'id': id,
        'nombre': label.isEmpty ? 'Delegación #$id' : label,
      };
    }

    final items = byId.values.toList()
      ..sort((a, b) => _delegacionNombre(a).compareTo(_delegacionNombre(b)));
    return items;
  }

  String _delegacionLabelFromRawHecho(Map<String, dynamic> hecho) {
    final direct =
        (hecho['delegacion_nombre_con_clave'] ??
                hecho['delegacion_nombre'] ??
                hecho['nombre_delegacion'] ??
                '')
            .toString()
            .trim();
    if (direct.isNotEmpty) return direct;

    final nested = hecho['delegacion'];
    if (nested is Map) {
      final nombre = (nested['nombre_con_clave'] ?? nested['nombre'] ?? '')
          .toString()
          .trim();
      if (nombre.isNotEmpty) return nombre;
    }

    return '';
  }

  List<Map<String, dynamic>> _hechosFiltrados() {
    var list = _hechos.where((hecho) {
      if (_unidadFiltroId == AuthService.unidadDelegacionesId) {
        return _esHechoDelegaciones(hecho);
      }

      return _unidadOrgId(hecho) == _unidadSiniestrosId;
    }).toList();

    if (_unidadFiltroId == AuthService.unidadDelegacionesId) {
      if (_delegacionFiltroId == _soloDelegacionesConHechosId) {
        final ids = _delegacionesConHechosIds();
        list = list
            .where((hecho) => ids.contains(_delegacionId(hecho)))
            .toList();
      } else if (_delegacionFiltroId != null && _delegacionFiltroId! > 0) {
        list = list
            .where((hecho) => _delegacionId(hecho) == _delegacionFiltroId)
            .toList();
      }
    }

    return list;
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

  String _fotoSituacionUrl(Map<String, dynamic> hecho) {
    final candidates = [
      'foto_situacion_url',
      'foto_situacion_path',
      'foto_situacion',
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

  int? _hechoIdFromMap(Map<String, dynamic> hecho) {
    final id = hecho['id'];
    if (id == null) return null;
    if (id is int) return id;
    return int.tryParse('$id');
  }

  bool _puedeEditarHecho(Map<String, dynamic> hecho) =>
      _editAccess.canEditHecho(hecho);

  void _setUnidadFiltro(int unidadId) {
    if (!_canChooseUnidadFiltro) return;
    if (_unidadFiltroId == unidadId) return;

    setState(() {
      _unidadFiltroId = unidadId;
      _delegacionFiltroId = null;
    });
  }

  void _setDelegacionFiltro(int? delegacionId) {
    if (_delegacionFiltroId == delegacionId) return;
    setState(() => _delegacionFiltroId = delegacionId);
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
      await ReporteHechoService.descargarYCompartirHecho(hechoId: hechoId);

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

  Future<void> _compartirWhatsapp(int hechoId) async {
    if (_enviandoWhatsapp.contains(hechoId)) return;

    setState(() => _enviandoWhatsapp.add(hechoId));

    try {
      await HechoShareService.compartirEnWhatsapp(hechoId: hechoId);
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('No se pudo compartir el hecho.\n\n$e'),
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

  Widget _buildFiltrosCard({required int totalFiltrado}) {
    final delegaciones = _delegacionesVisiblesParaSelect();
    final delegacionIds = delegaciones.map((d) => _toInt(d['id'])).toSet();
    final delegacionValue = _delegacionFiltroId == _soloDelegacionesConHechosId
        ? _soloDelegacionesConHechosId
        : _delegacionFiltroId != null &&
              delegacionIds.contains(_delegacionFiltroId)
        ? _delegacionFiltroId
        : null;

    final totalLabel = totalFiltrado == _hechos.length
        ? '$totalFiltrado hechos'
        : '$totalFiltrado de ${_hechos.length} hechos';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.blue.withValues(alpha: 0.06),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mostrando hechos del día: $_fechaSeleccionada',
            style: TextStyle(
              color: Colors.blue.shade900,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalLabel · Unidad: ${_unidadFiltroLabel()}',
            style: TextStyle(color: Colors.blue.shade900),
          ),
          const SizedBox(height: 12),
          if (_canChooseUnidadFiltro)
            SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: _unidadSiniestrosId,
                  label: Text('Siniestros'),
                  icon: Icon(Icons.car_crash),
                ),
                ButtonSegment<int>(
                  value: AuthService.unidadDelegacionesId,
                  label: Text('Delegaciones'),
                  icon: Icon(Icons.local_police),
                ),
              ],
              selected: {_unidadFiltroId},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                _setUnidadFiltro(selection.first);
              },
            )
          else
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Unidad',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              child: Text(_unidadFiltroLabel()),
            ),
          if (_unidadFiltroId == AuthService.unidadDelegacionesId) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: delegacionValue,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Delegación',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Todas las delegaciones'),
                ),
                const DropdownMenuItem<int?>(
                  value: _soloDelegacionesConHechosId,
                  child: Text('Solo delegaciones con hechos en este día'),
                ),
                ...delegaciones.map((d) {
                  final id = _toInt(d['id']);
                  return DropdownMenuItem<int?>(
                    value: id,
                    child: Text(_delegacionNombre(d)),
                  );
                }),
              ],
              onChanged: _setDelegacionFiltro,
            ),
            if (_cargandoDelegaciones)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Cargando catálogo de delegaciones...',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoy = _fmtYmd(DateTime.now());
    final hechosFiltrados = _hechosFiltrados();

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
          const AccountMenuAction(),
        ],
      ),
      drawer: AppDrawer(trackingOn: _trackingOn),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
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
              _buildFiltrosCard(totalFiltrado: hechosFiltrados.length),
              const SizedBox(height: 12),
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (hechosFiltrados.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text('No hay hechos con los filtros actuales.'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: hechosFiltrados.length,
                  itemBuilder: (context, index) {
                    final hecho = hechosFiltrados[index];

                    final folio = _safeText(hecho['folio_c5i']);
                    final fecha = _safeText(hecho['fecha']);
                    final hora = _safeText(hecho['hora']);
                    final situacion = _safeText(hecho['situacion']);
                    final perito = _safeText(hecho['perito']);
                    final delegacionesIncompleto = _esDelegacionesIncompleto(
                      hecho,
                    );
                    final capturaFaltanteDetalles =
                        HechoCaptureStatus.detallesFaltantes(hecho);
                    final delegacionLabel = _delegacionLabel(hecho);

                    final fotoHecho = _fotoHechoUrl(hecho);
                    final fotoSituacion = _fotoSituacionUrl(hecho);
                    final fotosVehiculos = _fotosDeVehiculos(hecho);
                    final fotoConvenio = _fotoConvenioUrl(hecho);

                    final hechoId = _hechoIdFromMap(hecho);

                    final isDownloading =
                        hechoId != null && _descargando.contains(hechoId);

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
                      fotoSituacion: fotoSituacion,
                      fotosVehiculos: fotosVehiculos,
                      fotoConvenio: fotoConvenio,
                      isDownloading: isDownloading,
                      isSending: isSending,
                      onTapShow: () => _abrirShow(hecho),
                      onTapEdit: _puedeEditarHecho(hecho)
                          ? () => _abrirEdit(hecho)
                          : null,
                      onDownload: (hechoId == null || isDownloading)
                          ? null
                          : () => _descargarReporte(hechoId),
                      onEnviarWhatsapp: (hechoId == null || isSending)
                          ? null
                          : () => _compartirWhatsapp(hechoId),
                      delegacionesIncompleto: delegacionesIncompleto,
                      capturaFaltanteDetalles: delegacionesIncompleto
                          ? capturaFaltanteDetalles
                          : const [],
                      delegacionLabel: _esHechoDelegaciones(hecho)
                          ? delegacionLabel
                          : null,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: _canCreateHechos
          ? FloatingActionButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.accidentesCreate),
              tooltip: 'Crear nuevo hecho',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
