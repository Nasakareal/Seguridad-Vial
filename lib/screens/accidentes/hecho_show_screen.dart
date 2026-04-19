import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/app_version_service.dart';
import '../../services/hecho_share_service.dart';

import '../../widgets/app_drawer.dart';
import '../../widgets/header_card.dart';

import '../login_screen.dart';
import '../../app/routes.dart';

import 'hecho_show/hecho_show_helpers.dart';
import 'widgets/hecho_card.dart';

class HechoShowScreen extends StatefulWidget {
  const HechoShowScreen({super.key});

  @override
  State<HechoShowScreen> createState() => _HechoShowScreenState();
}

class _HechoShowScreenState extends State<HechoShowScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _hecho;
  bool _cargando = true;
  String? _error;

  bool _trackingOn = false;
  bool _bootstrapped = false;
  bool _busy = false;
  bool _initialized = false;
  int _hechoId = 0;
  bool _sharingWhatsapp = false;
  bool _canEditAnyHecho = false;
  bool _hechosModuleExcluded = false;
  int? _currentUserId;

  Future<void> _bootstrapTrackingStatusOnly() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final running = await TrackingService.isRunning();
    if (!mounted) return;
    setState(() => _trackingOn = running);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _hechoId = HechoShowHelpers.hechoIdFromArgs(context);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await AppVersionService.enforceUpdateIfNeeded(context);
        if (!mounted) return;
      } catch (_) {}

      await _bootstrapTrackingStatusOnly();
      if (!mounted) return;

      await _loadEditAccess(refresh: true);
      if (!mounted) return;

      if (_hechoId > 0) {
        await _cargarHecho(_hechoId);
      } else if (mounted) {
        setState(() => _cargando = false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final running = await TrackingService.isRunning();
      await _loadEditAccess(refresh: true);
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
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final token = await AuthService.getToken();
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri = Uri.parse('${AuthService.baseUrl}/hechos/$id');
      final res = await http.get(uri, headers: headers);

      if (res.statusCode != 200) {
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hecho = null;
        _error = 'No se pudo cargar el hecho: $e';
        _cargando = false;
      });
    }
  }

  Future<void> _loadEditAccess({bool refresh = false}) async {
    if (refresh) {
      try {
        await AuthService.refreshCurrentUserAccess();
      } catch (_) {}
    }

    final canEdit = await AuthService.can('editar hechos');
    final excluded = await AuthService.isHechosModuleExcludedUser();
    final userId = await AuthService.getUserId();
    final role = (await AuthService.getRole())?.trim().toLowerCase() ?? '';
    final canEditAny =
        canEdit &&
        !excluded &&
        const {
          'superadmin',
          'administrador',
          'administrativo',
          'subdirector',
        }.contains(role);

    if (!mounted) return;
    setState(() {
      _canEditAnyHecho = canEditAny;
      _hechosModuleExcluded = excluded;
      _currentUserId = userId;
    });
  }

  int? _intFrom(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  bool _boolFrom(dynamic value) {
    if (value is bool) return value;
    final s = (value ?? '').toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'si' || s == 'sí';
  }

  bool _puedeEditarHecho(Map<String, dynamic> hecho) {
    if (_hechosModuleExcluded) return false;

    if (hecho.containsKey('puede_editar')) {
      return _boolFrom(hecho['puede_editar']);
    }

    if (_canEditAnyHecho) return true;

    final createdBy = _intFrom(hecho['created_by'] ?? hecho['createdBy']);
    return _currentUserId != null && createdBy == _currentUserId;
  }

  Future<void> _goEdit(int hechoId) async {
    if (hechoId <= 0) return;
    if (_hecho != null && !_puedeEditarHecho(_hecho!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permiso para editar este hecho.'),
        ),
      );
      return;
    }

    await Navigator.pushNamed(
      context,
      AppRoutes.accidentesEdit,
      arguments: hechoId,
    );

    if (!mounted) return;
    await _bootstrapTrackingStatusOnly();
    await _cargarHecho(hechoId);
  }

  Future<void> _compartirWhatsapp(int hechoId) async {
    if (_sharingWhatsapp || hechoId <= 0) return;

    setState(() => _sharingWhatsapp = true);

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
      if (mounted) setState(() => _sharingWhatsapp = false);
    }
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<_KV> items,
    bool initiallyExpanded = true,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map((e) => _KVCard(label: e.k, value: e.v, full: e.full))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _quickActions(int hechoId) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/accidentes/vehiculos',
                        arguments: {'hechoId': hechoId},
                      );
                    },
                    icon: const Icon(Icons.directions_car),
                    label: const Text('Vehículos'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
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
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.accidentesCroquis,
                        arguments: {'hechoId': hechoId},
                      );
                    },
                    icon: const Icon(Icons.draw),
                    label: const Text('Croquis'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pendiente: conectar descargo'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Descargo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hechoId = _hechoId;

    final h = _hecho ?? {};
    final puedeEditar = _hecho != null && _puedeEditarHecho(_hecho!);

    final folio = HechoShowHelpers.safeText(h['folio_c5i']);
    final fecha = HechoShowHelpers.safeText(h['fecha']);
    final hora = HechoShowHelpers.safeText(h['hora']);

    final situacion = (() {
      final s = (h['situacion'] ?? '').toString().trim();
      return s.isEmpty ? '—' : HechoShowHelpers.normalizeSituacion(s);
    })();

    final perito = HechoShowHelpers.safeText(h['perito']);

    final ubicacion = (() {
      final muni = HechoShowHelpers.safeText(h['municipio']);
      final calle = HechoShowHelpers.safeText(h['calle']);
      if (muni == '—' && calle == '—') return '—';
      if (muni == '—') return calle;
      if (calle == '—') return muni;
      return '$muni · $calle';
    })();

    final fotoHecho = HechoShowHelpers.fotoLugarUrl(_hecho);
    final fotoSituacion = HechoShowHelpers.fotoSituacionUrl(_hecho);
    final fotosVehiculos = HechoShowHelpers.fotosVehiculosFromHecho(_hecho);

    final fotoConvenio = (() {
      final raw =
          (h['foto_convenio_url'] ??
                  h['convenio_url'] ??
                  h['descargo_url'] ??
                  h['foto_convenio'] ??
                  h['convenio'] ??
                  h['descargo'] ??
                  '')
              .toString()
              .trim();
      return raw.isEmpty ? '' : HechoShowHelpers.toPublicUrl(raw);
    })();

    final identificacion = <_KV>[
      _KV('ID', HechoShowHelpers.safeText(h['id'])),
      _KV('Folio C5i', folio),
      _KV('Perito', perito),
      _KV('Unidad', HechoShowHelpers.safeText(h['unidad'])),
      _KV('Situación', situacion),
      _KV(
        'Tipo de hecho',
        HechoShowHelpers.safeText(h['tipo_hecho']),
        full: true,
      ),
    ];

    final tiempoLugar = <_KV>[
      _KV('Fecha', fecha),
      _KV('Hora', hora),
      _KV(
        'Sector',
        (() {
          final s = (h['sector'] ?? '').toString().trim();
          return s.isEmpty ? '—' : HechoShowHelpers.normalizeSector(s);
        })(),
      ),
      _KV('Municipio', HechoShowHelpers.safeText(h['municipio'])),
      _KV('Calle', HechoShowHelpers.safeText(h['calle']), full: true),
      _KV('Colonia', HechoShowHelpers.safeText(h['colonia']), full: true),
      _KV(
        'Entre calles',
        HechoShowHelpers.safeText(h['entre_calles']),
        full: true,
      ),
    ];

    final clasificacion = <_KV>[
      _KV('Superficie de vía', HechoShowHelpers.safeText(h['superficie_via'])),
      _KV('Tiempo', HechoShowHelpers.safeText(h['tiempo'])),
      _KV('Clima', HechoShowHelpers.safeText(h['clima'])),
      _KV('Condiciones', HechoShowHelpers.safeText(h['condiciones'])),
      _KV(
        'Control de tránsito',
        HechoShowHelpers.safeText(h['control_transito']),
        full: true,
      ),
      _KV(
        'Checaron antecedentes',
        HechoShowHelpers.safeBool01(h['checaron_antecedentes']),
      ),
      _KV('Causas', HechoShowHelpers.safeText(h['causas']), full: true),
      _KV(
        'Responsable',
        HechoShowHelpers.safeText(h['responsable']),
        full: true,
      ),
      _KV(
        'Colisión/camino',
        HechoShowHelpers.safeText(h['colision_camino']),
        full: true,
      ),
    ];

    final danos = <_KV>[
      _KV(
        'Daños patrimoniales',
        HechoShowHelpers.safeBool01(h['danos_patrimoniales']),
      ),
      _KV(
        'Propiedades afectadas',
        HechoShowHelpers.safeText(h['propiedades_afectadas']),
        full: true,
      ),
      _KV(
        'Monto daños',
        HechoShowHelpers.safeText(h['monto_danos_patrimoniales']),
      ),
    ];

    final mp = <_KV>[
      _KV('Oficio MP', HechoShowHelpers.safeText(h['oficio_mp']), full: true),
      _KV('Vehículos MP', HechoShowHelpers.safeText(h['vehiculos_mp'])),
      _KV('Personas MP', HechoShowHelpers.safeText(h['personas_mp'])),
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
          if (puedeEditar)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit),
              onPressed: () => _goEdit(hechoId),
            ),
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
              if (hechoId > 0) await _cargarHecho(hechoId);
            },
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
            if (hechoId > 0) await _cargarHecho(hechoId);
          },
          child: _cargando
              ? ListView(
                  children: const [
                    SizedBox(height: 140),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : _error != null
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: hechoId > 0
                          ? () => _cargarHecho(hechoId)
                          : null,
                      child: const Text('Reintentar'),
                    ),
                  ],
                )
              : (_hecho == null || _hecho!.isEmpty)
              ? const Center(child: Text('No se pudo cargar el hecho.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  children: [
                    if (_trackingOn) HeaderCard(trackingOn: _trackingOn),
                    if (_trackingOn) const SizedBox(height: 12),

                    HechoCard(
                      hecho: _hecho!,
                      folio: folio,
                      fecha: fecha,
                      hora: hora,
                      situacion: situacion,
                      perito: perito,
                      ubicacion: ubicacion,
                      fotoHecho: fotoHecho,
                      fotoSituacion: fotoSituacion,
                      fotosVehiculos: fotosVehiculos,
                      fotoConvenio: fotoConvenio,
                      isDownloading: false,
                      isSending: _sharingWhatsapp,
                      onTapShow: () {},
                      onTapEdit: puedeEditar ? () => _goEdit(hechoId) : null,
                      onDownload: null,
                      onEnviarWhatsapp: hechoId > 0
                          ? () => _compartirWhatsapp(hechoId)
                          : null,
                    ),

                    if (puedeEditar) ...[
                      _quickActions(hechoId),
                      const SizedBox(height: 12),
                    ],

                    _section(
                      title: 'Identificación',
                      icon: Icons.badge,
                      items: identificacion,
                      initiallyExpanded: true,
                    ),
                    _section(
                      title: 'Tiempo y lugar',
                      icon: Icons.place,
                      items: tiempoLugar,
                      initiallyExpanded: false,
                    ),
                    _section(
                      title: 'Clasificación',
                      icon: Icons.category,
                      items: clasificacion,
                      initiallyExpanded: false,
                    ),
                    _section(
                      title: 'Daños',
                      icon: Icons.warning_amber,
                      items: danos,
                      initiallyExpanded: false,
                    ),
                    _section(
                      title: 'Ministerio Público',
                      icon: Icons.gavel,
                      items: mp,
                      initiallyExpanded: false,
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
        ),
      ),
    );
  }
}

class _KV {
  final String k;
  final String v;
  final bool full;
  const _KV(this.k, this.v, {this.full = false});
}

class _KVCard extends StatelessWidget {
  final String label;
  final String value;
  final bool full;

  const _KVCard({required this.label, required this.value, this.full = false});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final double target = full ? (w - 32) : ((w - 32 - 10) / 2);

    return SizedBox(
      width: target,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: value == '—' ? Colors.grey.shade700 : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
