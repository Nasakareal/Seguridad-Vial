import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/routes.dart';
import '../../models/delegacion_actividad_fisica.dart';
import '../../services/auth_service.dart';
import '../../services/delegaciones_actividades_fisicas_service.dart';
import '../../services/estadisticas_actividades_service.dart';
import '../../services/photo_picker_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/photo_viewer.dart';
import '../../widgets/safe_network_image.dart';

class DelegacionesActividadesFisicasScreen extends StatefulWidget {
  const DelegacionesActividadesFisicasScreen({super.key});

  @override
  State<DelegacionesActividadesFisicasScreen> createState() =>
      _DelegacionesActividadesFisicasScreenState();
}

class _DelegacionesActividadesFisicasScreenState
    extends State<DelegacionesActividadesFisicasScreen> {
  final _buscarCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<DelegacionActividadFisica> _items = [];

  List<String> _tipos = const <String>[];
  List<DelegacionActividadFisicaDelegacion> _delegaciones =
      const <DelegacionActividadFisicaDelegacion>[];

  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  int? _delegacionFiltroId;
  String? _tipoFiltro;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  bool _checkingAccess = true;
  bool _allowed = false;
  bool _canManage = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loggingOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_maybeLoadMore);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final allowed = await DelegacionesActividadesFisicasService.canUse(
        refresh: true,
      );
      final canManage = allowed
          ? await AuthService.canManageDelegacionesActividadesFisicas()
          : false;
      if (!mounted) return;
      setState(() {
        _allowed = allowed;
        _canManage = canManage;
        _checkingAccess = false;
      });

      if (!allowed) return;
      await _loadCatalogs();
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingAccess = false;
        _allowed = false;
        _error = DelegacionesActividadesFisicasService.cleanExceptionMessage(e);
      });
    }
  }

  Future<void> _loadCatalogs() async {
    final tiposFuture = DelegacionesActividadesFisicasService.tipos();
    final delegacionesFuture = EstadisticasActividadesService()
        .catalogoDelegaciones();

    List<String> tipos = const <String>[];
    List<DelegacionActividadFisicaDelegacion> delegaciones =
        const <DelegacionActividadFisicaDelegacion>[];

    try {
      tipos = await tiposFuture;
    } catch (_) {}

    try {
      final rawDelegaciones = await delegacionesFuture;
      delegaciones =
          rawDelegaciones
              .map(_delegacionFromCatalog)
              .where((item) => item.id > 0)
              .toList()
            ..sort((a, b) => a.displayName.compareTo(b.displayName));
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _tipos = tipos;
      _delegaciones = delegaciones;
    });
  }

  DelegacionActividadFisicaDelegacion _delegacionFromCatalog(
    Map<String, dynamic> raw,
  ) {
    final nombreCompuesto =
        raw['nombre_con_clave'] ??
        raw['nombreConClave'] ??
        raw['label'] ??
        raw['text'];

    return DelegacionActividadFisicaDelegacion.fromJson(<String, dynamic>{
      'id': raw['id'] ?? raw['value'],
      'clave': raw['clave'] ?? raw['codigo'],
      'nombre': raw['nombre'] ?? raw['name'] ?? nombreCompuesto,
      'municipio': raw['municipio'],
    });
  }

  Future<void> _load({required bool reset}) async {
    if (!_allowed) return;

    if (reset) {
      setState(() {
        _loading = true;
        _page = 1;
        _lastPage = 1;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final page = await DelegacionesActividadesFisicasService.index(
        page: reset ? 1 : _page + 1,
        buscar: _buscarCtrl.text,
        fechaInicio: _fechaInicio == null ? null : _formatDate(_fechaInicio!),
        fechaFin: _fechaFin == null ? null : _formatDate(_fechaFin!),
        tipoEjercicio: _tipoFiltro,
        delegacionId: _delegacionFiltroId,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
        _page = page.currentPage;
        _lastPage = page.lastPage;
        _total = page.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = DelegacionesActividadesFisicasService.cleanExceptionMessage(e);
      });
    }
  }

  void _maybeLoadMore() {
    if (_loading || _loadingMore || _page >= _lastPage) return;
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 320) {
      unawaited(_load(reset: false));
    }
  }

  Future<void> _pickFilterDate({required bool start}) async {
    final current = start ? _fechaInicio : _fechaFin;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked == null) return;

    setState(() {
      if (start) {
        _fechaInicio = DateTime(picked.year, picked.month, picked.day);
        if (_fechaFin != null && _fechaFin!.isBefore(_fechaInicio!)) {
          _fechaFin = _fechaInicio;
        }
      } else {
        _fechaFin = DateTime(picked.year, picked.month, picked.day);
        if (_fechaInicio != null && _fechaInicio!.isAfter(_fechaFin!)) {
          _fechaInicio = _fechaFin;
        }
      }
    });
    await _load(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _buscarCtrl.clear();
      _delegacionFiltroId = null;
      _tipoFiltro = null;
      _fechaInicio = null;
      _fechaFin = null;
    });
    unawaited(_load(reset: true));
  }

  Future<void> _openCreateSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActividadFisicaCreateSheet(
        tipos: _tipos,
        delegaciones: _delegaciones,
        canManage: _canManage,
      ),
    );

    if (saved != true) return;
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ejercicio registrado.')));
    await _loadCatalogs();
    await _load(reset: true);
  }

  Future<void> _logout(BuildContext context) async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    try {
      try {
        await TrackingService.stop();
      } catch (_) {}
      await AuthService.logout();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final body = _checkingAccess
        ? const Center(child: CircularProgressIndicator())
        : !_allowed
        ? _AccessDenied(message: _error)
        : _buildContent();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Ejercicios Delegaciones'),
        actions: [
          if (_allowed)
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _loading ? null : () => unawaited(_load(reset: true)),
              icon: const Icon(Icons.refresh),
            ),
          const AccountMenuAction(),
        ],
      ),
      drawer: const AppDrawer(trackingOn: false),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      floatingActionButton: _allowed
          ? FloatingActionButton.extended(
              onPressed: _openCreateSheet,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Nuevo'),
            )
          : null,
      body: SafeArea(child: body),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _FiltersPanel(
          buscarCtrl: _buscarCtrl,
          tipos: _tipos,
          delegaciones: _delegaciones,
          total: _total,
          tipoFiltro: _tipoFiltro,
          delegacionFiltroId: _delegacionFiltroId,
          fechaInicio: _fechaInicio,
          fechaFin: _fechaFin,
          loading: _loading,
          onSearch: () => _load(reset: true),
          onClear: _clearFilters,
          onPickStart: () => _pickFilterDate(start: true),
          onPickEnd: () => _pickFilterDate(start: false),
          onTipoChanged: (value) {
            setState(() => _tipoFiltro = value);
            unawaited(_load(reset: true));
          },
          onDelegacionChanged: (value) {
            setState(() => _delegacionFiltroId = value);
            unawaited(_load(reset: true));
          },
          canFilterDelegacion: _canManage,
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 110, 24, 120),
                          children: const [
                            _EmptyState(
                              icon: Icons.fitness_center_outlined,
                              title: 'Sin ejercicios registrados',
                              subtitle:
                                  'Captura una actividad fisica con foto para iniciar el registro.',
                            ),
                          ],
                        )
                      : ListView.separated(
                          controller: _scrollCtrl,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
                          itemCount: _items.length + (_loadingMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(18),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _ActividadFisicaCard(item: _items[index]);
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

class _FiltersPanel extends StatelessWidget {
  final TextEditingController buscarCtrl;
  final List<String> tipos;
  final List<DelegacionActividadFisicaDelegacion> delegaciones;
  final int total;
  final String? tipoFiltro;
  final int? delegacionFiltroId;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final bool loading;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<String?> onTipoChanged;
  final ValueChanged<int?> onDelegacionChanged;
  final bool canFilterDelegacion;

  const _FiltersPanel({
    required this.buscarCtrl,
    required this.tipos,
    required this.delegaciones,
    required this.total,
    required this.tipoFiltro,
    required this.delegacionFiltroId,
    required this.fechaInicio,
    required this.fechaFin,
    required this.loading,
    required this.onSearch,
    required this.onClear,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onTipoChanged,
    required this.onDelegacionChanged,
    required this.canFilterDelegacion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: buscarCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Buscar tipo o delegacion',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Buscar',
                onPressed: loading ? null : onSearch,
                icon: const Icon(Icons.search),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                tooltip: 'Limpiar filtros',
                onPressed: loading ? null : onClear,
                icon: const Icon(Icons.filter_alt_off_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FilterChipButton(
                icon: Icons.event_outlined,
                label: fechaInicio == null
                    ? 'Desde'
                    : 'Desde ${_formatDisplayDate(fechaInicio!)}',
                onPressed: loading ? null : onPickStart,
              ),
              _FilterChipButton(
                icon: Icons.event_available_outlined,
                label: fechaFin == null
                    ? 'Hasta'
                    : 'Hasta ${_formatDisplayDate(fechaFin!)}',
                onPressed: loading ? null : onPickEnd,
              ),
              if (tipos.isNotEmpty)
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: tipoFiltro,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      for (final tipo in tipos)
                        DropdownMenuItem<String>(
                          value: tipo,
                          child: Text(tipo, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: loading ? null : onTipoChanged,
                  ),
                ),
              if (canFilterDelegacion && delegaciones.isNotEmpty)
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int>(
                    value: delegacionFiltroId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Delegacion',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Todas'),
                      ),
                      for (final delegacion in delegaciones)
                        DropdownMenuItem<int>(
                          value: delegacion.id,
                          child: Text(
                            delegacion.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: loading ? null : onDelegacionChanged,
                  ),
                ),
              Chip(
                avatar: const Icon(Icons.list_alt, size: 18),
                label: Text('$total registros'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _ActividadFisicaCard extends StatelessWidget {
  final DelegacionActividadFisica item;

  const _ActividadFisicaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final fotoUrl = item.fotoUrl?.trim() ?? '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: fotoUrl.isEmpty
                      ? null
                      : () => showPhotoViewer(
                          context: context,
                          title: item.tipoEjercicio,
                          photoUrl: fotoUrl,
                        ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 112,
                      height: 84,
                      color: const Color(0xFFE2E8F0),
                      child: fotoUrl.isEmpty
                          ? const Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFF64748B),
                            )
                          : SafeNetworkImage(
                              fotoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                color: Color(0xFF64748B),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.tipoEjercicio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.delegacionLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoPill(
                            icon: Icons.groups_2_outlined,
                            label: '${item.elementosParticipantes}',
                          ),
                          _InfoPill(
                            icon: Icons.event_outlined,
                            label: item.fechaCorta,
                          ),
                          _InfoPill(
                            icon: Icons.schedule,
                            label: item.horaCorta,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Capturo: ${item.capturoLabel}',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF1D4ED8)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1D4ED8),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActividadFisicaCreateSheet extends StatefulWidget {
  final List<String> tipos;
  final List<DelegacionActividadFisicaDelegacion> delegaciones;
  final bool canManage;

  const _ActividadFisicaCreateSheet({
    required this.tipos,
    required this.delegaciones,
    required this.canManage,
  });

  @override
  State<_ActividadFisicaCreateSheet> createState() =>
      _ActividadFisicaCreateSheetState();
}

class _ActividadFisicaCreateSheetState
    extends State<_ActividadFisicaCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _fechaCtrl = TextEditingController();
  final _horaCtrl = TextEditingController();
  final _elementosCtrl = TextEditingController(text: '0');

  int? _delegacionId;
  String? _tipoEjercicio;
  File? _foto;
  bool _saving = false;
  String? _error;

  List<String> get _tipoOptions => widget.tipos.isEmpty
      ? DelegacionesActividadesFisicasService.defaultTiposEjercicio
      : widget.tipos;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fechaCtrl.text = _formatDate(now);
    _horaCtrl.text = _formatTime(now);
    if (widget.canManage && widget.delegaciones.length == 1) {
      _delegacionId = widget.delegaciones.single.id;
    }
    if (_tipoOptions.length == 1) {
      _tipoEjercicio = _tipoOptions.single;
    }
  }

  @override
  void dispose() {
    _fechaCtrl.dispose();
    _horaCtrl.dispose();
    _elementosCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_fechaCtrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() => _fechaCtrl.text = _formatDate(picked));
  }

  Future<void> _pickTime() async {
    final currentParts = _horaCtrl.text.split(':');
    final initial = currentParts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(currentParts[0]) ?? TimeOfDay.now().hour,
            minute: int.tryParse(currentParts[1]) ?? TimeOfDay.now().minute,
          )
        : TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() => _horaCtrl.text = _formatTimeOfDay(picked));
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await PhotoPickerService.pickAndCropImage(
      context,
      _picker,
      source: source,
      cropLandscape: false,
    );
    if (file == null || !mounted) return;
    setState(() {
      _foto = file;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (widget.canManage &&
        (_fechaCtrl.text.trim().isEmpty || _horaCtrl.text.trim().isEmpty)) {
      setState(() => _error = 'Captura fecha y hora.');
      return;
    }
    if (_foto == null) {
      setState(() => _error = 'Selecciona una foto del ejercicio.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await DelegacionesActividadesFisicasService.store(
        delegacionId: widget.canManage ? _delegacionId : null,
        fecha: widget.canManage ? _fechaCtrl.text : '',
        hora: widget.canManage ? _horaCtrl.text : '',
        tipoEjercicio: _tipoEjercicio ?? '',
        elementosParticipantes: int.tryParse(_elementosCtrl.text.trim()) ?? 0,
        foto: _foto!,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = DelegacionesActividadesFisicasService.cleanExceptionMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF6F7FB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .92,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nuevo ejercicio',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    shrinkWrap: true,
                    children: [
                      if (!widget.canManage) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.business_outlined,
                                color: Color(0xFF1D4ED8),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Se registrara con la delegacion asignada a tu usuario.',
                                  style: TextStyle(
                                    color: Color(0xFF1E40AF),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (widget.canManage && widget.delegaciones.isNotEmpty)
                        DropdownButtonFormField<int>(
                          value: _delegacionId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Delegacion',
                            prefixIcon: Icon(Icons.business_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final delegacion in widget.delegaciones)
                              DropdownMenuItem<int>(
                                value: delegacion.id,
                                child: Text(
                                  delegacion.displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) =>
                                    setState(() => _delegacionId = value),
                          validator: (value) =>
                              value == null ? 'Selecciona delegacion.' : null,
                        ),
                      if (widget.canManage && widget.delegaciones.isNotEmpty)
                        const SizedBox(height: 12),
                      if (widget.canManage) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _fechaCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Fecha',
                                  prefixIcon: Icon(Icons.event_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                onTap: _saving ? null : _pickDate,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _horaCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Hora',
                                  prefixIcon: Icon(Icons.schedule),
                                  border: OutlineInputBorder(),
                                ),
                                onTap: _saving ? null : _pickTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      DropdownButtonFormField<String>(
                        value: _tipoEjercicio,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de ejercicio',
                          prefixIcon: Icon(Icons.fitness_center_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final tipo in _tipoOptions)
                            DropdownMenuItem<String>(
                              value: tipo,
                              child: Text(
                                tipo,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() {
                                _tipoEjercicio = value;
                              }),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Selecciona tipo.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _elementosCtrl,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Elementos participantes',
                          prefixIcon: Icon(Icons.groups_2_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final parsed = int.tryParse(value?.trim() ?? '');
                          if (parsed == null) return 'Captura un numero.';
                          if (parsed < 0 || parsed > 5000) {
                            return 'Usa un valor entre 0 y 5000.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _PhotoPickerPanel(
                        foto: _foto,
                        saving: _saving,
                        onCamera: () => _pickPhoto(ImageSource.camera),
                        onGallery: () => _pickPhoto(ImageSource.gallery),
                        onRemove: () => setState(() => _foto = null),
                      ),
                      if ((_error ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Guardando...' : 'Guardar'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPickerPanel extends StatelessWidget {
  final File? foto;
  final bool saving;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  const _PhotoPickerPanel({
    required this.foto,
    required this.saving,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Foto',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: const Color(0xFFE2E8F0),
                child: foto == null
                    ? const Center(
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 42,
                          color: Color(0xFF64748B),
                        ),
                      )
                    : Image.file(foto!, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : onCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camara'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : onGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeria'),
                ),
              ),
              if (foto != null) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Quitar foto',
                  onPressed: saving ? null : onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  final String? message;

  const _AccessDenied({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _EmptyState(
          icon: Icons.lock_outline,
          title: 'Modulo no disponible',
          subtitle: (message ?? '').trim().isEmpty
              ? 'Este modulo solo esta disponible para unidad Delegaciones y superadmin.'
              : message!,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function({required bool reset}) onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        _EmptyState(
          icon: Icons.warning_amber_rounded,
          title: 'No se pudieron cargar los registros',
          subtitle: message,
        ),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.icon(
            onPressed: () => onRetry(reset: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF64748B)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  String two(int x) => x.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

String _formatDisplayDate(DateTime date) {
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

String _formatTime(DateTime date) {
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(date.hour)}:${two(date.minute)}';
}

String _formatTimeOfDay(TimeOfDay time) {
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}';
}
