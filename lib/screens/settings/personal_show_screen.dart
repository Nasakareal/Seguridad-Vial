import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../services/settings_personal_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/permission_guard.dart';
import '../../widgets/photo_viewer.dart';
import '../../widgets/safe_network_image.dart';
import '../login_screen.dart';

class PersonalShowScreen extends StatefulWidget {
  const PersonalShowScreen({super.key});

  @override
  State<PersonalShowScreen> createState() => _PersonalShowScreenState();
}

class _PersonalShowScreenState extends State<PersonalShowScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _canEdit = false;
  String? _error;
  Map<String, dynamic>? _personal;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_personal == null && _loading) {
      _load();
    }
  }

  int? _idFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final raw = args['personal_id'] ?? args['id'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '');
    }
    if (args is int) return args;
    return int.tryParse(args?.toString() ?? '');
  }

  Future<void> _load() async {
    final id = _idFromArgs();
    if (id == null || id <= 0) {
      setState(() {
        _loading = false;
        _error = 'Falta personal_id.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final isSuperadmin = await AuthService.isSuperadmin();
      final canEdit = isSuperadmin || await AuthService.can('editar personal');
      final personal = await SettingsPersonalService.show(id);
      if (!mounted) return;
      setState(() {
        _canEdit = canEdit;
        _personal = personal;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'No se pudo cargar el personal.\n${SettingsPersonalService.cleanExceptionMessage(e)}';
      });
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

  Future<void> _addIncidencia() async {
    final personal = _personal;
    final id = _int(personal?['id']);
    if (id <= 0) return;

    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.settingsPersonalIncidenciaCreate,
      arguments: {
        'personal_id': id,
        'personal_name': _text(personal?['nombre_completo'], 'Personal'),
      },
    );

    if (changed == true && mounted) {
      await _load();
    }
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _text(dynamic value, [String fallback = '-']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _nestedName(dynamic raw, [String fallback = '-']) {
    if (raw is Map) {
      return _text(
        raw['nombre'] ?? raw['name'] ?? raw['numero_economico'],
        fallback,
      );
    }
    return fallback;
  }

  List<Map<String, dynamic>> _list(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final personal = _personal;
    final name = _text(personal?['nombre_completo'], 'Personal');
    final incidencias = _list(personal?['incidencias']);
    final photoUrl = SettingsPersonalService.photoUrlFor(personal);

    return PermissionGuard(
      permission: 'ver personal',
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.blue,
          title: const Text('Detalle de personal'),
          actions: [
            IconButton(
              tooltip: 'Agregar incidencia',
              onPressed: personal == null || !_canEdit ? null : _addIncidencia,
              icon: const Icon(Icons.add_alert_outlined),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
            const AccountMenuAction(),
          ],
        ),
        endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _card(
                    title: 'Error',
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  )
                else if (personal == null)
                  const Center(child: Text('Sin datos.'))
                else ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        _headerAvatar(name, photoUrl),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_text(personal['grado'], 'Sin grado')} · ${_text(personal['estatus'], 'Sin estatus')}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .8),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _card(
                    title: 'Datos principales',
                    child: Column(
                      children: [
                        _row('Empleado', _text(personal['numero_empleado'])),
                        _row('Nombre', name),
                        _row('CURP', _text(personal['curp'])),
                        _row('RFC', _text(personal['rfc'])),
                        _row('CUIP', _text(personal['cuip'])),
                        _row('CUP', _text(personal['cup'])),
                        _row('Puesto', _text(personal['puesto'])),
                        _row('Categoria', _text(personal['categoria'])),
                        _row('Ingreso', _formatDate(personal['fecha_ingreso'])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _card(
                    title: 'Asignacion',
                    child: Column(
                      children: [
                        _row(
                          'Unidad',
                          _nestedName(personal['unidad'], 'Sin unidad'),
                        ),
                        _row('Turno', _nestedName(personal['turno'])),
                        _row('Patrulla', _nestedName(personal['patrulla'])),
                        _row('Adscripcion', _text(personal['adscripcion'])),
                        _row('Area', _text(personal['area'])),
                        _row(
                          'Usuario',
                          _nestedName(personal['user'], 'Sin usuario'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _card(
                    title: 'Incidencias',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_canEdit) ...[
                          ElevatedButton.icon(
                            onPressed: _addIncidencia,
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar incidencia'),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (incidencias.isEmpty)
                          const Text('No hay incidencias registradas.')
                        else
                          ...incidencias.map(_incidenciaTile),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _headerAvatar(String name, String photoUrl) {
    Widget fallback() {
      return CircleAvatar(
        radius: 30,
        backgroundColor: Colors.white.withValues(alpha: .14),
        child: Text(
          _initials(name),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    final url = photoUrl.trim();
    if (url.isEmpty) return fallback();

    return Tooltip(
      message: 'Ver foto',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () =>
            showPhotoViewer(context: context, title: name, photoUrl: url),
        child: ClipOval(
          child: SafeNetworkImage(
            url,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback(),
            loadingBuilder: (context, progress) => fallback(),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _incidenciaTile(Map<String, dynamic> item) {
    final tipo = _text(item['tipo_nombre'] ?? item['tipo'], 'Incidencia');
    final inicio = _formatDate(item['fecha_inicio']);
    final fin = _formatDate(item['fecha_fin']);
    final folio = _text(item['folio'], '');
    final motivo = _text(item['motivo'], '');
    final activo = item['activo'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: activo
            ? Colors.orange.withValues(alpha: .08)
            : Colors.grey.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activo
              ? Colors.orange.withValues(alpha: .22)
              : Colors.grey.withValues(alpha: .22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tipo,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _Pill(text: activo ? 'Activa' : 'Inactiva'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fin == '-' ? 'Desde $inicio' : '$inicio - $fin',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (folio.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Folio: $folio'),
          ],
          if (motivo.isNotEmpty) ...[const SizedBox(height: 4), Text(motivo)],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

String _formatDate(dynamic raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return '-';
  if (text.length >= 10) return text.substring(0, 10);
  return text;
}

String _initials(String raw) {
  final parts = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) return 'P';
  if (parts.length == 1) {
    final text = parts.first;
    return text.substring(0, text.length >= 2 ? 2 : 1).toUpperCase();
  }

  return (parts.first[0] + parts.last[0]).toUpperCase();
}
