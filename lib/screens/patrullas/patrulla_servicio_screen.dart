import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/patrulla_servicio_service.dart';
import 'ayuda/patrulla_servicio_help_sheet.dart';

class PatrullaServicioScreen extends StatefulWidget {
  final String initialSection;

  const PatrullaServicioScreen({super.key, this.initialSection = 'servicio'});

  @override
  State<PatrullaServicioScreen> createState() => _PatrullaServicioScreenState();
}

class _PatrullaServicioScreenState extends State<PatrullaServicioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _service = const <String, dynamic>{};
  Map<String, dynamic>? _log;
  List<Map<String, dynamic>> _available = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _history = const <Map<String, dynamic>>[];

  bool get _hasService => _service['tiene_servicio'] == true;

  @override
  void initState() {
    super.initState();
    final initialIndex = switch (widget.initialSection) {
      'recibir' => 0,
      'historial' => 2,
      _ => 1,
    };
    _tabs = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>([
        PatrullaServicioService.miServicio(),
        PatrullaServicioService.disponibles(),
        PatrullaServicioService.miHistorial(),
        PatrullaServicioService.miBitacora(),
      ]);
      if (!mounted) return;
      setState(() {
        _service = Map<String, dynamic>.from(results[0] as Map);
        _available = List<Map<String, dynamic>>.from(results[1] as List);
        _history = List<Map<String, dynamic>>.from(results[2] as List);
        _log = results[3] is Map
            ? Map<String, dynamic>.from(results[3] as Map)
            : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  void _notify(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
        ),
      );
  }

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.help_outline, color: Colors.blue, size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¿En qué necesitas ayuda?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Consulta el proceso correcto para recibir, utilizar y entregar una patrulla.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.local_police_outlined),
              ),
              title: const Text('Cómo usar el control de patrullas'),
              subtitle: const Text(
                'Guía paso a paso de recepción, inspección, servicio y entrega.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Future<void>.delayed(const Duration(milliseconds: 180), () {
                  if (!mounted) return;
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) =>
                        PatrullaServicioHelpSheet(initialPage: _tabs.index),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: const Text('Control de patrulla'),
        actions: [
          IconButton(
            tooltip: 'Ayuda',
            onPressed: _showHelp,
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.login_rounded), text: 'Recibir'),
            Tab(icon: Icon(Icons.local_police_outlined), text: 'Mi servicio'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Historial'),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _ReceiveTab(
                    available: _available,
                    hasService: _hasService,
                    onCompleted: () async {
                      _notify('Patrulla recibida. Servicio iniciado.');
                      await _load();
                      if (mounted) _tabs.animateTo(1);
                    },
                    onError: (value) => _notify(value, error: true),
                  ),
                  _ServiceTab(
                    service: _service,
                    log: _log,
                    onCompleted: () async {
                      _notify('Patrulla entregada correctamente.');
                      await _load();
                    },
                    onUpdated: () async {
                      _notify('Servicio actualizado.');
                      await _load();
                    },
                    onError: (value) => _notify(value, error: true),
                  ),
                  _HistoryTab(history: _history),
                ],
              ),
            ),
    );
  }
}

class _ReceiveTab extends StatefulWidget {
  final List<Map<String, dynamic>> available;
  final bool hasService;
  final Future<void> Function() onCompleted;
  final ValueChanged<String> onError;

  const _ReceiveTab({
    required this.available,
    required this.hasService,
    required this.onCompleted,
    required this.onError,
  });

  @override
  State<_ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<_ReceiveTab> {
  final _formKey = GlobalKey<FormState>();
  final _km = TextEditingController();
  final _equipment = TextEditingController();
  final _damage = TextEditingController();
  final _news = TextEditingController();
  final _notes = TextEditingController();
  final _picker = ImagePicker();
  final Map<String, String> _photos = <String, String>{};
  final Map<String, String> _status = <String, String>{
    'estado_carroceria': 'bueno',
    'estado_interiores': 'bueno',
    'estado_llantas': 'bueno',
    'estado_luces': 'bueno',
    'estado_torreta': 'bueno',
    'estado_sirena': 'bueno',
    'estado_radio': 'bueno',
    'estado_mecanico': 'bueno',
  };
  final Map<String, bool> _inventory = <String, bool>{
    'trae_refaccion': true,
    'trae_gato': true,
    'trae_llave_cruz': true,
    'trae_extintor': true,
    'trae_botiquin': true,
  };
  int? _patrolId;
  double _fuel = 100;
  bool _saving = false;

  @override
  void dispose() {
    _km.dispose();
    _equipment.dispose();
    _damage.dispose();
    _news.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(String field) async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 78,
      maxWidth: 1800,
    );
    if (file != null && mounted) setState(() => _photos[field] = file.path);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _patrolId == null) return;
    setState(() => _saving = true);
    try {
      final fields = <String, String>{
        'kilometraje': _km.text.trim(),
        'nivel_combustible': _fuel.round().toString(),
        ..._status,
        for (final entry in _inventory.entries)
          entry.key: entry.value ? '1' : '0',
        if (_equipment.text.trim().isNotEmpty)
          'equipo_adicional': _equipment.text.trim(),
        if (_damage.text.trim().isNotEmpty)
          'danos_existentes': _damage.text.trim(),
        if (_news.text.trim().isNotEmpty) 'novedades': _news.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'observaciones': _notes.text.trim(),
      };
      await PatrullaServicioService.recibir(
        patrullaId: _patrolId!,
        fields: fields,
        photos: _photos,
      );
      await widget.onCompleted();
    } catch (error) {
      widget.onError(_message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hasService) {
      return const _MessageState(
        icon: Icons.directions_car_filled_rounded,
        title: 'Ya tienes una patrulla en servicio',
        message: 'Primero debes entregarla desde la pestaña “Mi servicio”.',
      );
    }
    if (widget.available.isEmpty) {
      return const _MessageState(
        icon: Icons.car_crash_outlined,
        title: 'No hay patrullas disponibles',
        message: 'Todas las unidades de tu área están ocupadas o inactivas.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroCard(
          icon: Icons.assignment_turned_in_outlined,
          title: 'Recepción de unidad',
          subtitle: 'Realiza la inspección antes de iniciar el servicio.',
          color: const Color(0xFF0E7490),
        ),
        const SizedBox(height: 14),
        Form(
          key: _formKey,
          child: Column(
            children: [
              _SectionCard(
                title: 'Unidad y lecturas',
                icon: Icons.local_police_outlined,
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      value: _patrolId,
                      decoration: const InputDecoration(
                        labelText: 'Patrulla disponible',
                        prefixIcon: Icon(Icons.directions_car_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: widget.available.map((patrol) {
                        final id = _int(patrol['id'])!;
                        final number = _text(patrol['numero_economico'], 'S/N');
                        final description = _text(
                          patrol['descripcion_vehiculo'],
                          'Unidad operativa',
                        );
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(
                            '$number · $description',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _patrolId = value),
                      validator: (value) =>
                          value == null ? 'Selecciona una patrulla.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _km,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kilometraje actual',
                        suffixText: 'km',
                        prefixIcon: Icon(Icons.speed_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        return parsed == null || parsed < 0
                            ? 'Captura un kilometraje válido.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _FuelSelector(
                      value: _fuel,
                      onChanged: (value) => setState(() => _fuel = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Inspección física',
                icon: Icons.fact_check_outlined,
                child: Column(
                  children: [
                    _StatusField(
                      label: 'Carrocería',
                      field: 'estado_carroceria',
                      values: const ['bueno', 'regular', 'malo'],
                      status: _status,
                      onChanged: _setStatus,
                    ),
                    _StatusField(
                      label: 'Interiores',
                      field: 'estado_interiores',
                      values: const ['bueno', 'regular', 'malo'],
                      status: _status,
                      onChanged: _setStatus,
                    ),
                    _StatusField(
                      label: 'Llantas',
                      field: 'estado_llantas',
                      values: const ['bueno', 'regular', 'malo'],
                      status: _status,
                      onChanged: _setStatus,
                    ),
                    _StatusField(
                      label: 'Luces',
                      field: 'estado_luces',
                      values: const ['bueno', 'regular', 'malo'],
                      status: _status,
                      onChanged: _setStatus,
                    ),
                    _StatusField(
                      label: 'Torreta',
                      field: 'estado_torreta',
                      values: const ['bueno', 'regular', 'malo', 'no_aplica'],
                      status: _status,
                      onChanged: _setStatus,
                    ),
                    _StatusField(
                      label: 'Sirena',
                      field: 'estado_sirena',
                      values: const ['bueno', 'regular', 'malo', 'no_aplica'],
                      status: _status,
                      onChanged: _setStatus,
                    ),
                    _StatusField(
                      label: 'Radio',
                      field: 'estado_radio',
                      values: const ['bueno', 'regular', 'malo', 'no_aplica'],
                      status: _status,
                      onChanged: _setStatus,
                    ),
                    _StatusField(
                      label: 'Estado mecánico',
                      field: 'estado_mecanico',
                      values: const ['bueno', 'regular', 'malo'],
                      status: _status,
                      onChanged: _setStatus,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Inventario',
                icon: Icons.inventory_2_outlined,
                child: Column(
                  children: _inventory.entries
                      .map(
                        (entry) => SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_inventoryLabel(entry.key)),
                          value: entry.value,
                          onChanged: (value) =>
                              setState(() => _inventory[entry.key] = value),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Evidencia fotográfica',
                icon: Icons.add_a_photo_outlined,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      const {
                            'foto_frontal': 'Frontal',
                            'foto_trasera': 'Trasera',
                            'foto_lateral_izquierdo': 'Lateral izq.',
                            'foto_lateral_derecho': 'Lateral der.',
                            'foto_tablero': 'Tablero',
                          }.entries
                          .map(
                            (entry) => ActionChip(
                              avatar: Icon(
                                _photos.containsKey(entry.key)
                                    ? Icons.check_circle
                                    : Icons.camera_alt_outlined,
                                size: 18,
                              ),
                              label: Text(entry.value),
                              onPressed: () => _takePhoto(entry.key),
                            ),
                          )
                          .toList(),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Novedades',
                icon: Icons.notes_rounded,
                child: Column(
                  children: [
                    _TextArea(
                      controller: _equipment,
                      label: 'Equipo adicional',
                    ),
                    _TextArea(controller: _damage, label: 'Daños existentes'),
                    _TextArea(controller: _news, label: 'Novedades'),
                    _TextArea(controller: _notes, label: 'Observaciones'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.key_rounded),
                  label: Text(
                    _saving
                        ? 'Registrando recepción...'
                        : 'Confirmar recepción e iniciar servicio',
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  void _setStatus(String field, String value) =>
      setState(() => _status[field] = value);
}

class _ServiceTab extends StatefulWidget {
  final Map<String, dynamic> service;
  final Map<String, dynamic>? log;
  final Future<void> Function() onCompleted;
  final Future<void> Function() onUpdated;
  final ValueChanged<String> onError;

  const _ServiceTab({
    required this.service,
    required this.log,
    required this.onCompleted,
    required this.onUpdated,
    required this.onError,
  });

  @override
  State<_ServiceTab> createState() => _ServiceTabState();
}

class _ServiceTabState extends State<_ServiceTab> {
  final _km = TextEditingController();
  final _news = TextEditingController();
  final _notes = TextEditingController();
  double _fuel = 100;
  bool _saving = false;

  @override
  void dispose() {
    _km.dispose();
    _news.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _deliver(int patrolId, int initialKm) async {
    final km = int.tryParse(_km.text.trim());
    if (km == null || km < initialKm) {
      widget.onError(
        'El kilometraje final debe ser igual o mayor a $initialKm km.',
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar entrega'),
        content: const Text(
          'Se cerrará tu bitácora y la patrulla quedará disponible para el siguiente elemento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entregar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _saving = true);
    try {
      await PatrullaServicioService.entregar(
        patrullaId: patrolId,
        kilometraje: km,
        nivelCombustible: _fuel,
        novedades: _news.text,
        observaciones: _notes.text,
      );
      await widget.onCompleted();
    } catch (error) {
      widget.onError(_message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.service['tiene_servicio'] != true ||
        widget.service['data'] is! Map) {
      return const _MessageState(
        icon: Icons.key_off_outlined,
        title: 'Sin servicio activo',
        message: 'Recibe una patrulla para abrir tu bitácora de turno.',
      );
    }
    final data = Map<String, dynamic>.from(widget.service['data'] as Map);
    final patrol = _map(data['patrulla']);
    final log = _map(data['bitacora']);
    final initialKm = _int(log['kilometraje_inicio']) ?? 0;
    final patrolId = _int(patrol['id'])!;
    final logData = _map(widget.log?['data']);
    final totals = _map(logData['totales']);
    if (_km.text.isEmpty) {
      _km.text = (_int(log['kilometraje_fin']) ?? initialKm).toString();
    }
    final startFuel =
        double.tryParse('${log['combustible_inicio'] ?? 100}') ?? 100;
    if (_fuel == 100 && startFuel != 100) _fuel = startFuel;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroCard(
          icon: Icons.local_police_rounded,
          title: 'Unidad ${_text(patrol['numero_economico'], 'S/N')}',
          subtitle:
              '${_text(_map(patrol['unidad'])['nombre'], 'Sin unidad')} · Desde ${_shortTime(log['hora_inicio'])}',
          color: const Color(0xFF1D4ED8),
          trailing: const Chip(label: Text('EN SERVICIO')),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Inicio',
                value: '$initialKm km',
                icon: Icons.speed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: 'Servicios',
                value: '${totals['servicios'] ?? 0}',
                icon: Icons.assignment_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                label: 'Combustible',
                value: '${startFuel.round()}%',
                icon: Icons.local_gas_station_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ServiceRecordsCard(logData: logData),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Cierre de turno',
          icon: Icons.logout_rounded,
          child: Column(
            children: [
              TextField(
                controller: _km,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kilometraje final',
                  suffixText: 'km',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _FuelSelector(
                value: _fuel,
                onChanged: (value) => setState(() => _fuel = value),
              ),
              const SizedBox(height: 8),
              _TextArea(controller: _news, label: 'Novedades de la entrega'),
              _TextArea(controller: _notes, label: 'Observaciones finales'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB42318),
                  ),
                  onPressed: _saving
                      ? null
                      : () => _deliver(patrolId, initialKm),
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(
                    _saving
                        ? 'Entregando...'
                        : 'Entregar patrulla y cerrar servicio',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ServiceRecordsCard extends StatelessWidget {
  final Map<String, dynamic> logData;

  const _ServiceRecordsCard({required this.logData});

  @override
  Widget build(BuildContext context) {
    final activities = _mapList(logData['actividades']);
    final events = _mapList(logData['hechos']);
    final records =
        <({String type, Map<String, dynamic> data})>[
          ...activities.map((data) => (type: 'actividad', data: data)),
          ...events.map((data) => (type: 'hecho', data: data)),
        ]..sort((a, b) {
          final aKey = '${a.data['fecha'] ?? ''} ${a.data['hora'] ?? ''}';
          final bKey = '${b.data['fecha'] ?? ''} ${b.data['hora'] ?? ''}';
          return bKey.compareTo(aKey);
        });

    return _SectionCard(
      title: 'Servicios vinculados al turno',
      icon: Icons.assignment_turned_in_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CountChip(
                icon: Icons.task_alt_rounded,
                label: '${activities.length} actividades',
                color: const Color(0xFF15803D),
              ),
              _CountChip(
                icon: Icons.car_crash_outlined,
                label: '${events.length} hechos',
                color: const Color(0xFFC2410C),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Aún no hay hechos ni actividades asociados a este turno.',
                      style: TextStyle(color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            )
          else
            ...records.map((record) => _ServiceRecordTile(record: record)),
        ],
      ),
    );
  }
}

class _ServiceRecordTile extends StatelessWidget {
  final ({String type, Map<String, dynamic> data}) record;

  const _ServiceRecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final isEvent = record.type == 'hecho';
    final data = record.data;
    final color = isEvent ? const Color(0xFFC2410C) : const Color(0xFF15803D);
    final title = isEvent
        ? _text(data['tipo_hecho'], 'Hecho de tránsito')
        : _text(
            data['nombre'],
            _text(_map(data['categoria'])['nombre'], 'Actividad'),
          );
    final location = isEvent
        ? [data['calle'], data['colonia'], data['municipio']]
        : [data['lugar'], data['municipio']];
    final locationText = location
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join(' · ');
    final folio = data['folio_c5i']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: .13),
            child: Icon(
              isEvent ? Icons.car_crash_outlined : Icons.task_alt_rounded,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      _shortTime(data['hora']),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (folio.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Folio C5i: $folio',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                if (locationText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 15),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          locationText,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CountChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _HistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _HistoryTab({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const _MessageState(
        icon: Icons.history_toggle_off,
        title: 'Sin historial',
        message: 'Tus servicios cerrados aparecerán aquí.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = history[index];
        final patrol = _map(item['patrulla']);
        final log = _map(item['bitacora']);
        return Card(
          elevation: 0,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.directions_car_outlined),
            ),
            title: Text(
              'Patrulla ${_text(patrol['numero_economico'], 'S/N')}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${_text(log['fecha'], 'Sin fecha')} · ${_shortTime(log['hora_inicio'])}–${_shortTime(log['hora_fin'])}\n${log['kilometros_recorridos'] ?? 0} km recorridos',
            ),
            isThreeLine: true,
            trailing: Icon(
              log['estatus'] == 'cerrada' ? Icons.check_circle : Icons.pending,
              color: log['estatus'] == 'cerrada' ? Colors.green : Colors.orange,
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _HeroCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget? trailing;
  const _HeroCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color, Color.lerp(color, Colors.black, .28)!],
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: .22),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: Colors.white, size: 27),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .82),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Metric({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    ),
  );
}

class _FuelSelector extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _FuelSelector({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Nivel de combustible',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            '${value.round()}%',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
      Slider(
        value: value,
        min: 0,
        max: 100,
        divisions: 20,
        label: '${value.round()}%',
        onChanged: onChanged,
      ),
    ],
  );
}

class _StatusField extends StatelessWidget {
  final String label;
  final String field;
  final List<String> values;
  final Map<String, String> status;
  final void Function(String, String) onChanged;
  const _StatusField({
    required this.label,
    required this.field,
    required this.values,
    required this.status,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<String>(
      value: status[field],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: values
          .map(
            (value) => DropdownMenuItem(
              value: value,
              child: Text(_statusLabel(value)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(field, value);
      },
    ),
  );
}

class _TextArea extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _TextArea({required this.controller, required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      minLines: 2,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      SizedBox(height: MediaQuery.sizeOf(context).height * .18),
      Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 16),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, height: 1.45),
        ),
      ),
    ],
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 58, color: Colors.red.shade400),
          const SizedBox(height: 14),
          const Text(
            'No se pudo cargar el módulo',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const <Map<String, dynamic>>[];
int? _int(dynamic value) => value is int ? value : int.tryParse('$value');
String _text(dynamic value, String fallback) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}

String _shortTime(dynamic value) {
  final text = value?.toString() ?? '';
  return text.length >= 5
      ? text.substring(0, 5)
      : (text.isEmpty ? '--:--' : text);
}

String _message(Object error) =>
    error.toString().replaceFirst('Exception: ', '').trim();
String _statusLabel(String value) => switch (value) {
  'bueno' => 'Bueno',
  'regular' => 'Regular',
  'malo' => 'Malo',
  'no_aplica' => 'No aplica',
  _ => value,
};
String _inventoryLabel(String key) => switch (key) {
  'trae_refaccion' => 'Llanta de refacción',
  'trae_gato' => 'Gato hidráulico',
  'trae_llave_cruz' => 'Llave de cruz',
  'trae_extintor' => 'Extintor',
  'trae_botiquin' => 'Botiquín',
  _ => key,
};
