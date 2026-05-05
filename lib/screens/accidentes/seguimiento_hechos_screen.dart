import 'package:flutter/material.dart';

import 'package:seguridad_vial_app/app/routes.dart';

import '../../core/hechos/hecho_capture_status.dart';
import '../../services/accidentes_service.dart';
import '../../services/app_version_service.dart';
import '../../services/auth_service.dart';
import '../../services/hecho_share_service.dart';
import '../../services/reportes_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/safe_network_image.dart';
import '../login_screen.dart';

class SeguimientoHechosScreen extends StatefulWidget {
  const SeguimientoHechosScreen({super.key});

  @override
  State<SeguimientoHechosScreen> createState() =>
      _SeguimientoHechosScreenState();
}

class _SeguimientoHechosScreenState extends State<SeguimientoHechosScreen>
    with WidgetsBindingObserver {
  static const String _periodoSemana = 'SEMANA';
  static const String _periodoMes = 'MES';
  static const String _periodoAnio = 'ANIO';
  static const String _situacionPendiente = 'PENDIENTE';
  static const String _situacionTurnado = 'TURNADO';
  static const String _situacionResuelto = 'RESUELTO';
  static const String _situacionFaltaCompletar = 'FALTA_COMPLETAR';

  final TextEditingController _searchCtrl = TextEditingController();
  final Set<int> _descargando = <int>{};
  final Set<int> _enviandoWhatsapp = <int>{};
  final Set<int> _eliminando = <int>{};

  SeguimientoHechosResponse? _response;
  bool _loading = true;
  bool _trackingOn = false;
  bool _busy = false;
  String? _error;
  String _periodo = _periodoSemana;
  String _situacion = _situacionPendiente;
  String _unidadFiltro = '';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await AppVersionService.enforceUpdateIfNeeded(context);
      } catch (_) {}

      try {
        final running = await TrackingService.isRunning();
        if (mounted) setState(() => _trackingOn = running);
      } catch (_) {}

      await _fetchSeguimiento();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await HechoShareService.onAppResumed();
      try {
        final running = await TrackingService.isRunning();
        if (mounted) setState(() => _trackingOn = running);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
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

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _fetchSeguimiento({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await AccidentesService.fetchSeguimientoHechos(
        periodo: _periodo,
        situacion: _situacion,
        unidadFiltro: _unidadFiltro,
        page: _page,
        perPage: 20,
      );

      if (!mounted) return;
      setState(() {
        _response = response;
        _periodo = response.filters.periodo;
        _situacion = response.filters.situacion;
        _unidadFiltro = response.filters.puedeFiltrarUnidad
            ? response.filters.unidadFiltro
            : '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _hechosFiltrados {
    final hechos = _response?.hechos ?? const <Map<String, dynamic>>[];
    final q = _normalize(_searchCtrl.text);
    if (q.isEmpty) return hechos;

    return hechos.where((hecho) {
      final parts = <String>[
        '${_hechoId(hecho) ?? ''}',
        _text(hecho['folio_c5i']),
        _text(hecho['fecha']),
        _text(hecho['hora']),
        _text(hecho['situacion']),
        _text(hecho['perito']),
        _unidadLabel(hecho),
        _delegacionLabel(hecho),
        _creatorLabel(hecho),
        _ubicacion(hecho),
        ...HechoCaptureStatus.detallesFaltantes(hecho),
      ];

      return _normalize(parts.join(' ')).contains(q);
    }).toList();
  }

  void _setPeriodo(String periodo) {
    if (_periodo == periodo) return;
    setState(() => _periodo = periodo);
    _fetchSeguimiento(resetPage: true);
  }

  void _setSituacion(String situacion) {
    if (_situacion == situacion) return;
    setState(() => _situacion = situacion);
    _fetchSeguimiento(resetPage: true);
  }

  void _setUnidadFiltro(String? unidad) {
    final next = (unidad ?? '').trim();
    if (_unidadFiltro == next) return;
    setState(() => _unidadFiltro = next);
    _fetchSeguimiento(resetPage: true);
  }

  void _abrirShow(Map<String, dynamic> hecho) {
    final id = _hechoId(hecho);
    if (id == null || id <= 0) return;

    Navigator.pushNamed(
      context,
      AppRoutes.accidentesShow,
      arguments: {'hechoId': id},
    );
  }

  void _abrirEdit(Map<String, dynamic> hecho) {
    final id = _hechoId(hecho);
    if (id == null || id <= 0) return;

    Navigator.pushNamed(
      context,
      AppRoutes.accidentesEdit,
      arguments: {'id': id},
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
      _showError('No se pudo descargar el reporte.', e);
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
      _showError('No se pudo compartir el hecho.', e);
    } finally {
      if (mounted) setState(() => _enviandoWhatsapp.remove(hechoId));
    }
  }

  Future<void> _eliminarHecho(int hechoId) async {
    if (_eliminando.contains(hechoId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar hecho'),
        content: const Text('Esta acción no se puede revertir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _eliminando.add(hechoId));

    try {
      await AccidentesService.deleteHecho(hechoId: hechoId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hecho eliminado correctamente.')),
      );
      await _fetchSeguimiento();
    } catch (e) {
      if (!mounted) return;
      _showError('No se pudo eliminar el hecho.', e);
    } finally {
      if (mounted) setState(() => _eliminando.remove(hechoId));
    }
  }

  void _showError(String title, Object error) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text('$title\n\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  int _conteo(String situacion) {
    final key = _periodo.toLowerCase();
    return _response?.conteos[key]?[situacion] ?? 0;
  }

  String _periodoLabel(String periodo) {
    switch (periodo) {
      case _periodoMes:
        return 'Mes';
      case _periodoAnio:
        return 'Año';
      default:
        return 'Semana';
    }
  }

  String _situacionLabel(String situacion) {
    switch (situacion) {
      case _situacionPendiente:
        return 'Pendientes';
      case _situacionTurnado:
        return 'Turnados';
      case _situacionResuelto:
        return 'Resueltos';
      case _situacionFaltaCompletar:
        return 'Falta completar';
      default:
        final raw = situacion.trim();
        return raw.isEmpty || raw == '—' ? 'Sin situación' : raw;
    }
  }

  Color _situacionColor(String situacion) {
    switch (situacion) {
      case _situacionTurnado:
        return const Color(0xFF4338CA);
      case _situacionResuelto:
        return const Color(0xFF047857);
      case _situacionFaltaCompletar:
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFB45309);
    }
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = (value ?? '').toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'si' || s == 'sí' || s == 'yes';
  }

  int? _hechoId(Map<String, dynamic> hecho) {
    final id = hecho['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse((id ?? '').toString());
  }

  String _text(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? '—' : text;
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

  String _nestedText(dynamic raw, List<String> keys) {
    if (raw is! Map) return '';
    final map = Map<String, dynamic>.from(raw);
    for (final key in keys) {
      final value = (map[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _unidadLabel(Map<String, dynamic> hecho) {
    final direct = (hecho['unidad_nombre'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final nested = _nestedText(hecho['unidad_organizacional'], [
      'nombre',
      'name',
    ]);
    if (nested.isNotEmpty) return nested;

    return _text(hecho['unidad']);
  }

  String _delegacionLabel(Map<String, dynamic> hecho) {
    final direct = (hecho['delegacion_nombre'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    return _nestedText(hecho['delegacion'], ['nombre', 'name']);
  }

  String _creatorLabel(Map<String, dynamic> hecho) {
    final direct = (hecho['creator_name'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final nested = _nestedText(hecho['creator'], ['name', 'nombre']);
    if (nested.isNotEmpty) return nested;

    return _text(hecho['perito']);
  }

  String _ubicacion(Map<String, dynamic> hecho) {
    final formatted = (hecho['ubicacion_formateada'] ?? '').toString().trim();
    if (formatted.isNotEmpty) return formatted;

    final parts = <String>[];
    for (final key in const ['calle', 'colonia', 'municipio']) {
      final value = (hecho[key] ?? '').toString().trim();
      if (value.isNotEmpty && value != '—') parts.add(value);
    }

    return parts.isEmpty ? '—' : parts.join(', ');
  }

  String _fechaHora(Map<String, dynamic> hecho) {
    var fecha = _text(hecho['fecha']);
    if (fecha.contains('T')) fecha = fecha.split('T').first;
    if (fecha.contains(' ')) fecha = fecha.split(' ').first;

    var hora = _text(hecho['hora']);
    if (hora != '—' && hora.length >= 5) {
      hora = hora.substring(0, 5);
    }

    return hora == '—' ? fecha : '$fecha $hora';
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

  String _fotoPrincipal(Map<String, dynamic> hecho) {
    for (final key in const [
      'foto_lugar_url',
      'foto_lugar_path',
      'foto_lugar',
      'foto_hecho_url',
      'foto_hecho_path',
      'foto_hecho',
      'foto_situacion_url',
      'foto_situacion_path',
      'foto_situacion',
    ]) {
      final value = (hecho[key] ?? '').toString().trim();
      if (value.isNotEmpty) return _toPublicUrl(value);
    }
    return '';
  }

  Widget _buildPeriodoSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final periodo in const [_periodoSemana, _periodoMes, _periodoAnio])
          ChoiceChip(
            label: Text(_periodoLabel(periodo)),
            selected: _periodo == periodo,
            onSelected: (_) => _setPeriodo(periodo),
            showCheckmark: false,
            avatar: Icon(
              periodo == _periodoSemana
                  ? Icons.view_week_outlined
                  : periodo == _periodoMes
                  ? Icons.calendar_view_month
                  : Icons.calendar_today,
              size: 18,
            ),
          ),
      ],
    );
  }

  Widget _buildFiltros() {
    final filters = _response?.filters;
    final canFilterUnidad = filters?.puedeFiltrarUnidad ?? false;
    final unidadItems = filters?.unidadesFiltro ?? const <String, String>{};

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Filtros de seguimiento',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _loading
                    ? null
                    : () {
                        setState(() {
                          _periodo = _periodoSemana;
                          _situacion = _situacionPendiente;
                          _unidadFiltro = '';
                          _searchCtrl.clear();
                        });
                        _fetchSeguimiento(resetPage: true);
                      },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restablecer'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPeriodoSelector(),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _situacion,
            decoration: const InputDecoration(
              labelText: 'Situación',
              prefixIcon: Icon(Icons.flag_outlined),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value: _situacionPendiente,
                child: Text('Pendientes'),
              ),
              DropdownMenuItem(
                value: _situacionTurnado,
                child: Text('Turnados'),
              ),
              DropdownMenuItem(
                value: _situacionResuelto,
                child: Text('Resueltos'),
              ),
              DropdownMenuItem(
                value: _situacionFaltaCompletar,
                child: Text('Falta completar'),
              ),
            ],
            onChanged: _loading ? null : (value) => _setSituacion(value ?? ''),
          ),
          if (canFilterUnidad) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _unidadFiltro,
              decoration: const InputDecoration(
                labelText: 'Unidad',
                prefixIcon: Icon(Icons.apartment_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Todas')),
                ...unidadItems.entries.map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: _loading ? null : _setUnidadFiltro,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar en esta página',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(Icons.close),
                      onPressed: _searchCtrl.clear,
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConteos() {
    final cards = [
      _ConteoCardData(
        situacion: _situacionPendiente,
        icon: Icons.pending_actions,
      ),
      _ConteoCardData(situacion: _situacionTurnado, icon: Icons.send_outlined),
      _ConteoCardData(
        situacion: _situacionResuelto,
        icon: Icons.check_circle_outline,
      ),
      _ConteoCardData(
        situacion: _situacionFaltaCompletar,
        icon: Icons.assignment_late_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 4 : 2,
            mainAxisExtent: 112,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final card = cards[index];
            final color = _situacionColor(card.situacion);
            return _ConteoCard(
              label: _situacionLabel(card.situacion),
              count: _conteo(card.situacion),
              icon: card.icon,
              color: color,
              selected: _situacion == card.situacion,
              onTap: () => _setSituacion(card.situacion),
            );
          },
        );
      },
    );
  }

  Widget _buildListado() {
    final hechos = _hechosFiltrados;
    final response = _response;

    if (_loading && response == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && response == null) {
      return _ErrorState(message: _error!, onRetry: () => _fetchSeguimiento());
    }

    if (hechos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 42),
        child: Center(child: Text('No hay hechos con los filtros actuales.')),
      );
    }

    return Column(
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        for (final hecho in hechos)
          _SeguimientoHechoCard(
            id: _hechoId(hecho),
            fechaHora: _fechaHora(hecho),
            unidad: _unidadLabel(hecho),
            delegacion: _delegacionLabel(hecho),
            ubicacion: _ubicacion(hecho),
            situacionLabel: _situacionLabel(_text(hecho['situacion'])),
            situacionColor: _situacionColor(_text(hecho['situacion'])),
            creator: _creatorLabel(hecho),
            fotoUrl: _fotoPrincipal(hecho),
            incomplete:
                _asBool(hecho['mostrar_captura']) &&
                _text(hecho['estado_captura']) == 'INCOMPLETO',
            faltantes: HechoCaptureStatus.detallesFaltantes(hecho),
            downloading:
                _hechoId(hecho) != null &&
                _descargando.contains(_hechoId(hecho)),
            sending:
                _hechoId(hecho) != null &&
                _enviandoWhatsapp.contains(_hechoId(hecho)),
            deleting:
                _hechoId(hecho) != null &&
                _eliminando.contains(_hechoId(hecho)),
            canEdit: _asBool(hecho['puede_editar']),
            canDelete: _asBool(hecho['puede_eliminar']),
            onShow: () => _abrirShow(hecho),
            onEdit: _asBool(hecho['puede_editar'])
                ? () => _abrirEdit(hecho)
                : null,
            onDownload: _hechoId(hecho) == null
                ? null
                : () => _descargarReporte(_hechoId(hecho)!),
            onWhatsapp: _hechoId(hecho) == null
                ? null
                : () => _compartirWhatsapp(_hechoId(hecho)!),
            onDelete:
                _asBool(hecho['puede_eliminar']) && _hechoId(hecho) != null
                ? () => _eliminarHecho(_hechoId(hecho)!)
                : null,
          ),
        _buildPagination(),
      ],
    );
  }

  Widget _buildPagination() {
    final meta = _response?.meta;
    if (meta == null) return const SizedBox.shrink();

    final canPrev = meta.currentPage > 1;
    final canNext = meta.currentPage < meta.lastPage;

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 18),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Página anterior',
            onPressed: canPrev
                ? () {
                    setState(() => _page = meta.currentPage - 1);
                    _fetchSeguimiento();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              'Página ${meta.currentPage} de ${meta.lastPage} · ${meta.total} hechos',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Página siguiente',
            onPressed: canNext
                ? () {
                    setState(() => _page = meta.currentPage + 1);
                    _fetchSeguimiento();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = _response?.meta;
    final filteredCount = _hechosFiltrados.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Seguimiento de hechos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : () => _fetchSeguimiento(),
            icon: const Icon(Icons.refresh),
          ),
          const AccountMenuAction(),
        ],
      ),
      drawer: AppDrawer(trackingOn: _trackingOn),
      endDrawer: AppAccountDrawer(onLogout: _logout),
      body: RefreshIndicator(
        onRefresh: () => _fetchSeguimiento(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildFiltros(),
            const SizedBox(height: 12),
            _buildConteos(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_situacionLabel(_situacion)} · ${_periodoLabel(_periodo)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (meta != null)
                  Text(
                    '$filteredCount/${meta.total}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _buildListado(),
          ],
        ),
      ),
    );
  }
}

class _ConteoCardData {
  final String situacion;
  final IconData icon;

  const _ConteoCardData({required this.situacion, required this.icon});
}

class _ConteoCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ConteoCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : const Color(0xFFE5E7EB),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.radio_button_checked, color: color, size: 18),
                ],
              ),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeguimientoHechoCard extends StatelessWidget {
  final int? id;
  final String fechaHora;
  final String unidad;
  final String delegacion;
  final String ubicacion;
  final String situacionLabel;
  final Color situacionColor;
  final String creator;
  final String fotoUrl;
  final bool incomplete;
  final List<String> faltantes;
  final bool downloading;
  final bool sending;
  final bool deleting;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onShow;
  final VoidCallback? onEdit;
  final VoidCallback? onDownload;
  final VoidCallback? onWhatsapp;
  final VoidCallback? onDelete;

  const _SeguimientoHechoCard({
    required this.id,
    required this.fechaHora,
    required this.unidad,
    required this.delegacion,
    required this.ubicacion,
    required this.situacionLabel,
    required this.situacionColor,
    required this.creator,
    required this.fotoUrl,
    required this.incomplete,
    required this.faltantes,
    required this.downloading,
    required this.sending,
    required this.deleting,
    required this.canEdit,
    required this.canDelete,
    required this.onShow,
    required this.onEdit,
    required this.onDownload,
    required this.onWhatsapp,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = incomplete
        ? const Color(0xFFDC2626)
        : const Color(0xFFE5E7EB);
    final bg = incomplete ? const Color(0xFFFFF1F2) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: incomplete ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onShow,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(url: fotoUrl, incomplete: incomplete),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Pill(
                          label: id == null ? 'Sin ID' : '#$id',
                          color: const Color(0xFF111827),
                        ),
                        _Pill(label: situacionLabel, color: situacionColor),
                        if (incomplete)
                          const _Pill(
                            label: 'CAPTURA INCOMPLETA',
                            color: Color(0xFFDC2626),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fechaHora,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unidad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (delegacion.trim().isNotEmpty)
                      Text(
                        delegacion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      ubicacion,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Creado por: $creator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (incomplete) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            (faltantes.isEmpty
                                    ? const [
                                        'Falta completar la captura esperada',
                                      ]
                                    : faltantes)
                                .map(
                                  (item) => _Pill(
                                    label: item,
                                    color: const Color(0xFFDC2626),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Ver',
                          onPressed: onShow,
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          tooltip: 'Descargar informe',
                          onPressed: downloading ? null : onDownload,
                          icon: downloading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          tooltip: 'WhatsApp',
                          onPressed: sending ? null : onWhatsapp,
                          icon: sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.chat_bubble_outline),
                        ),
                        if (canEdit) ...[
                          const SizedBox(width: 4),
                          IconButton.filledTonal(
                            tooltip: 'Editar',
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                        if (canDelete) ...[
                          const SizedBox(width: 4),
                          IconButton.filledTonal(
                            tooltip: 'Eliminar',
                            onPressed: deleting ? null : onDelete,
                            style: IconButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                            ),
                            icon: deleting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String url;
  final bool incomplete;

  const _Thumb({required this.url, required this.incomplete});

  @override
  Widget build(BuildContext context) {
    final accent = incomplete
        ? const Color(0xFFDC2626)
        : const Color(0xFF2563EB);
    return Container(
      width: 74,
      height: 74,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: .20)),
      ),
      child: url.trim().isEmpty
          ? Icon(Icons.car_crash_outlined, color: accent, size: 30)
          : SafeNetworkImage(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.image_not_supported_outlined, color: accent),
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
